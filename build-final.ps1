$d="kabe-final";$o="kabe-final.zip"
if(Test-Path $o){Remove-Item $o -Force}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z=[System.IO.Compression.ZipFile]::Open((Join-Path $PWD $o),'Create')
function A($z,$f,$r){$e=$z.CreateEntry($r,'Optimal');$s=$e.Open();$b=[System.IO.File]::ReadAllBytes($f);$s.Write($b,0,$b.Length);$s.Close()}
$m=Join-Path $d "META-INF\com\google\android"
A $z (Join-Path $m "update-binary") "META-INF/com/google/android/update-binary"
A $z (Join-Path $m "updater-script") "META-INF/com/google/android/updater-script"
foreach($f in @("module.prop","service.sh","customize.sh","uninstall.sh")){A $z (Join-Path $d $f) $f}
A $z (Join-Path $d "webroot\index.html") "webroot/index.html"
$z.Dispose()
Write-Output "ZIP: $o ($((Get-Item $o).Length) bytes)"
