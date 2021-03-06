#NVD CPE Functions
#Created 7/22/2014
#brinkn@nationwide.com

#Used to contain functions related to CPEs (Common Platform Enumeration)
#Designed to implement the concepts described in this document to convert to and from CPE22 and CPE23 formats
#http://csrc.nist.gov/publications/nistir/ir7695/NISTIR-7695-CPE-Naming.pdf
#https://cpe.mitre.org/specification/

##TODO
#Finish out the problems with pulling out non-approved characters in the setWFNAttribute function
[Reflection.Assembly]::LoadFile("C:\MyStuff\TestDev\PowerShellScripts\NWNVD\ps_cpe\CPE.dll")
import-module SQLite #http://psqlite.codeplex.com/

Function GetStats {
	Param(
		[object]$Scores)
	Write-Verbose "Counting number of CVE's and their scores"
	$objRecord = New-Object System.Object
	$High = 0
	$Medium = 0
	$Low = 0
	$Score_String = ""
	
	foreach($score in $Scores){
		switch ($score.Severity) 
		    { 
		        HIGH {$High++} 
		        MEDIUM {$Medium++} 
		        LOW {$Low++} 
		        default {}
		    }
		$Score_String = $score_String + ":" + $score.Score

	}
	if($High -eq 0){$HIGH ="-"}
	if($Medium -eq 0){$Medium ="-"}
	if($Low -eq 0){$Low ="-"}
	$objRecord | Add-Member -NotePropertyName HIGH -NotePropertyValue $HIGH
	$objRecord | Add-Member -NotePropertyName MEDIUM -NotePropertyValue $MEDIUM
	$objRecord | Add-Member -NotePropertyName LOW -NotePropertyValue $LOW
	$objRecord | Add-Member -NotePropertyName SCORES -NotePropertyValue $Score_String
	return $objRecord
}



#Start Metrics
$sw = [Diagnostics.Stopwatch]::StartNew()

#Mount Database
#attach to db
#$DatabaseFile = "C:\MyStuff\TestDev\PowerShellScripts\NWNVD\NVDDB_test.db" 
$DatabaseFile = "C:\MyStuff\TestDev\PowerShellScripts\NWNVD\NVDDB.db" 
mount-sqlite -name NVDDB -dataSource $DatabaseFile

#Do some SQL Queries
#$myCPE = Get-ChildItem NVDDB:/CPE
$cpeQuery = "select * from CPE"
$cveQuery = "SELECT C.cve_id,C.score as Score, C.severity as Severity , A.cpe 
     FROM CVE C      
          JOIN (SELECT cpe,cve_id
              FROM Application 
               ) A ON C.cve_id = A.cve_id where a.cpe = "
$nvdURL = "http://web.nvd.nist.gov/view/vuln/search-results?adv_search=true&cves=on&cpe_version="			   
$myData = invoke-item NVDDB: -sql $cpeQuery

#$myData | Select-Object cpe, title, cpe23 | Export-Csv -Path C:\MyStuff\TestDev\PowerShellScripts\NWNVD\ps_cpe\cpe.csv -Encoding ascii -NoTypeInformation
$i=0
foreach($item in $myData){
	#Clear some Vars
	$myScores = ""

		if(($i % 500) -eq 0){
		Write-Host "$i records, restarting the database connection"
		Remove-PSDrive NVDDB
		mount-sqlite -name NVDDB -dataSource $DatabaseFile
		}
	
	#Create a container for our excel row
	$objRecord = New-Object System.Object
	
	#$item contains each CPE, need to turn this into a WFN for the excel file
	$myWFN = [CPE.CPENameUnbinder]::unbindURI($item.cpe)
	$objRecord = $myWFN.myWFN
	
	#Get a count of High, Medium and Low, and create an array of scores.
	$testsql = $cveQuery + "'" + $item.cpe +"'"
	#the @() is to force the return of a collection, even if empty
	
	$myScores = @(Invoke-Item NVDDB: -sql $testsql)
	
	$objRecord | Add-Member -NotePropertyName CPE -NotePropertyValue $item.cpe
	#get list of scores
	if ($myScores.Count -gt 0) {
		$myResult = GetStats $myScores
		$objRecord | Add-Member -NotePropertyName HIGH -NotePropertyValue $myResult.HIGH
		$objRecord | Add-Member -NotePropertyName MEDIUM -NotePropertyValue $myResult.MEDIUM
		$objRecord | Add-Member -NotePropertyName LOW -NotePropertyValue $myResult.LOW
		$objRecord | Add-Member -NotePropertyName SCORES -NotePropertyValue $myResult.Scores.substring(1)
		$myReference = $nvdURL + $item.cpe
		$objRecord | Add-Member -NotePropertyName REFERENCE -NotePropertyValue $myReference
	}
	#replace \ with nothing, repalce underscore with space to improve readability
	$objRecord.VENDOR = $objRecord.VENDOR.Replace("\","")
	$objRecord.PRODUCT = $objRecord.PRODUCT.Replace("\","")
	$objRecord.VENDOR = $objRecord.VENDOR.Replace("_"," ")
	$objRecord.PRODUCT = $objRecord.PRODUCT.Replace("_"," ")
	$objRecord.VERSION = $objRecord.version.Replace("\","")
	
	#repalce 0's with blanks.
	$objRecord.UPDATE = $objRecord.UPDATE.Replace("0","")
	$objRecord.EDITION = $objRecord.EDITION.Replace("0","")
	$objRecord.LANGUAGE = $objRecord.LANGUAGE.Replace("0","")
	$objRecord.SW_EDITION = $objRecord.SW_EDITION.Replace("0","")
	$objRecord.TARGET_SW = $objRecord.TARGET_SW.Replace("0","")
	$objRecord.TARGET_HW = $objRecord.TARGET_HW.Replace("0","")
	$objRecord.OTHER = $objRecord.OTHER.Replace("0","")
	
	$objRecord | Select-Object CPE, PART, VENDOR, PRODUCT, VERSION, UPDATE, EDITION, LANGUAGE, SW_EDITION, TARGET_SW, TARGET_HW, OTHER, HIGH, MEDIUM, LOW, SCORES,REFERENCE | Export-Csv -Path C:\MyStuff\TestDev\PowerShellScripts\NWNVD\ps_cpe\cpe.csv -Encoding ascii -NoTypeInformation -Append
	#$myWFN.myWFN | Select-Object PART, VENDOR, PRODUCT, VERSION, UPDATE, EDITION, LANGUAGE, SW_EDITION, TARGET_SW, TARGET_HW, OTHER, $test | Export-Csv -Path C:\MyStuff\TestDev\PowerShellScripts\NWNVD\ps_cpe\cpe.csv -Encoding ascii -NoTypeInformation -Append
	$i++
}

#$wfn= [CPE.CPENameUnbinder]::unbindURI("cpe:/a:microsoft:internet_explorer%01%01%01%01:?:beta")

Remove-PSDrive NVDDB

#write metrics
$sw.Stop()
write-verbose "Time Elapsed: $($sw.Elapsed)"
write-host "Time Elapsed: $($sw.Elapsed)"