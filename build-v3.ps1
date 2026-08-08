$moduleDir = "kabe-v3"
$output = "kabe-v3.zip"
if (Test-Path $output) { Remove-Item $output -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open((Join-Path $PWD $output), 'Create')
function Add-Zip($zip,$file,$rel){$e=$zip.CreateEntry($rel,'Optimal');$s=$e.Open();$b=[System.IO.File]::ReadAllBytes($file);$s.Write($b,0,$b.Length);$s.Close()}
$md=Join-Path $moduleDir "META-INF\com\google\android"
Add-Zip $zip (Join-Path $md "update-binary") "META-INF/com/google/android/update-binary"
Add-Zip $zip (Join-Path $md "updater-script") "META-INF/com/google/android/updater-script"
foreach($f in @("module.prop","service.sh","customize.sh","uninstall.sh")){Add-Zip $zip (Join-Path $moduleDir $f) $f}
Add-Zip $zip (Join-Path $moduleDir "webroot\index.html") "webroot/index.html"
$zip.Dispose()
Write-Output "ZIP: $output ($((Get-Item $output).Length) bytes)"
