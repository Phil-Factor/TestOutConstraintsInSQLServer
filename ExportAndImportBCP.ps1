<# This script will BCP out all the tables from one version of a database, and 
place them in a directory of your choice, (defaulting to your user area in a 
directory called BCPFiles) They are placed in subdirectories based on your server
name and database name, just to keep things neat. It will do a list of these
tasks if you feel bold.
The script then will transfer this data to an empty version of the same database
(same meaning with the same table schema) with no data in it) If the two versions
have a different table structure you'll get an error. If you use this system and
you change the table structure, you run your migration code on the source until
it is the same as the target. 
BCP needs to be installed to run this. This comes with SSMS so you probably
have it already. Sometimes you need to create an alias for BCP but I think that
problem has gone away

To get started, fill in the connection string for your source of data $datasource
and $dataTarget. You also need to fill in an array of objects, each of which
define your source and target databases, so you can do a whole list of databases.
  #>


$Filepath = "$env:USERPROFILE\BCPFiles" # local directory to save build-scripts to
$DataSource = @{ 'ConnectionString' = 'Server=MySourceServer;Persist Security Info=False' }; # server name and instance
$DataTarget = @{ 'ConnectionString' = 'Server=MyTargetServer;User Id=sa;Persist Security Info=False' }; # server name and instance

$FileSourceDirectory = 'MyServer'<#if you are reading files in only, the script
needs to know the subdirectory of your root directory to use to get the right files#>

if ($DataSource -eq $null -and $FileSourceDirectory -eq $null)
{ write-error 'the script needs to know the subdirectory of your root directory to use' break; }


$Databases = @(@{ 'source' = 'MyDatabase'; 'target' = 'MyNewDatabase' })
$slash = '+' #the string that you want to replace for the 'slash' in an instance name for files etc

# set "Option Explicit" to catch subtle errors
set-psdebug -strict
$ErrorActionPreference = "stop" # you can opt to stagger on, bleeding, if an error occurs
#load the sqlserver module
$popVerbosity = $VerbosePreference
$VerbosePreference = "Silentlycontinue"
# the import process can be very noisy if you are in verbose mode
Import-Module sqlserver -DisableNameChecking #load the SQLPS functionality
$VerbosePreference = $popVerbosity

if (!(Test-Path -path $Filepath -PathType Container))
{ $null = New-Item -ItemType directory -Path $Filepath }


