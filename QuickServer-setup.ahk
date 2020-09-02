FileCreateDir, %A_Temp%\QuickServer
SetWorkingDir, %A_Temp%\QuickServer
DefaultDir := A_AppData "\.QuickServer\"
FileCreateDir, %DefaultDir%
#notrayicon

Progress,,Downloading...,Installing QuickServer, QuickServer-setup
Progress, 0
Progress, 10

URLDownloadToFile,https://github.com/mkzeender/QuickServerMC/archive/master.zip, QuickServerDownload.zip
Progress, 30
runwait, tar.exe -x -f QuickServerDownload.zip,,hide
SetWorkingDir, %A_Temp%\QuickServer\QuickServerMC-master
If not FileExist("QuickServer.ahk") {
	Progress, hide
	msgbox,0x10,, Install Failed. Connect to the internet and try again.
	ExitApp
}

Progress,50
FileCopy, %A_ScriptDir%\QuickServer-setup.exe, %DefaultDir%\QuickServer.exe
FileCopy, QuickServer.ahk, %DefaultDir%\QuickServer.ahk
FileCopy, QuickServer.ico, %DefaultDir%\QuickServer.ico
FileCopy, quickserveruhc.zip, %DefaultDir%\quickserveruhc.zip

Progress,65

SetWorkingDir, %DefaultDir%

If not FileExist("ngrok.exe") {
	If A_Is64bitOS {
		URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-amd64.zip, ngrok.zip
	}
	Else {
		URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-386.zip, ngrok.zip
	}
	try runwait, tar.exe -x -f ngrok.zip
}
If not FileExist("quickserveruhc.zip") {
	URLDownloadToFile, https://github.com/mkzeender/QuickServerMC/raw/master/quickserveruhc.zip,quickserveruhc.zip
}
Progress, 95

FileCreateShortcut, %DefaultDir%\QuickServer.exe, %A_Programs%\QuickServer.lnk, %A_WorkingDir%,,Create and manage Minecraft Spigot Servers,%A_WorkingDir%\QuickServer.ico

FileRemoveDir, %A_Temp%\QuickServer, 1

Progress,100

Run, QuickServer.exe