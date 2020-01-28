    DECLARE @OurFailedConstraints  NVARCHAR(MAX)
    EXECUTE #TestAllCheckConstraints @JSONConstraintList=@JSONinput, @TheResult=@OurFailedConstraints OUTPUT
    SELECT @OurFailedConstraints AS theFailedCheckConstraints