@($DataSource, $DataTarget) | where { $_ -ne $null } | foreach {
	$csb = New-Object System.Data.Common.DbConnectionStringBuilder
	$csb.set_ConnectionString($_.ConnectionString)
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
		$_.ServerConnection =
		new-object `
				   "Microsoft.SqlServer.Management.Common.ServerConnection"`
		($csb.server, $SqlCredentials.UserName, $SqlCredentials.GetNetworkCredential().password)
		$csb.Add('password', $SqlCredentials.GetNetworkCredential().password)
	}
	else
	{
		$_.ServerConnection =
		new-object `
				   "Microsoft.SqlServer.Management.Common.ServerConnection" `
		($csb.server)
	}
	$_.csb = $csb
	try # now we make an SMO connection to the server, using the connection string
	{
		$_.srv = new-object ("Microsoft.SqlServer.Management.Smo.Server") $_.ServerConnection
	}
	catch
	{
		Write-error "Could not connect to SQL Server instance $($DataSource.csb.server) $($error[0]). Script is aborted"
		exit -1
	}
} <# all this work just to maintain passwords ! #>
if ($DataSource -ne $null)
{
	$DirectoryToSaveTo = $DataSource.csb.server.Replace('\', $slash)
	if ($DataSource.srv.Version -eq $null) { Throw "Can't find the instance $($DataSource.csb.server)" }
	Write-verbose "writing data out to $directoryToSaveTo"
	$DataSource.srv.Databases[$Databases.source].Tables | Select Name, Schema |
	foreach{
    <# calculate where it should be saved #>
		$directory = "$($FilePath)\$($DirectoryToSaveTo)\$($Databases.Source)\Data"
    <# check that the directory exists #>
		if (-not (Test-Path -PathType Container $directory))
		{
      <# we create the  directory if it doesn't already exist #>
			$null = New-Item -ItemType Directory -Force -Path $directory;
		}
		$filename = "$($_.Schema)_$($_.Name)" -replace '[\\\/\:\.]', '-'
		Write-Verbose "Writing out $($_.Schema).$($_.Name) t0 $($directory)\$filename.bcp"
		If ($DataSource.csb.'user id' -eq '')<# OK. Easy, a trusted connection #>
		{
			#native format -n, Trusted connection -T
			$Progress = BCP "$($_.Schema).$($_.Name)"  out  "$($directory)\$filename.bcp"   `
							-n -T "-d$($Databases.source)"  "-S$($DataSource.csb.server)"
		}
		else <# if not a trusted connection we need to provide a userid and password #>
		{
			
			$Progress = BCP "$($_.Schema).$($_.Name)"  out  "$($directory)\$($_.Schema)_$($_.Name).bcp"  `
							-n "-d$($Databases.source)"  "-S$($DataSource.csb.server)"  `
							"-U$($DataSource.csb.'user id')" "-P$($DataSource.csb.password)"
		}
		
		if (-not ($?) -or $Progress -like '*Error*') # if there was an error
		{
			throw ("Error with data export of $($directory)\$($_.Schema)_$($_.Name).bcp - $Progress");
		}
	}
}
if ($DataTarget -ne $null)
{
	if ($DataSource -ne $null) { $DirectoryToLoadFrom = $DataSource.csb.server.Replace('\', $slash) }
	else { $DirectoryToLoadFrom = $FileSourceDirectory }
	if ($DataTarget.srv.Version -eq $null) { Throw "Can't find the instance $($DataTarget.csb.server)" }
	If ($DataTarget.srv.Databases[$Databases.target] -eq $null)
	{ Throw "Can't find the database $($Databases.target) on instance $($DataTarget.csb.server)" }
	Write-verbose "Reading data in from $DirectoryToLoadFrom"
	
	$DataTarget.srv.Databases[$Databases.target].Tables | Select Name, Schema |
	foreach {
		# calculate where it gotten from #
		$directory = "$($FilePath)\$($DirectoryToLoadFrom)\$($Databases.Source)\Data"
		$filename = "$($_.Schema)_$($_.Name)" -replace '[\\\/\:\.]', '-'
		$progress = '';
		Write-Verbose "Reading in $($_.Schema).$($_.Name) from $($directory)\$filename.bcp"
		if ($DataTarget.csb.'user id' -ne '')
		{
			$Progress = BCP "$($Databases.target).$($_.Schema).$($_.Name)" in "$($directory)\$filename.bcp" -q -N -E `
							"-U$($DataTarget.csb.'user id')"  "-P$($DataTarget.csb.password)" "-S$($DataTarget.csb.server)"
		}
		else
		{
			$Progress = BCP "$($Databases.target).$($_.Schema).$($_.Name)" in `
							"$($directory)\$filename.bcp" -q -N -T -E `
							"-S$($DataTarget.csb.server)"
		}
		if (-not ($?) -or $Progress -like '*Error*') # if there was an error
		{
			throw ("Error with data import  of $($directory)\$($_.Schema)_$($_.Name).bcp - $Progress ");
		}
	}
	try # now we make an SMO connection to the server, using the connection string
	{
		$DataTarget.srv.ConnectionContext.ExecuteNonQuery(" use [$($Databases.target)]   EXEC sp_msforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all'")
	}
	catch
	{
		Write-error "there was a constraint error!  Script is aborted"
		exit -1
	}
}


"I have done my best to obey, Master. "