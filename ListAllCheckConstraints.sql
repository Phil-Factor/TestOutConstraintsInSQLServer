CREATE OR ALTER PROCEDURE #ListAllCheckConstraints
  /**
Summary: >
  This creates a JSON list of all the check constraints in the database. 
  their name, table and definition
Author: Phil Factor
Date: 12/12/2019
Example:
   - DECLARE @OurListAllCheckConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllCheckConstraints @TheJsonList=@OurListAllCheckConstraints OUTPUT
     SELECT @OurListAllCheckConstraints AS theCheckConstraints
   - DECLARE @OurCheckConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllCheckConstraints @TheJsonList=@OurCheckConstraints OUTPUT
	 SELECT Constraintname, TheTable, [definition]
      FROM OPENJSON(@OurCheckConstraints)  WITH
      (Constraintname sysname '$.constraintname',TheTable sysname '$.thetable', 
	  [Definition] nvarchar(4000) '$.definition' ); 
Returns: >
  the JSON as an output variable
**/
  @TheJSONList NVARCHAR(MAX) OUTPUT
AS
SELECT @TheJSONList =
  (
  SELECT QuoteName(CC.name) AS constraintname,
    QuoteName(Object_Schema_Name(CC.parent_object_id)) + '.'
    + QuoteName(Object_Name(CC.parent_object_id)) AS thetable, definition
    FROM sys.check_constraints AS CC
    WHERE is_ms_shipped = 0
  FOR JSON AUTO
  );



