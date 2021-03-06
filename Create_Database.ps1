#NVD Create Database
#Created 7/18/2014
#updated 9/2/2014
#brinkn@nationwide.com

#Used to create a database to put NVD data into
#Relies on Powershell Addin from 
#http://psqlite.codeplex.com/wikipage?title=Creating%20Tables&referringTitle=Documentation

#allows for creation of a blank access or sqlite3 database

##NOTE:  If you get a message similar to:
#Exception calling "Open" with "0" argument(s): "The 'Microsoft.ACE.OLEDB.12.0' provider is not registered on the local machine."
#You will need to either change the connection string for your database version, or more likly you have a 32bit office version installed and are running powershell in 64bit.  run the script as 32 bit.

##TODO
#Figure a way to deal with the bracket problem in file names

##Inputs
[CmdletBinding(DefaultParametersetName="Create")]
[CmdletBinding()]
param(	[switch]$help,
		[string]$DatabaseFile,		#The default name to use
		[string]$scriptpath = $MyInvocation.MyCommand.Path, 	#The directory to store files
		[switch]$Clean = $false,									#If true, drop and recreate tables
		[switch]$Access = $false									#If true, create an access database
	)


##Load Assemblies
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
import-module SQLite 	#http://psqlite.codeplex.com/

##Variables
$Filter = 'All Files|*.*'

##Functions
function Write-HelpMessage(){
	$USAGE='Vulnerability Database Creator Tool
Created by brinkn@nationwide.com

	Parameters:             
	-Help                          (This Message)
	-Database	   <FILENAME>      (Name of Database to create)
	-Clean						   (Drop all tables and recreate)
	-Access						   (Create an Access MDB file instead of SQLite)

	        '
	Write-host $usage
}
Function FileExists {
	Param(
		[string]$FileName="")  #Name of file to check
	Write-Verbose "Checking for existance of $FileName"
	$result = Test-Path -path $FileName 
	if ($result){Write-Verbose "The file $FileName exists."}else{Write-Verbose "The file $FileName does not exist."}
	return $result
}
Function GetFileLocation($StartDirectory, $Filter){
	#Powershell tip of the day
	#http://s1403.t.en25.com/e/es.aspx?s=1403&e=85122&elq=7b9bf21b612743dea14c73c513d956f9
	$dialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog

	$dialog.AddExtension = $true
	$dialog.Filter = $filter
	$dialog.Multiselect = $false
	$dialog.FilterIndex = 0
	$dialog.InitialDirectory = $StartDirectory
	$dialog.RestoreDirectory = $true
	#$dialog.ShowReadOnly = $true
	$dialog.ReadOnlyChecked = $false
	$dialog.Title = 'Select a Database File'
	$dialog.checkfileexists = $false

	$result = $dialog.ShowDialog()
	if ($result -eq 'OK')
	{
	    $filename = $dialog.FileName
	    $readonly = $dialog.ReadOnlyChecked
	    if ($readonly) { $mode = 'read-only' } else {$mode = 'read-write' }
		return $filename
	} else {return "cancel"} 
}
Function Create-AccessDatabase($Db){
 	$application = New-Object -ComObject 'ADOX.Catalog'
	$application.Create("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$db") | Out-Null
} #End Create-AccessDatabase
Function Invoke-ADOCommand($Db, $Command){
 $connection = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Db")
 $connection.Open()
 $cmd = New-Object System.Data.OleDb.OleDbCommand($Command, $connection) 
 $cmd.ExecuteNonQuery()  | Out-Null
} #End Invoke-ADOCommand

##Begin Program
Write-Host "NVD Database Creator 1.0"

##Parameter Checking
#Check if help message was requested
if ($help) {Write-HelpMessage;break}

#Start Metrics
$sw = [Diagnostics.Stopwatch]::StartNew()

if ($DatabaseFile.length -le 1) {
	#Since there was not a filename provided on the command line, go ahead and ask for one.
	$scriptpath = $MyInvocation.MyCommand.Path
	$scriptpath = Split-Path $scriptpath
	$DatabaseFile = GetFileLocation $scriptpath $filter 	#file with policy information
	if ($DatabaseFile -eq "cancel"){write-host "Exiting..."; exit}	#On cancel, exit
}

Write-Verbose "Database file: $databaseFile"
Write-Verbose "Clean Flag: $Clean"

# Check if file exists, if not error out.
if((fileexists($databaseFile)) -AND (!($Clean))){Write-Host "The file: $databaseFile exists.  To recreate add the Clean flag";break}

