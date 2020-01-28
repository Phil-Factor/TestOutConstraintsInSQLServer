CREATE OR ALTER PROCEDURE #TestAllForeignKeyConstraints
  /**
Summary: >
  This tests the current database against its check constraints. 
  and reports any data that would fail a check were it enabled
Author: Phil Factor
Date: 15/12/2019
Example:
   - DECLARE @OurFailedConstraints  NVARCHAR(MAX)
     EXECUTE #TestAllForeignKeyConstraints @TheResult=@OurFailedConstraints OUTPUT
     SELECT @OurFailedConstraints AS theFailedForeignKeyConstraints
  Returns: >
  the JSON as an output variable
**/
@JsonConstraintList NVARCHAR(MAX)=null,--you can either provide a json document
--or you can go and get the current
@TheResult NVARCHAR(MAX) OUTPUT --the JSON document that gives the test result.
as

IF @JsonConstraintList IS NULL
  EXECUTE #ListAllForeignKeyConstraints @TheJSONList = @JsonConstraintList OUTPUT;

DECLARE @TheForeignKeyConstraints TABLE --the list of Foreign Keys in the database
  (
  TheOrder INT IDENTITY PRIMARY KEY, --needed to iterate through the table
  ColumnCount INT,
  KeyName sysname,
  Referencing sysname,
  Referenced sysname,
  HowReferenced NVARCHAR(4000),
  NullCondition NVARCHAR(4000),
  ReferencingColumnListAsString NVARCHAR(4000),
  ReferencedColumnListAsString NVARCHAR(4000),
  ColumnList NVARCHAR(4000)
  );
INSERT INTO @TheForeignKeyConstraints
  (ColumnCount, KeyName, Referencing, Referenced, HowReferenced, NullCondition,
ReferencingColumnListAsString, ReferencedColumnListAsString, ColumnList)
  SELECT ColumnCount, KeyName, Referencing, Referenced, HowReferenced,
    NullCondition, ReferencingColumnListAsString, ReferencedColumnListAsString,
    ColumnList
    FROM
    OpenJson(@JsonConstraintList)
    WITH
      (
      ColumnCount INT, KeyName sysname, Referencing sysname,
      Referenced sysname, HowReferenced NVARCHAR(4000),
      NullCondition NVARCHAR(4000),
      ReferencingColumnListAsString NVARCHAR(4000),
      ReferencedColumnListAsString NVARCHAR(4000), ColumnList NVARCHAR(4000)
      );
