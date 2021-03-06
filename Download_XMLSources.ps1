#Vulnerabilty Files Download
#Created 8/29/2014
#brinkn@nationwide.com

#Powershell script to grab xml files from the NVD website
#This includes CVE data, CPE data and CWE data
#Relies on Powershell 
#http://powershell.com/cs/PowerTips_Monthly_Volume_10.pdf

##TODO
#Figure a way to deal with the bracket problem in file names

##Inputs
[CmdletBinding()]
param(	[switch]$help,
		[string]$Directory = $MyInvocation.MyCommand.Path, 		#the location to save files to.  default is current directory
		[string]$scriptpath = $MyInvocation.MyCommand.Path  	#The directory to store files
	)


##Functions
function Write-HelpMessage(){
	$USAGE='SQLite Database Create Tool
Created by brinkn@nationwide.com

	Parameters:             
	-Help                       (This Message)
	-Direction	   <PATH>		(Location to save files)

	        '
	Write-host $usage
}

function Get-WebClient{
 $wc = New-Object Net.WebClient
 $wc.UseDefaultCredentials = $true
 $wc.Proxy.Credentials = $wc.Credentials
 $wc
}


##Begin Program
Write-Host "NVD File Downloader .01"

##Parameter Checking
#Check if help message was requested
if ($help) {Write-HelpMessage;break}

#Start Metrics
$sw = [Diagnostics.Stopwatch]::StartNew()


$myURLS = @("http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2002.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2003.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2004.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2005.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2006.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2007.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2008.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2009.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2010.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2011.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2012.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2013.xml",
 "http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2014.xml",
 "http://static.nvd.nist.gov/feeds/xml/cpe/dictionary/official-cpe-dictionary_v2.3.xml",
 "https://threatfeed.mtis.mcafee.com/ctp/data/2_3/LatestThreats_$(Get-Date -Format yyyy_MM_dd).zip")
 

foreach( $url in $myURLS) {
	$object = Get-WebClient
	#$object.DownloadFile($url,$URL.Substring($URL.LastIndexOf("/") + 1))
	Invoke-WebRequest $url -OutFile $URL.Substring($URL.LastIndexOf("/") + 1)
}

#Print Metrics
$sw.Stop()
Write-Host "Complete!"
write-verbose "Time Elapsed: $($sw.Elapsed)"