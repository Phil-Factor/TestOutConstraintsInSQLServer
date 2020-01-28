CREATE OR ALTER PROCEDURE #ListAllUniqueIndexes
/**
Summary: >
  This creates a JSON list of all the unique indexes in the database. 
  This includes indexes in the database that have been explicitly 
  declared as well as those that have been automatically created 
  to enforce UNIQUE or PRIMARY KEY constraints
Author: Phil Factor
Date: 12/12/2019
Example:
   - DECLARE @JsonConstraintList  NVARCHAR(MAX)
     EXECUTE #ListAllUniqueIndexes @TheJsonList=@JsonConstraintList OUTPUT
     SELECT @JsonConstraintList AS theUniqueIndexes

   - DECLARE @JsonConstraintList  NVARCHAR(MAX)
     EXECUTE #ListAllUniqueIndexes @TheJsonList=@JsonConstraintList OUTPUT
     SELECT * FROM OpenJson( @JsonConstraintList) 
	 WITH (columncount INT, indexname sysname, 
	       thetable sysname, columnlist NVARCHAR(4000),delimitedlist nvarchar(4000))
Returns: >
  the JSON as an output variable
**/
@TheJSONList NVARCHAR(MAX) OUTPUT
AS 
SELECT @TheJSONList=
 (SELECT Count(*) AS columncount, IX.name AS indexname,
        QuoteName(Object_Schema_Name(IX.object_id)) + '.'
        + QuoteName(Object_Name(IX.object_id)) AS thetable,
        String_Agg(QuoteName(col.name), ',') AS columnlist,
		''''+String_Agg(Replace(col.name,'''',''''''),''',''')+'''' AS delimitedlist
        FROM sys.tables AS tabs
          INNER JOIN sys.indexes AS IX
            ON IX.object_id = tabs.object_id
          INNER JOIN sys.index_columns AS IC
            ON IC.index_id = IX.index_id AND IC.object_id = IX.object_id
          INNER JOIN sys.columns AS col
            ON col.column_id = IC.column_id AND col.object_id = IC.object_id
        WHERE is_unique = 1 -- we only need the ones that force uniqueness
		--we've chosen to test both the enabled ones and the disabled ones
		--AND Is_disabled=0
        GROUP BY IX.index_id, IX.object_id, IX.name FOR JSON AUTO)

