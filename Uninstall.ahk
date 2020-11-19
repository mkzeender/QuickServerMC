;#NoTrayIcon
DefaultDir := A_ScriptDir

MsgBox, 260, Uninstall QuickServer, Are you sure you want to uninstall QuickServer?
IfMsgBox, No
{
	ExitApp
}
MsgBox, 308, Uninstall QuickServer, WARNING: Do you want to permanently delete your worlds?`nThis cannot be undone!
IfMsgBox, Yes
{
	FileAppend,
( %
cd ..
TimeOut -t 10
rd /s /q .QuickServer
), cleanup.bat

	Run, cleanup.bat, %DefaultDir%, hide
}
IfMsgBox, No
{
	FileRemoveDir, %DefaultDir%\BuildTools, 1
	FileDelete, %DefaultDir%\ngrok.zip
	FileDelete, %DefaultDir%\ngrok.exe
	try FileDelete, %DefaultDir%\QuickServer.ahk
}
FileDelete, %A_Programs%\QuickServer.lnk
RegDelete, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QuickServer