DefaultDir := A_AppData "\.QuickServer\"
FileCreateDir, %DefaultDir%
SetWorkingDir, %DefaultDir%
#notrayicon

FileMoveDir, Server, Server_256

try {
	runwait, java.exe,,hide
}
catch {
	Msgbox, 0x24,, It looks like Java is not installed. Download now?
	IfMsgbox Yes
	{
		If A_Is64bitOS {
			run,https://javadl.oracle.com/webapps/download/AutoDL?BundleId=242990_a4634525489241b9a9e1aa73d9e118e6
		}
		Else {
			run,https://javadl.oracle.com/webapps/download/AutoDL?BundleId=242988_a4634525489241b9a9e1aa73d9e118e6
		}
		Msgbox Once you have installed Java`, please press OK
	}
}
Progress,,Downloading...,Updating QuickServer, QuickServer-setup
Progress, 0
Progress, 10

URLDownloadToFile,https://github.com/mkzeender/QuickServerMC/archive/master.zip, QuickServerMC-master.zip
Progress, 30
runwait, tar.exe -x -f QuickServerMC-master.zip,,hide
Progress,45
FileMove, QuickServerMC-master\*.*, %DefaultDir%\*.*, true
If not FileExist("QuickServer.ahk") {
	Progress, hide
	FileDelete, build.txt
	msgbox,0x10,, Install Failed. Connect to the internet and try again.
	ExitApp
}

Progress,55



If not FileExist("ngrok.exe") {
	If A_Is64bitOS {
		URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-amd64.zip, ngrok.zip
	}
	Else {
		URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-386.zip, ngrok.zip
	}
	Progress, 80
	try runwait, tar.exe -x -f ngrok.zip,,hide
}
Progress, 90
If not FileExist("quickserveruhc.zip") {
	URLDownloadToFile, https://github.com/mkzeender/QuickServerMC/raw/master/quickserveruhc.zip,quickserveruhc.zip
}
Progress, 95

If not FileExist("QuickServer.ahk") {
	Progress, hide
	FileDelete, build.txt
	msgbox,0x10,, Install Failed. Connect to the internet and try again.
	ExitApp
}

FileCreateShortcut, %DefaultDir%\QuickServer.exe, %A_Programs%\QuickServer.lnk, %A_WorkingDir%,,Create and manage Minecraft Spigot Servers,%A_WorkingDir%\QuickServer.ico

FileRemoveDir, QuickServerMC-master, 1
FileDelete, QuickServerMC-master.zip

Progress,100

If not (A_Args[1] = "--NoStart")
	try Run, QuickServer.exe