--now we have the information we need about the foreign key references
DECLARE @Breakers TABLE (TheObject NVARCHAR(MAX));
DECLARE @Errors TABLE (Description NVARCHAR(MAX));
DECLARE @OrphanKeyValues NVARCHAR(MAX); ---list of OrphanKeyValue rows 
DECLARE @ExecString NVARCHAR(MAX); --The string for that finds the OrphanKeyValues
DECLARE @keyName sysname; --to hold the value when iterating through the result
DECLARE @referenced sysname; --to hold the value when iterating through the result
DECLARE @Referencing sysname;
DECLARE @ReferencingColumnListAsString NVARCHAR(4000);
DECLARE @ReferencedColumnListAsString NVARCHAR(4000);
DECLARE @CheckReferencingExecString NVARCHAR(MAX); --The string for that checks the referencing cols exist
DECLARE @CheckReferencedExecString NVARCHAR(MAX); --The string for that checks the referenced cols exist
--DECLARE @ColumnListAsString NVARCHAR(4000);
--to hold the value when iterating through the result
DECLARE @columnOrphanKeyValues NVARCHAR(MAX); --the OrphanKeyValue columns
DECLARE @AllReferencedColumnsAndTableThere INT;
DECLARE @AllReferencingColumnsAndTableThere INT;
DECLARE @iiMax INT = @@RowCount;
DECLARE @ii INT = 1;
WHILE (@ii <= @iiMax)
  BEGIN
    SELECT @CheckReferencingExecString =
      N'SELECT @AllColumnsThere =
  CASE WHEN ' + Convert(VARCHAR(3), ColumnCount)
      + N' =
  (
  SELECT Count(*) FROM sys.columns AS c
    WHERE c.name IN (' + ReferencingColumnListAsString
      + N')
      AND Object_Id(''' + Referencing
      + N''') = c.object_id
  ) THEN 1 ELSE 0 END;
'   , @CheckReferencedExecString =
        N'SELECT @AllColumnsThere =
  CASE WHEN ' + Convert(VARCHAR(3), ColumnCount)
        + N' =
  (
  SELECT Count(*) FROM sys.columns AS c
    WHERE c.name IN (' + ReferencedColumnListAsString
        + N')
      AND Object_Id(''' + Referenced
        + N''') = c.object_id
  ) THEN 1 ELSE 0 END; 
'   , @ExecString =
        N'SET @OrphanKeyValues=(SELECT TOP 50 ' + ColumnList + N' FROM  '
        + Referencing + N' as referencing
LEFT OUTER JOIN '   + Referenced + N' as referenced
ON  '               + HowReferenced + N'
WHERE '             + NullCondition + N' FOR JSON auto)', @keyName = KeyName,
      @referenced = Referenced, @Referencing = Referencing,
      @ReferencingColumnListAsString = ReferencingColumnListAsString,
      @ReferencedColumnListAsString = ReferencedColumnListAsString
      FROM @TheForeignKeyConstraints
      WHERE TheOrder = @ii;
	 -- PRINT @CheckReferencingExecString
    EXECUTE sp_executesql @CheckReferencingExecString,
      N'@AllColumnsThere int output',
      @AllColumnsThere = @AllReferencingColumnsAndTableThere OUTPUT;
	  --PRINT @CheckReferencedExecString
	  EXECUTE sp_executesql @CheckReferencedExecString,
      N'@AllColumnsThere int output',
      @AllColumnsThere = @AllReferencedColumnsAndTableThere OUTPUT;
    IF @AllReferencedColumnsAndTableThere = 1
   AND @AllReferencedColumnsAndTableThere = 1
      BEGIN
       -- PRINT @ExecString
        EXECUTE sp_executesql @ExecString,
          N'@OrphanKeyValues NVARCHAR(MAX) output',
          @OrphanKeyValues = @columnOrphanKeyValues OUTPUT;
        IF @columnOrphanKeyValues IS NOT NULL
          BEGIN
           -- PRINT @ExecString;
            INSERT INTO @Breakers (TheObject)
              SELECT
                (
                SELECT @keyName AS KeyName, @referenced AS Referenced,
                  @Referencing AS Referencing,
                  @ReferencedColumnListAsString AS ColumnListAsString,
                  Json_Query(@columnOrphanKeyValues) AS OrphanKeyValues
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                );
          END;
      END;
    ELSE
      INSERT INTO @Errors (Description)
        SELECT CASE WHEN @AllReferencedColumnsAndTableThere <> 1 THEN
                      'Table' + @referenced
                      + 'either didn''nt exist or didn''t have the key column(s)'
                      + @ReferencedColumnListAsString + 'so foreign key '
                      + @keyName + ' was untested' ELSE '' END
               + CASE WHEN @AllReferencingColumnsAndTableThere <> 1 THEN
                        'Table' + @Referencing
                        + 'either didn''nt exist or didn''t have the key column(s)'
                        + @ReferencingColumnListAsString + 'so foreign key '
                        + @keyName + ' was untested' ELSE '' END;
    SELECT @ii = @ii + 1; --do the next Foreign Key in the list
  END;
DECLARE @ErrorCount INT=(SELECT Count(*) FROM @errors)
DECLARE @BreakerCount INT=(SELECT Count(*) FROM @Breakers)

DECLARE @Success VARCHAR(100)=
  CASE WHEN @Breakercount=0 and @ErrorCount=0 THEN 'Everything went well' 
   ELSE 
    'There were '+Convert(Varchar(5),@Breakercount)+' Broken foreign key constraints and '
		   +CASE WHEN @Errorcount>0 then Convert(Varchar(5),@Errorcount) ELSE 'no' end+' errors'
	end
SELECT @TheResult=
  (SELECT  @success AS success, 
    (SELECT Json_Query(TheObject) AS OrphanKeyValued FROM @Breakers FOR JSON AUTO) AS OrphanKeyValuelist,
    (SELECT Description FROM @Errors FOR JSON AUTO) AS errors
  FOR JSON PATH);
/*
  GO
   DECLARE @OurFailedConstraints  NVARCHAR(MAX)
 EXECUTE #TestAllForeignKeyConstraints @TheResult=@OurFailedConstraints OUTPUT
 SELECT @OurFailedConstraints AS theFailedFKConstraints
 */