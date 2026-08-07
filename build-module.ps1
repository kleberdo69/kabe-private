# Build KABE Private Magisk Module
$moduleDir = "files\kabe_module"
$output = "kabe-module.zip"

if (Test-Path $output) { Remove-Item $output -Force }

# Create temp dir with proper structure
$tempDir = "$env:TEMP\kabe_module_build"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Copy module files
Copy-Item -Path "$moduleDir\*" -Destination $tempDir -Recurse -Force

# Create ZIP
Compress-Archive -Path "$tempDir\*" -DestinationPath $output -Force

# Cleanup
Remove-Item $tempDir -Recurse -Force

Write-Output "Module ZIP created: $output"
Write-Output "Size: $((Get-Item $output).Length) bytes"
