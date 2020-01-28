    DECLARE @OurFailedConstraints  NVARCHAR(MAX)
    EXECUTE #TestAllUniqueConstraints @JSONConstraintList=@JSONinput, @TheResult=@OurFailedConstraints OUTPUT
    SELECT @OurFailedConstraints AS theFailedUniqueConstraints