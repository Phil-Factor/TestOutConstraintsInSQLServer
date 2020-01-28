CREATE OR ALTER PROCEDURE #ListAllForeignKeyConstraints
  /**
Summary: >
  This creates a JSON list of all the Foreign key constraints in the database. 
  
  Author: Phil Factor
Date: 12/12/2019
Example:
   - DECLARE @OurListOfForeignKeyConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllForeignKeyConstraints @TheJsonList=@OurListOfForeignKeyConstraints OUTPUT
     SELECT @OurListOfForeignKeyConstraints AS theForeignKeyConstraints

   - DECLARE @OurListOfForeignKeyConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllForeignKeyConstraints @TheJsonList=@OurListOfForeignKeyConstraints OUTPUT
     SELECT * FROM OpenJson( @OurListOfForeignKeyConstraints) 
	 WITH (ColumnCount INT, KeyName sysname, 
	       Referencing sysname,Referenced sysname, HowReferenced NVARCHAR(4000),NullCondition NVARCHAR(4000),
		   ReferencingColumnListAsString nvarchar(4000),ReferencedColumnListAsString nvarchar(4000), ColumnList nvarchar(4000))
Returns: >
  the JSON as an output variable
**/
  @TheJSONList NVARCHAR(MAX) OUTPUT
AS
SELECT @TheJSONList =
  (
  SELECT name AS KeyName, Count(*) AS ColumnCount,
    QuoteName(Object_Schema_Name(FK.parent_object_id)) + '.'
    + QuoteName(Object_Name(FK.parent_object_id)) AS Referencing,
    QuoteName(Object_Schema_Name(FK.referenced_object_id)) + '.'
    + QuoteName(Object_Name(FK.referenced_object_id)) AS Referenced,
    String_Agg(
                 'referencing.'
                + QuoteName(Col_Name(FK.parent_object_id, parent_column_id))
                + ' = referenced.' 
                + QuoteName(
Col_Name(FK.referenced_object_id, referenced_column_id)
)   ,
                ' AND '
              ) AS HowReferenced,
    String_Agg(
                '(referenced.'
                + QuoteName(
Col_Name(FK.referenced_object_id, referenced_column_id)
)               + ' IS NOT NULL AND referenced.'
                + QuoteName(
Col_Name(FK.referenced_object_id, referenced_column_id)
)               + ' IS NULL )',
                ' AND '
              ) AS NullCondition,
    ''''
    + String_Agg(
                  Replace(
Col_Name(FK.parent_object_id, parent_column_id), '''', ''''''
)   ,
                  ''','''
                ) + '''' AS ReferencingColumnListAsString,
    ''''
    + String_Agg(
                  Replace(
Col_Name(FK.referenced_object_id, referenced_column_id), '''', ''''''
)   ,
                  ''','''
                ) + '''' AS ReferencedColumnListAsString,
    String_Agg(
                'Referencing.'
                + QuoteName(Col_Name(FK.parent_object_id, parent_column_id)),
                ' ,'
              ) AS ColumnList
    FROM sys.foreign_keys AS FK
      INNER JOIN sys.foreign_key_columns AS FKC
        ON FKC.constraint_object_id = FK.object_id
    WHERE is_ms_shipped = 0
    GROUP BY name, FK.parent_object_id, FK.referenced_object_id
  FOR JSON AUTO
  );
