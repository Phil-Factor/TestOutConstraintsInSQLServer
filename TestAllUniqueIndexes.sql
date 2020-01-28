CREATE OR alter PROCEDURE #TestAllUniqueConstraints
  /**
Summary: >
  This tests the current database against its Unique constraints. 
  and reports any data that would fail a check were it enabled
Author: Phil Factor
Date: 15/12/2019
Example:
   - DECLARE @OurFailedConstraints  NVARCHAR(MAX)
     EXECUTE #TestAllUniqueConstraints @TheResult=@OurFailedConstraints OUTPUT
     SELECT @OurFailedConstraints AS theFailedUniqueConstraints
  Returns: >
  the JSON as an output variable
**/
@JsonConstraintList NVARCHAR(MAX)=null,--you can either provide a json document
--or you can go and get the current
@TheResult NVARCHAR(MAX) OUTPUT --the JSON document that gives the test result.
as

IF @JsonConstraintList IS NULL
EXECUTE #ListAllUniqueIndexes @TheJSONList = @JsonConstraintList OUTPUT;
DECLARE @TheUniqueIndexes TABLE --the list of unique indexes in the database
  (
  TheOrder INT IDENTITY PRIMARY KEY,--needed to iterate through the table
  ColumnCount INT, --the number of columns used in the index
  IndexName sysname, --the name of the index
  TheTable sysname, --the quoted name of the table wqith the schema
  ColumnList NVARCHAR(4000), --the list of columns in the index
  DelimitedList NVARCHAR(4000) --the list of columns in the index
 );
INSERT INTO @TheUniqueIndexes (ColumnCount, IndexName, 
		TheTable, ColumnList, DelimitedList)
  SELECT * FROM OpenJson(@JsonConstraintList)
  WITH
    (columncount INT, indexname sysname, 
	 thetable sysname, columnlist NVARCHAR(4000),delimitedlist nvarchar(4000)
  );

DECLARE @Breakers TABLE (TheObject NVARCHAR(MAX));
DECLARE @Errors TABLE ([Description] NVARCHAR(MAX));
DECLARE @Duplicates NVARCHAR(MAX); ---list of duplicate rows 
DECLARE @ExecString NVARCHAR(MAX); --The string for that finds the duplicates
DECLARE @indexName sysname; --to hold the value when iterating through the result
DECLARE @tablename sysname; --to hold the value when iterating through the result
DECLARE @CheckExecString NVARCHAR(MAX); --The string for that checks the cols exist
DECLARE @columnList NVARCHAR(4000);
                           --to hold the value when iterating through the result
DECLARE @columnDuplicates NVARCHAR(MAX);--the duplicate indexes
DECLARE @AllColumnsAndTableThere int
DECLARE @iiMax INT = @@RowCount;
DECLARE @ii INT = 1;
WHILE (@ii <= @iiMax)
  BEGIN
	SELECT @CheckExecString ='SELECT @AllColumnsThere =
  CASE WHEN '+Convert(varchar(3),ColumnCount)+' =
  (
  SELECT Count(*) FROM sys.columns AS c
    WHERE c.name IN ('+delimitedList+')
      AND Object_Id('''+TheTable+''') = c.object_id
  ) THEN 1 ELSE 0 END;
', @ExecString =
      N'SET @duplicates=(SELECT top 50 Count(*) AS duplicatecount, '
      + ColumnList + N' FROM ' + TheTable + N' GROUP BY ' + ColumnList
      + N' HAVING Count(*) >1 FOR JSON auto)', @indexName = IndexName,
      @tablename = TheTable, @columnList = ColumnList
      FROM @TheUniqueIndexes
      WHERE TheOrder = @ii;
    EXECUTE sp_executesql @CheckExecString, N'@AllColumnsThere int output',
      @AllColumnsThere = @AllColumnsAndTableThere OUTPUT;
    if @AllColumnsAndTableThere=1
	  BEGIN
      EXECUTE sp_executesql @ExecString, N'@duplicates NVARCHAR(MAX) output',
        @duplicates = @columnDuplicates OUTPUT;
       IF @columnDuplicates IS NOT NULL
        INSERT INTO @Breakers (TheObject)
          SELECT
            (
            SELECT @indexName AS indexName, @tablename AS tablename,
              @columnList AS columnlist, Json_Query(@columnDuplicates) AS duplicates
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
      END
    ELSE
	   INSERT INTO @errors(description) 
	     SELECT 'Table' + @Tablename
		        +'either didn''nt exist or didn''t have the column(s)' 
				+@columnlist+ 'so index '+@Indexname+' was untested'
	SELECT @ii = @ii + 1; --do the next unique index in the list
  END;
DECLARE @ErrorCount INT=(SELECT Count(*) FROM @errors)
DECLARE @BreakerCount INT=(SELECT Count(*) FROM @Breakers)

DECLARE @Success VARCHAR(100)=
  CASE WHEN @Breakercount=0 and @ErrorCount=0 THEN 'Everything went well' 
   ELSE 
    'There were '+Convert(Varchar(5),@Breakercount)+' Duplicate rows and '
		   +CASE WHEN @Errorcount>0 then Convert(Varchar(5),@Errorcount) ELSE 'no' end+' errors' 
   end
SELECT @TheResult=
  (SELECT  @success AS success,
 (SELECT Json_Query(TheObject) AS duplicated FROM @Breakers FOR  JSON auto) AS duplicatelist,
       (SELECT description FROM @Errors FOR JSON auto) AS errors FOR JSON PATH);

