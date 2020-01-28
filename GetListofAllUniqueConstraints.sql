DECLARE @JsonConstraintList  NVARCHAR(MAX)
EXECUTE #ListAllUniqueIndexes @TheJsonList=@JsonConstraintList OUTPUT
SELECT @JsonConstraintList AS theUniqueIndexes