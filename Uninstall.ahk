;#NoTrayIcon
DefaultDir := A_ScriptDir
Win := new Gui(,"Uninstall QuickServer")
Win.add("Text",, "Are you sure you want to uninstall QuickServer?`n")
FullDelete := Win.add("CheckBox",,"Also delete worlds and settings")
btn := Win.add("Button","section"," Uninstall ")
Win.add("Button","ys","  Cancel   ").OnEvent("Cancelbtn")
Win.OnEvent("Cancelbtn","Close")
Win.Show("autosize center")

ret:
btn.Wait("Normal")

Cancelbtn(Event) {
	ExitApp
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

	Run, cleanup.bat, %DefaultDir%, hide
}
Win.Destroy()



FileRemoveDir, %DefaultDir%\BuildTools, 1
FileDelete, %DefaultDir%\ngrok.zip
FileDelete, %DefaultDir%\ngrok.exe
try FileDelete, %DefaultDir%\QuickServer.ahk
FileDelete, %A_Programs%\QuickServer.lnk
RegDelete, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QuickServer
ExitApp



#Include %A_ScriptDir%\GuiObject.ahk