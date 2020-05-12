[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )

$directory = "C:\src\PowerShellUnZip"
$targetDirectory = "C:\src\PowerShellMovedTo"
$zipFiles = Get-ChildItem -Path $directory -Filter *.zip -Recurse

if (!(Test-Path $targetDirectory)){
    Write-Host "Target Directory $($targetDirectory) Does Not Exist - Creating It"
    New-Item -Path $targetDirectory -ItemType Directory -Force
    Write-Host "$($targetDirectory) Created"
}



Write-Host "Found $(($zipFiles | Measure-Object).Count) .zip Files"

while (($zipFiles | Measure-Object).Count -gt 0){
    foreach($zipFile in $zipFiles){
        $zipPath = Join-Path $directory $zipFile
        Write-Host "Extracting $($zipPath) to $($directory)"
        #[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$directory)
        Write-Host "Deleting Zip Folder $($zipPath)"
        #Remove-Item -Path $zipPath
    }
    $zipFiles = Get-ChildItem -Path $directory -Filter *.zip
}


$txtFiles = Get-ChildItem -Path $directory -Filter *.txt -Recurse

Write-Host "Found $(($txtFiles | Measure-Object).Count) .txt Files To Move"

foreach($txtFile in $txtFiles){
    $txtPath = Join-Path $directory $txtFile
    $targetPath = Join-Path $targetDirectory $txtFile
    Write-Host "Moving File $($txtPath) to $($targetPath)"
    #Move-Item -Path $txtPath -Destination $targetPath 
}
