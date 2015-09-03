param ($ServerUrl, $JobName, $PreviousBuildNumber = $null)

$ErrorActionPreference = 'Stop'

$version = '0.0.2'
Write-Output "jincremental-packer v. $version"

Remove-Item ".\*_incremental.zip"

$jobUrl = "$ServerUrl/job/$JobName"
$buildNumber = (Invoke-WebRequest -UseBasicParsing "$jobUrl/lastSuccessfulBuild/buildNumber").Content
$buildDetails = ConvertFrom-Json (Invoke-WebRequest -UseBasicParsing "$jobUrl/$buildNumber/api/json").Content
if ($PreviousBuildNumber -eq $null) {
    $PreviousBuildNumber = $buildNumber - 1
}

function Get-Artifact ($jobData, $outPath) {
  $artifact = $jobData.artifacts[0]
  $url = "$($jobData.url)/artifact/$($artifact.relativePath)"
  Invoke-WebRequest -UseBasicParsing $url -OutFile $outPath
}

$jobDirectory = "$env:TEMP\Prepare-Release\$JobName"
if (-not (Test-Path $jobDirectory)) {
  New-Item -Path $jobDirectory -Type Directory
}

function Download-Artifact ($buildNumber) {
  $details = ConvertFrom-Json (Invoke-WebRequest -UseBasicParsing "$jobUrl/$buildNumber/api/json").Content
  Get-Artifact $details "$jobDirectory\$buildNumber.zip"
}

Download-Artifact $buildNumber
Download-Artifact $PreviousBuildNumber

function Unzip-Artifact ($buildNumber) {
  $sourceFile = "$jobDirectory\$buildNumber.zip"
  $targetFolder = "$jobDirectory\$buildNumber"
  if (Test-Path $targetFolder) {
    Remove-Item -Recurse -Force $targetFolder
  }

  [IO.Compression.ZipFile]::ExtractToDirectory($sourceFile, $targetFolder)
}

[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
Unzip-Artifact $buildNumber
Unzip-Artifact $PreviousBuildNumber

$resultDirectory = "$jobDirectory\$PreviousBuildNumber-$buildNumber"
if (Test-Path $resultDirectory) {
  Remove-Item -Recurse -Force $resultDirectory
}

New-Item -Path $resultDirectory -Type Directory

& "$PSScriptRoot\Diff.ps1" "$jobDirectory\$PreviousBuildNumber" "$jobDirectory\$buildNumber" $resultDirectory
Get-Content "$resultDirectory\Uploads.txt" | % {
  $fileName = $_
  $resultPath = "$resultDirectory\$fileName"
  $directory = [IO.Path]::GetDirectoryName($resultPath)
  if (-not (Test-Path $directory)) {
    New-Item -Path $directory -Type Directory
  }

  Copy-Item "$jobDirectory\$buildNumber\$fileName" "$resultDirectory\$fileName"
}

$resultFileName = [IO.Path]::GetFileNameWithoutExtension($buildDetails.artifacts[0].fileName)
Write-Zip "$resultDirectory\*" ".\${resultFileName}_incremental.zip"
