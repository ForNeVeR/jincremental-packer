param (
    $OldVersion,
    $NewVersion,
    $Output = $NewVersion
)

$OldVersion = $OldVersion.TrimEnd('\')
$NewVersion = $NewVersion.TrimEnd('\')

function FileFilter($file) {
    -not (($file.Name -in @('Deletes.txt', 'Uploads.txt'))
      -or ($file.FullName.Split('/\') -contains 'App_Data'))
}

$oldVersionFiles = Get-ChildItem $OldVersion -Recurse | ? { -not $_.PSIsContainer -and (FileFilter($_)) }
$newVersionFiles = Get-ChildItem $NewVersion -Recurse | ? { -not $_.PSIsContainer -and (FileFilter($_)) }

function Hash($file) {
    $md5 = [Security.Cryptography.HashAlgorithm]::Create('MD5')
    $stream = ([IO.StreamReader]$file).BaseStream
    $hash = -join ($md5.ComputeHash($stream) | ForEach { "{0:x2}" -f $_ })
    Write-Host "$($file): $hash"
    $hash
}

function UpdatedFile($relativePath) {
    $oldFile = Join-Path $OldVersion $relativePath
    $newFile = Join-Path $NewVersion $relativePath
    if (-not (Test-Path $oldFile)) {
        $true
    } else {
        $oldHash = Hash($oldFile)
        $newHash = Hash($newFile)
        $oldHash -ne $newHash
    }
}

if (Test-Path "$Output\Uploads.txt") {
  Remove-Item "$Output\Uploads.txt" -Force
}

if (Test-Path "$Output\Deletes.txt") {
  Remove-Item "$Output\Deletes.txt" -Force
}

$newVersionFiles | % {
    $relativePath = & "$PSScriptRoot\Get-RelativePath.ps1" $NewVersion $_.FullName
    if (UpdatedFile $relativePath) {
        $relativePath >> "$Output\Uploads.txt"
    }
}

$oldVersionFiles | % {
    $relativePath = & "$PSScriptRoot\Get-RelativePath.ps1" $OldVersion $_.FullName
    if (-not (Test-Path (Join-Path $NewVersion $relativePath))) {
        $relativePath >> "$Output\Deletes.txt"
    }
}
