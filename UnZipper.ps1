[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )

$directory = "C:\src\PowerShellUnZip"
$targetDirectory = "C:\src\PowerShellMovedTo"
$zipFiles = Get-ChildItem -Recurse -Path $directory -Filter *.zip | Select-Object -Property FullName

if (!(Test-Path $targetDirectory)){
    Write-Host "Target Directory $($targetDirectory) Does Not Exist - Creating It"
    New-Item -Path $targetDirectory -ItemType Directory -Force
    Write-Host "$($targetDirectory) Created"
}



Write-Host "Found $(($zipFiles | Measure-Object).Count) .zip Files"

while (($zipFiles | Measure-Object).Count -gt 0){
    foreach($zipFile in $zipFiles){
        Write-Host "Extracting $($zipFile.FullName) to $($directory)"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName,$directory)
        Write-Host "Deleting Zip File $($zipFile.FullName)"
        Remove-Item -Path $zipFile.FullName
    }
    $zipFiles = Get-ChildItem -Path $directory -Filter *.zip
}


$txtFiles = Get-ChildItem -Recurse -Path $directory -Filter *.txt | Select-Object -Property FullName

Write-Host "Found $(($txtFiles | Measure-Object).Count) .txt Files To Move"

foreach($txtFile in $txtFiles){
    Write-Host "Moving File $($txtFile.FullName) to $($targetPath)"
    Move-Item -Path $txtFile.FullName -Destination $targetPath 
}

do {
  $dirs = gci $directory -directory -recurse | Where { (gci $_.fullName).count -eq 0 } | select -expandproperty FullName
  $dirs | Foreach-Object { Remove-Item $_ }
} while ($dirs.count -gt 0)
