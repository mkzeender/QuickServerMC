#NoTrayIcon
DefaultDir := A_ScriptDir
GroupAdd, QS, ahk_exe QuickServer.exe
WinClose, ahk_group QS

Win := new Gui(,"Uninstall QuickServer")
Win.add("Text",, "Are you sure you want to uninstall QuickServer?`n")
FullDelete := Win.add("CheckBox",,"Also delete worlds and settings")
btn := Win.add("Button","section","   Uninstall   ")
cncl := Win.add("Button","ys","   Cancel   ")
cncl.OnEvent("Cancelbtn")
Win.OnEvent("Cancelbtn","Close")
Win.Show("autosize center")

ret:
AllowCancel := true
btn.Wait("Normal")
AllowCancel := false

Cancelbtn(Event) {
	Global AllowCancel
	If AllowCancel
		ExitApp
	else
		Event.NoClose := true
}

If FullDelete.Contents
{
	MsgBox, 308, Uninstall QuickServer, WARNING: Do you want to permanently delete your worlds?`nThis cannot be undone!
	IfMsgBox, No
	{
		goto ret
	}
	FileAppend,
(
cd ..
TimeOut -t 10
rd /s /q .QuickServer
), cleanup.bat

	
}
Else
{
	FileAppend,
(
TimeOut -t 10
del QuickServer.exe
del cleanup.bat
), cleanup.bat
}

FullDelete.Enabled := false
btn.Text := "Uninstalling"
btn.Enabled := false
cncl.Enabled := false




FileRemoveDir, %DefaultDir%\BuildTools, 1
FileDelete, %DefaultDir%\ngrok.zip
FileDelete, %DefaultDir%\ngrok.exe
try FileDelete, %DefaultDir%\QuickServer.ahk
FileDelete, %A_Programs%\QuickServer.lnk
RegDelete, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QuickServer
Run, cleanup.bat, %DefaultDir%, hide
ExitApp



#Include %A_ScriptDir%\GuiObject.ahk