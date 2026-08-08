# Build KABE PRIVATE Magisk Module
$moduleDir = "files\kabe_module"
$output = "kabe-module.zip"

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

# META-INF (instalador)
$metaDir = Join-Path $moduleDir "META-INF\com\google\android"
Add-ZipEntry $zip (Join-Path $metaDir "update-binary") "META-INF/com/google/android/update-binary"
Add-ZipEntry $zip (Join-Path $metaDir "updater-script") "META-INF/com/google/android/updater-script"

# Arquivos raiz do modulo
foreach ($f in @("module.prop","post-fs-data.sh","service.sh","customize.sh")) {
    Add-ZipEntry $zip (Join-Path $moduleDir $f) $f
}

# Binarios
foreach ($f in @("kabe-agent","kabe-keygen","kabe-server","kabe-setup","kabe-webconfig")) {
    Add-ZipEntry $zip (Join-Path $moduleDir "system\bin\$f") "system/bin/$f"
}

$zip.Dispose()

Write-Output "Module ZIP created: $output"
Write-Output "Size: $((Get-Item $output).Length) bytes"
