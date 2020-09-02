@echo off
mkdir %appdata%\.QuickServer\bin
cd %appdata%\.QuickServer\bin
If NOT Exist Autohotkey.exe (
curl -z QuickServer.ahk -o QuickServer.ahk https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/QuickServer.ahk
curl -z Autohotkey.zip -o Autohotkey.zip https://www.autohotkey.com/download/ahk.zip
tar -x -f Autohotkey.zip
)
start "" Autohotkey.exe QuickServer.ahk
