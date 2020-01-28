import-Module sqlserver
<# a list of connection strings for each of the target database instances in which 
 you'd like to run the code #>
$ServerAndDatabaseList =
@(
 <# list of connection strings for each of the SQLservers that you need to execute code on #>
	@{  <# To make things simpler, I've treated each server as having its own 'global' variables #>
		#provide a connection string for the instance
		'ServerConnectionString' = 'Server=PentlowMillServ;User Id=sa;Persist Security Info=False';
		#and a list of databases you wish the string-based (EG JSON report) from. 
		'Databases' = @('NorthWind', 'AdventureWorks2016', 'WestWind'); # do all these databases
		'RootDirectoryForOutputFile' = "$env:USERPROFILE\JSONDocumentation"; #the directory you want it in as subdirectories
		'minimumCompatibilityLevel' = 130; #specify the minimum database compatibility level. We check!
		'ScriptDirectory' = 'S:\work\Github\TestOutConstraints'; # where you store the project SQL files 
		'fileType' = 'json'; #the filetype of the files you save for each database for reports
        # and now a list of all the temporary stored procedures you'll need.
		'setupScripts' = @('ListAllUniqueIndexes.sql', 'ListAllForeignKeyConstraints.sql', 'ListAllCheckConstraints.sql',
			'TestAllUniqueIndexes.sql', 'TestAllForeignKeyConstraints.sql', 'TestAllCheckConstraints.sql');
    <#This lot are used process 1- for testing the loaded data to ensure it complies with the constraints
    'FilesToExecute' = @(
      @{ 'scriptFileName' = 'TestLoadedDataForCheckConstraints.sql'; 'OutputFileName' = 'CheckConstraintsReport' },
      @{ 'scriptFileName' = 'TestLoadedDataForUniqueConstraints.sql'; 'OutputFileName' = 'UniqueConstraintsReport' },
      @{ 'scriptFileName' = 'TestLoadedDataForFKConstraints.sql'; 'OutputFileName' = 'FKConstraintsReport' }
    )#>
		
    <#Save the lists of constraints as defined in the database
    'FilesToExecute' = @(
      @{ 'scriptFileName' = 'GetListofAllForeignKeyConstraints.sql'; 'OutputFileName' = 'FKConstraintsList' },
      @{ 'scriptFileName' = 'GetListofAllUniqueConstraints.sql'; 'OutputFileName' = 'UniqueConstraintsList' },
      @{ 'scriptFileName' = 'GetListofAllCheckConstraints.sql'; 'OutputFileName' = 'CheckConstraintsList' }
    )#>
		'FilesToExecute' = @(
			@{ 'scriptFileName' = 'TestJSONForUniqueIndexes.sql'; ` 
               'input' = @{ 'FileName' = 'UniqueConstraintsList' }; ` 
               'OutputFileName' = 'DelayedFConstraintsReport' } <#,
      @{ 'scriptFileName' = 'TestLoadedDataForUniqueConstraints.sql'; 'OutputFileName' = 'UniqueConstraintsReport' },
      @{ 'scriptFileName' = 'TestLoadedDataForFKConstraints.sql'; 'OutputFileName' = 'FKConstraintsReport' }#>
		)
		'TearDownScripts' = @();
	}
)

$slash = '+' #the string that you want to replace for the 'slash' in an instance name for files etc
# end of data area

