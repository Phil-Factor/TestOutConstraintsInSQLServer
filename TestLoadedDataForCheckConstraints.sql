 DECLARE @OurFailedConstraints  NVARCHAR(MAX)
 EXECUTE #TestAllCheckConstraints @TheResult=@OurFailedConstraints OUTPUT
 SELECT @OurFailedConstraints AS theFailedCheckConstraints