# Build KABE PRIVATE v2 Module
$moduleDir = "kabe-module-v2"
$output = "kabe-private-v2.zip"

if (Test-Path $output) { Remove-Item $output -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open((Join-Path $PWD $output), 'Create')

function Add-ZipEntry($zip, $file, $relativePath) {
    $entry = $zip.CreateEntry($relativePath, 'Optimal')
    $entryStream = $entry.Open()
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $entryStream.Write($bytes, 0, $bytes.Length)
    $entryStream.Close()
}

$metaDir = Join-Path $moduleDir "META-INF\com\google\android"
Add-ZipEntry $zip (Join-Path $metaDir "update-binary") "META-INF/com/google/android/update-binary"
Add-ZipEntry $zip (Join-Path $metaDir "updater-script") "META-INF/com/google/android/updater-script"

foreach ($f in @("module.prop","service.sh","customize.sh","uninstall.sh")) {
    Add-ZipEntry $zip (Join-Path $moduleDir $f) $f
}

Add-ZipEntry $zip (Join-Path $moduleDir "webroot\index.html") "webroot/index.html"

$zip.Dispose()

Write-Output "ZIP: $output ($((Get-Item $output).Length) bytes)"
