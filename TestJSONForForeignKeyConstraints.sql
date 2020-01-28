    DECLARE @OurFailedConstraints  NVARCHAR(MAX)
    EXECUTE #TestAllForeignKeyConstraints @JSONConstraintList=@JSONinput, @TheResult=@OurFailedConstraints OUTPUT
    SELECT @OurFailedConstraints AS theFailedFKConstraints