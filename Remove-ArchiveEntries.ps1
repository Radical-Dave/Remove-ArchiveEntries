#Set-StrictMode -Version Latest
#####################################################
# Remove-ArchiveEntries
#####################################################
<#PSScriptInfo

.VERSION 0.1
.GUID c87a9681-72b8-4100-90e4-1bc2834ee7e1

.AUTHOR David Walker, Sitecore Dave, Radical Dave

.COMPANYNAME David Walker, Sitecore Dave, Radical Dave

.COPYRIGHT David Walker, Sitecore Dave, Radical Dave

.TAGS powershell archive files entries zip remove

.LICENSEURI https://github.com/SharedSitecore/ConvertTo-Sitecore-WDP/blob/main/LICENSE

.PROJECTURI https://github.com/SharedSitecore/ConvertTo-Sitecore-WDP

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

<# 

.DESCRIPTION 
 PowerShell script to search/remove entries/files in Zip package

.PARAMETER name
Path of package

#> 
#####################################################
# Remove-ArchiveEntries
#####################################################
Param(
	[Parameter(Mandatory=$true)]
	[string] $path,
	[Parameter(Mandatory=$true)]
	[string[]] $search
)
function Remove-ArchiveEntries
{
	Param(
		[Parameter(Mandatory=$true)]
		[string] $path,	
		[Parameter(Mandatory=$true)]
		[string[]] $search
	)
	$ProgressPreference = "SilentlyContinue"
	$results = @()
	Write-Verbose "Remove-ArchiveEntries $path $search"
	try {
		if (($path.IndexOf("/") -eq -1) -or (-not (Test-Path $path)) ) {
			if (Test-Path (Join-Path (Get-Location) $path)) {
				$path = Join-Path (Get-Location) $path
				Write-Verbose "path:$path"
			}
			if (!(Test-Path $path)) {
				throw "ERROR Remove-ArchiveEntries - file not found: $path"
			}
		}
		
		$file = (Split-Path $path -leaf).Replace('.zip', '')
		Write-Verbose "file:$file"
		$tempPackagePath = Join-Path $ENV:TEMP $file
		Write-Verbose "tempPackagePath:$tempPackagePath"
		if (Test-Path $tempPackagePath) { Remove-Item $tempPackagePath -Recurse -Force }
		if (!(Test-Path $tempPackagePath)) { New-Item $tempPackagePath -ItemType Directory | Out-Null }

		Add-Type -AssemblyName System.IO.Compression
		$stream = New-Object IO.FileStream($path, [IO.FileMode]::Open)
		$zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Update)
		foreach($query in $search) {
			Write-Verbose "query:$query"
			$queryResults = @()
			($zip.Entries | Where-Object { $_.FullName -Like $query }) | ForEach-Object {
				Write-Host "Found:$($_.FullName)"
				$_.Delete()
				$queryResults += $_				
			}
			Write-Verbose "query.count:$($queryResults.Length)"
			$results += $queryResults
		}
		Write-Verbose "files:$results"

		$zips = @()
		if ($file -ne 'package') { #SearchStax.zip causes issues
			($zip.Entries | Where-Object { $_.Name -Like '*.zip' }) | ForEach-Object { 
				Write-Host "Found:$($_.FullName)"
				[IO.Compression.ZipFileExtensions]::ExtractToFile($_,"$tempPackagePath\$_",$Overwrite)
				$zips += $_
			}
		}

		if ($zip) {	$zip.Dispose() }
		if ($stream) {
			$stream.Close()
			$stream.Dispose()
		}
	
		Write-Verbose "zips:$zips"

		if ($zips) {
			$tempFolder = $tempPackagePath
			($zips | Where-Object { $_.Name -Like '*.zip' }) | ForEach-Object {
				$tempZipPath = "$tempFolder\$($_.FullName)"
				$resultsNested = Remove-ArchiveEntries $tempZipPath $search
			
				if ($resultsNested.count -gt 0) { 
					Write-Verbose "Changes made to $tempZipPath. Updating $path"
				 	$compress = @{
				 		Path = "$tempZipPath"
				 		DestinationPath = $path }
			
				 	#Compress-Archive -Path $destination\temp\metadata\* -Update -DestinationPath $path -Force
				 	Compress-Archive -Update @compress
				 	Write-Verbose "$path updated."
				}

				$results += $resultsNested
			}
		}
		if (Test-Path $tempPackagePath) { Remove-Item $tempPackagePath -Recurse -Force }
	}
	catch {
		Write-Error "ERROR Remove-ArchiveEntries $($path) $($search):$_"

		if ($zip) {	$zip.Dispose() }
		if ($stream) {
			$stream.Close()
			$stream.Dispose()
		}
	}
	Write-Verbose "results:$results"
	Write-Verbose "results.count:$($results.Length)"
	return $results
}
#cls
Remove-ArchiveEntries $path $search