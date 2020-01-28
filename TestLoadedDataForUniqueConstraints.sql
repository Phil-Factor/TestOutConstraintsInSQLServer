 DECLARE @OurFailedConstraints  NVARCHAR(MAX)
 EXECUTE #TestAllUniqueConstraints @TheResult=@OurFailedConstraints OUTPUT
 SELECT @OurFailedConstraints AS theFailedUniqueConstraints