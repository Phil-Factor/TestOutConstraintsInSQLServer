 DECLARE @OurFailedConstraints  NVARCHAR(MAX)
 EXECUTE #TestAllForeignKeyConstraints @TheResult=@OurFailedConstraints OUTPUT
 SELECT @OurFailedConstraints AS theFailedFKConstraints