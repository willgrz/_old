foreach ($file in Get-ChildItem -name -exclude unpack.ps1) { 
cd $file
$SFV = ls -name -include *.sfv
C:\srr.exe "$PWD\$SFV" -s *.nfo
$rarfile = ls -name -include *.rar -exclude *.part*.*
if (!$rarfile) { $rarfile = ls -name -include *.part01.rar }
if (!$rarfile) { $rarfile = ls -name -include *.001 }
rar x $rarfile
$rmfile = ls -name -exclude *.avi,*.srr,*.mkv
rm -recurse $rmfile
cd ..
echo $file "Rescened, Unrared and files deleted!"
}