#Now for each instance and associated list of databases
$ServerAndDatabaseList | foreach {
	$Job = $_
	#for each instance/sever
	if (!(Test-Path -path $_.RootDirectoryForOutputFile -PathType Container))
	{ $null = New-Item -ItemType directory -Path $_.RootDirectoryForOutputFile }
	$csb = New-Object System.Data.Common.DbConnectionStringBuilder
	$csb.set_ConnectionString($_.ServerConnectionString)
	# create an SMO connection get credentials if necessary
	if ($csb.'user id' -ne '') #then it is using SQL Server Credentials
	{ <# Oh dear, we need to get the password, if we don't already know it #>
		$SqlEncryptedPasswordFile = `
		"$env:USERPROFILE\$($csb.'user id')-$($csb.server.Replace('\', $slash)).xml"
		# test to see if we know about the password in a secure string stored in the user area
		if (Test-Path -path $SqlEncryptedPasswordFile -PathType leaf)
		{
			#has already got this set for this login so fetch it
			$SqlCredentials = Import-CliXml $SqlEncryptedPasswordFile
			
		}
		else #then we have to ask the user for it (once only)
		{
			#hasn't got this set for this login
			$SqlCredentials = get-credential -Credential $csb.'user id'
			$SqlCredentials | Export-CliXml -Path $SqlEncryptedPasswordFile
		}
		$ServerConnection =
		new-object `
				   "Microsoft.SqlServer.Management.Common.ServerConnection"`
		($csb.server, $SqlCredentials.UserName, $SqlCredentials.GetNetworkCredential().password)
		$csb.Add('password', $SqlCredentials.GetNetworkCredential().password)
	}
	else
	{
		$ServerConnection =
		new-object `
				   "Microsoft.SqlServer.Management.Common.ServerConnection" `
		($csb.server)
	}
 <# all this work just to maintain passwords ! #>
	try # now we make an SMO connection to the server, using the connection string
	{
		$srv = new-object ("Microsoft.SqlServer.Management.Smo.Server") $ServerConnection
	}
	catch
	{
		Write-error "Could not connect to SQL Server instance $($csb.server) $($error[0]). Script is aborted"
		exit -1
	}
	$Databasesthere = $srv.Databases.name
	$_.Databases |
	foreach {
		$Db = $_
		write-output "now running scripts on $Db database in the SQL Server $($csb.server) "
		$ReturnedStringFromBatch = ''
		$CompatibilityLevel = $srv.ConnectionContext.ExecuteScalar("
 SELECT top 1 compatibility_level FROM sys.databases WHERE name = '$db'");
		if ($databasesThere -notcontains $db)
		{
			Write-Error "The Server $($csb.Server) does not have a database called $db"
		}
		if ($CompatibilityLevel -lt $_.minimumCompatibilityLevel)
		{
			Write-Error "The Server database called $db on $($csb.Server) at level $CompatibilityLevel is below the minimum compatibility level $_.minimumCompatibilityLevel"
		}
<# now execute all the files for setting up the work on the connections #>
		$connection = New-Object System.Data.SqlClient.SqlConnection
		$connection.ConnectionString = $csb.ConnectionString
		$connection.Open()
		$SQLComm = New-Object System.Data.SqlClient.SqlCommand
		$SQLComm.Connection = $connection
		$SQLComm.CommandText = "use $db";
		$sqlcomm.ExecuteScalar()
		$job.setupScripts |
		foreach{
			if ($_ -ne $null)
			{
				write-output "now running script $($job.ScriptDirectory)\$($_) on $Db database "
				
				try
				{
					
					$SetupScript = [IO.File]::ReadAllText("$($job.ScriptDirectory)\$($_)")
					$SQLComm.CommandText = "$SetupScript";
					$Result = $sqlcomm.ExecuteScalar()
				}
				catch
				{
					Write-error `
								"Could not execute the setup code in $_ on $($csb.server) $($error[0].Exception). Script is aborted"
					exit -1
				}
			}
		}
		$outputFilePath = "$($Job.RootDirectoryForOutputFile)\$($csb.server.Replace('\', $slash))"
		
		#make sure that the folder exists for the subdirectory orresponding to the server
		if (!(Test-Path -path $outputFilePath -PathType Container))
		{ $null = New-Item -ItemType directory -Path $outputFilePath }
		
		
		$job.FilesToExecute |
		foreach{
			
			if ($_ -ne $null)
			{
				write-output "now running script $($job.ScriptDirectory)\$($_.scriptfilename) on $Db database "
				if ($_.input -ne $null)
				{
					#if he has specified an input
					
					$SQLParamComm = New-Object System.Data.SqlClient.SqlCommand
					$SQLParamComm.Connection = $connection
					$SQLParamComm.CommandText = "use $db";
					$SQLParamComm.ExecuteScalar()
					$null=$SQLParamComm.Parameters.Add('@JSONinput', [System.Data.SqlDbType]'NVarchar');
					$SQLParamComm.Parameters['@JSONinput'].Value = [IO.File]::ReadAllText("$outputFilePath\$db\$($_.input.filename)");
					try
					{
						$paramScript = [IO.File]::ReadAllText("$($job.ScriptDirectory)\$($_.scriptfilename)")
						$SQLParamComm.CommandText ="$paramScript"# "$paramScript";
						$Result = $sqlParamcomm.ExecuteScalar()
						
					}
					catch
					{
						Write-error `
									"Could not execute the parameterised code in $($job.ScriptDirectory)\$($_.scriptfilename) on $($csb.server) $($error[0].Exception). Script is aborted"
						exit -1
					}
				}
				else
				{
					try
					{
						$NextScript = [IO.File]::ReadAllText("$($job.ScriptDirectory)\$($_.scriptfilename)")
						$SQLComm.CommandText = "$NextScript";
						$Result = $sqlcomm.ExecuteScalar()
						
					}
					catch
					{
						Write-error `
									"Could not execute the code in $($job.ScriptDirectory)\$($_.scriptfilename) on $($csb.server) $($error[0].Exception). Script is aborted"
						exit -1
					}
				}	
					if ($_.Outputfilename -ne $null)
				{
					#if he has specified an output
					if (!(Test-Path -path "$outputFilePath\$db" -PathType Container))
					{ $null = New-Item -ItemType directory -Path "$outputFilePath\$db" }
					$Result>"$outputFilePath\$db\$($_.Outputfilename)" #output it to the file
				}
				$ResultMessage = ($Result | Convertfrom-json).success
				if ($ResultMessage -ne $null)
				{ if ($ResultMessage -ne 'Everything went well') { Write-Warning $ResultMessage } }
				
			}
		}
		$job.TeardownScripts |
		foreach{
			if ($_ -ne $null)
			{
				try
				{
					$TearDownScript = [IO.File]::ReadAllText("$($job.ScriptDirectory)\$($_)")
					$SQLComm.CommandText = "$TearDownScript";
					$Result = $sqlcomm.ExecuteScalar()
					
				}
				catch
				{
					Write-error `
								"Could not execute the teardown code in $_ on $($csb.server) $($error[0].Exception). Script is aborted"
					exit -1
				}
			}
		}
	}
}

