# PowerShell script to build deployment package for KolkaUICameras
# Run this script from the project root directory

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputFile = Join-Path $projectRoot "KolkaUICameras.zip"
$appZipFile = Join-Path $projectRoot "app.zip"

Write-Host "=== Building KolkaUICameras deployment package ===" -ForegroundColor Cyan
Write-Host "Project root: $projectRoot"

# Remove old archives
if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
if (Test-Path $appZipFile) { Remove-Item $appZipFile -Force }

# Create temporary staging directory for app files
$tempDir = Join-Path $env:TEMP "KolkaUICameras_build"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Host "Building app.zip..."

# Copy root files
$rootFiles = @("app.py", "config.py", "models.py", "calibration.py", "config_loader.py", "kolka_snapshot_and_download.py", "compress_images.py", "appsettings.json", "requirements.txt")
foreach ($file in $rootFiles) {
    $source = Join-Path $projectRoot $file
    if (Test-Path $source) {
        Copy-Item $source -Destination $tempDir
        Write-Host "  + $file" -ForegroundColor Gray
    }
}

# Copy routes directory
$routesSource = Join-Path $projectRoot "routes"
if (Test-Path $routesSource) {
    Copy-Item $routesSource -Destination (Join-Path $tempDir "routes") -Recurse
    Write-Host "  + routes/" -ForegroundColor Gray
}

# Copy templates
$templatesSource = Join-Path $projectRoot "templates"
if (Test-Path $templatesSource) {
    Copy-Item $templatesSource -Destination (Join-Path $tempDir "templates") -Recurse
    Write-Host "  + templates/" -ForegroundColor Gray
}

# Copy static
$staticSource = Join-Path $projectRoot "static"
if (Test-Path $staticSource) {
    Copy-Item $staticSource -Destination (Join-Path $tempDir "static") -Recurse
    Write-Host "  + static/" -ForegroundColor Gray
}

# Copy SQL scripts
$sqlSource = Join-Path $projectRoot "sql"
if (Test-Path $sqlSource) {
    Copy-Item $sqlSource -Destination (Join-Path $tempDir "sql") -Recurse
    Write-Host "  + sql/" -ForegroundColor Gray
}

# Create app.zip and fix backslash paths for Linux compatibility
Write-Host "Creating app.zip..."
Compress-Archive -Path "$tempDir\*" -DestinationPath $appZipFile -CompressionLevel Optimal
Remove-Item $tempDir -Recurse -Force

# Fix backslash paths in zip for Linux
Write-Host "Fixing zip paths for Linux..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmpZip = $appZipFile + '.tmp'
$srcZip = [System.IO.Compression.ZipFile]::OpenRead($appZipFile)
$dstZip = [System.IO.Compression.ZipFile]::Open($tmpZip, 'Create')
foreach ($entry in $srcZip.Entries) {
    $fixedName = $entry.FullName -replace '\\', '/'
    $newEntry = $dstZip.CreateEntry($fixedName, [System.IO.Compression.CompressionLevel]::Optimal)
    if ($entry.Length -gt 0) {
        $src = $entry.Open()
        $dst = $newEntry.Open()
        $src.CopyTo($dst)
        $dst.Dispose()
        $src.Dispose()
    }
}
$srcZip.Dispose()
$dstZip.Dispose()
Remove-Item $appZipFile
Rename-Item $tmpZip $appZipFile
Write-Host "  Paths fixed" -ForegroundColor Gray

Write-Host "Creating KolkaUICameras.zip..."

# Create final package directory
$packageDir = Join-Path $env:TEMP "KolkaUICameras_package"
if (Test-Path $packageDir) { Remove-Item $packageDir -Recurse -Force }
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# Copy app.zip
Copy-Item $appZipFile -Destination $packageDir
Remove-Item $appZipFile

# Copy scripts to root of package
$scriptsSource = Join-Path $projectRoot "scripts"
$scriptsToInclude = @("install-KolkaUICameras.sh", "update-KolkaUICameras.sh", "verify-KolkaUICameras.sh")
foreach ($script in $scriptsToInclude) {
    $scriptSource = Join-Path $scriptsSource $script
    if (Test-Path $scriptSource) {
        Copy-Item $scriptSource -Destination $packageDir
        Write-Host "  + $script" -ForegroundColor Gray
    }
}

# Create final zip
Compress-Archive -Path "$packageDir\*" -DestinationPath $outputFile -CompressionLevel Optimal
Remove-Item $packageDir -Recurse -Force

# Show result
$archiveSize = (Get-Item $outputFile).Length / 1KB
Write-Host ""
Write-Host "=== Package created successfully ===" -ForegroundColor Green
Write-Host "File: $outputFile"
Write-Host "Size: $([math]::Round($archiveSize, 1)) KB"
Write-Host ""
Write-Host "Archive contents:" -ForegroundColor Cyan
Write-Host "  - app.zip (application files)"
Write-Host "  - install-KolkaUICameras.sh"
Write-Host "  - update-KolkaUICameras.sh"
Write-Host "  - verify-KolkaUICameras.sh"