$strCVETable =  "[cve_id] TEXT(15) PRIMARY KEY NOT NULL UNIQUE,
		published TEXT,
		modified TEXT,
		summary TEXT,
		score TEXT(5),
		severity TEXT(8),
		vector TEXT(15),
		complexity TEXT(15),
		authentication TEXT(15),
		confidentiality TEXT(15),
		integrity TEXT(15),
		availability TEXT(15),
		cwe TEXT(15)" 
$strApplicationTable = "cpe TEXT(100),
		cve_id TEXT(15)"
$strReferenceTable = "cve_id TEXT(15),
		type TEXT(30),
		source TEXT(30),
		reference TEXT(255)"	
$strCPETable = "cpe TEXT(100) PRIMARY KEY NOT NULL UNIQUE,
		title TEXT,
		reference TEXT,
		cpe23 TEXT(100)"
$strWFNTable = "cpe TEXT(100) PRIMARY KEY NOT NULL UNIQUE,
		part TEXT(50),
		vendor TEXT(60),
		product TEXT(100),
		version TEXT(50),
		[update] TEXT(50),
		edition TEXT(50),
		[language] TEXT(50),
		sw_edition TEXT(50),
		target_sw TEXT(50),
		target_hw TEXT(50),
		other TEXT,
		reference TEXT"
		
$strMTFTable = "CVE TEXT(20) PRIMARY KEY NOT NULL UNIQUE,
		recommendation TEXT,
		vector TEXT(25),
		productid TEXT(4),
		productname TEXT(50),
		mitigationcoverage TEXT(255)"	

if($Access) { 
	write-host "This will be an access database"
	if($Clean){
		Write-Verbose "Attempting to remove tables"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table CVE"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table Application"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table CPE"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table Reference"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table WFN"
	Invoke-ADOCommand -db $DatabaseFile -command "DROP Table MTF"
	} else {
		Create-AccessDatabase -db $DatabaseFile
		$table = "CVE" 
	}
	$command = "Create Table CVE `($strCVETable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command
	$command = "Create Table Application `($strApplicationTable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command
	$command = "Create Table CPE `($strCPETable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command
	$command = "Create Table Reference `($strReferenceTable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command		
	$command = "Create Table WFN `($strWFNTable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command		
	$command = "Create Table MTF `($strMTFTable`)"
	Invoke-ADOCommand -db $DatabaseFile -command $command	
} else {
	#attempt to create a SQLite3 NVDDB Database
	write-host "This will be a SQLite database"
	mount-sqlite -name NVDDB -dataSource $DatabaseFile |Out-Null

	if($Clean){
	Write-Verbose "Attempting to remove tables"
		Remove-Item -Path NVDDB:/CVE |Out-Null
		Remove-Item -Path NVDDB:/Application |Out-Null
		Remove-Item -Path NVDDB:/CPE |Out-Null
		Remove-Item -Path NVDDB:/Reference |Out-Null
		Remove-Item -Path NVDDB:/WFN |Out-Null
		Remove-Item -Path NVDDB:/MTF |Out-Null
	}

	#Load the Schema for CVE
	Write-Verbose "Creating CVE table"
	new-item -path NVDDB:/CVE -value  $strCVETable |Out-Null

	#Load the Schema for CVE - CPE
	#Applications with CVE NVDDB
	Write-Verbose "Creating Application table"
	new-item -path NVDDB:/Application -value $strApplicationTable |Out-Null

	#Load the Schema for CPE - which are all known applications
	#Common Platform Enumeration (CPE) Dictionary
	#http://nvd.nist.gov/cpe.cfm
	Write-Verbose "Creating CPE table"
	new-item -path NVDDB:/CPE -value $strCPETable |Out-Null
	
	#Load the Schema for References - Which contains links to vendor advisories
	Write-Verbose "Creating References table"
	new-item -path NVDDB:/Reference -value $strReferenceTable |Out-Null
		
	#Load the Schema for WFN - Which will be generated later user WFN dll
	Write-Verbose "Creating WFN table"
	new-item -path NVDDB:/WFN -value $strWFNTable |Out-Null
	
	#Load the Schema for WFN - Which will be generated later user WFN dll
	Write-Verbose "Creating MTF table"
	new-item -path NVDDB:/MTF -value $strMTFTable |Out-Null	
	
	#All done end our connection
	Write-Verbose "Closing connection"
	Remove-PSDrive NVDDB
}
#Print Metrics
$sw.Stop()
write-Host "Time Elapsed: $($sw.Elapsed)"
Write-Host "Complete!"
