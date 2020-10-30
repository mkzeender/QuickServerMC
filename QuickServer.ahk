;-------- Quick Modifications --------------

global DefaultDir := A_AppData "\.QuickServer"
global Enable_CheckForUpdates := true
global defaultRAM := 2
global debug := false

{ ;--------------------------------  AUTORUN ----------------------------------

SetBatchLines, -1
#NoTrayIcon
If debug {
	Menu, tray, icon
}
#persistent
#singleinstance, Off
OnError("ErrorFunc")

FontInf := GetFontDefault()
global FontSmall := FontInf.Small
global FontNormal := FontInf.Normal
global FontLarge := FontInf.Large
CheckSingleInstance()
CheckPortableMode()
FileCreateDir, %DefaultDir%
SetWorkingDir, %DefaultDir%

global ServerList
global ngrok := new NgrokHandler

If FileExist("QuickServer.ico") {
	menu, tray, icon, QuickServer.ico
}

If Enable_CheckForUpdates {
	CheckForUpdates()
}


OnExit("ExitFunc")

BuildServerWindow()
SetBatchLines, 20ms
ngrok.run()
ConnectionsWindow.Refresh()

return




CheckForUpdates() {
	CurrentBuild := IniRead("QuickServer.ini", "version", "build", 0)
	FileDelete, build.txt
	URLDownloadToFile,https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/build.txt, build.txt
	FileRead, LatestBuild, build.txt
	LatestBuild := StrReplace(StrReplace(LatestBuild,"`n"),"`r")
	If (LatestBuild > CurrentBuild) {
		try FileDelete, QuickServer-setup.ahk
		URLDownloadToFile,https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/QuickServer-setup.ahk, QuickServer-setup.ahk
		If not FileExist("QuickServer-setup.ahk") {
			fail := true
		}
		try run, QuickServer.exe QuickServer-setup.ahk
		catch
		{
			try FileCopy, %A_ScriptDir%\QuickServer.exe, QuickServer.exe
			try run, QuickServer.exe QuickServer-setup.ahk
			catch
			{
				fail := true
			}
		}
		IniWrite, %LatestBuild%, QuickServer.ini, version, build
		If not fail {
			ExitApp
		}
	}
}

CheckPortableMode() {
	UsePortable := IniRead(A_ScriptDir . "\QuickServer.ini", "QuickServer", "EnablePortableMode", 0)
	If not FileExist(DefaultDir . "\QuickServer.ini") and not UsePortable ;----prompt for installation
	{
		msgbox, 0x23, Install QuickServer, Would you like to install QuickServer on this computer? Press Yes to install. Press No to use QuickServer Portable (i.e. if you want to run it on a flash drive).
		IfMsgBox Cancel
			ExitApp
		IfMsgBox No
		{
			DefaultDir := A_ScriptDir
			Enable_CheckForUpdates := false
			IniWrite(true, A_ScriptDir . "\QuickServer.ini", "QuickServer", "EnablePortableMode")
		}
	}
	Else If UsePortable
	{
		DefaultDir := A_ScriptDir
		Enable_CheckForUpdates := false
	}
}

CheckSingleInstance() {
	If WinExist("ahk_exe QuickServer.exe") {
		WinActivate
		ExitApp
	}
	Else If not A_IsCompiled and WinExist("QuickServer.ahk ahk_exe Autohotkey.exe")
	{
		WinActivate
		ExitApp
	}
}

ExitFunc() {
	ngrok.stop()
}

ErrorFunc(exception) {
	FormatTime, t,, MM/dd/yyyy hh:mm:ss tt
	ErrorMsg := "[" . t . "]`nError: " . exception.Message
	msgbox,0x10,, %ErrorMsg%
	FileAppend, %ErrorMsg%`n`n`n, QuickServer.log
	return not debug
}

}

{ ;----------------------------------Main GUI (SelectServer) Window-------------------------------- 



ChooseServerWindow() {
	global MainGui_ServerListView
	ListCtrl := MainGui_ServerListView
	ListCtrl.LV_Delete()
	
	ServerList := GetServerList()
	
	Loop, % ServerList.Length()
	{
		DateFormat := GetDate(ServerList[A_Index])
		
		ListCtrl.LV_Add("",IniRead(ServerList[A_Index] . "\QuickServer.ini", "QuickServer", "name", "Untitled server"),GetDate(ServerList[A_Index],false),ServerList[A_Index],GetDate(ServerList[A_Index],true))
	}
	
	Listctrl.LV_Modify(1, "Focus")
}

BuildServerWindow() {
	ServerLV_Menu.Build()
	
	global MainGui
	MainGui := new Gui(, "QuickServer")
	MainGui.Font("s" . FontNormal)
	LV_width := FontNormal * 50
	Listctrl := MainGui.add("ListView", "R15 w" . LV_width . " -Multi", "World|DateFormat|uniquename|Date Modified")

	Listctrl.LV_ModifyCol(1, FontNormal * 30)
	Listctrl.LV_ModifyCol(1, "Sort")
	Listctrl.LV_ModifyCol(2, 0)
	Listctrl.LV_ModifyCol(3, 0)
	Listctrl.LV_ModifyCol(4, "AutoHDR NoSort")
	Listctrl.OnEvent("SelectServer_ListView", "Normal")
	global MainGui_ServerListView
	MainGui_ServerListView := Listctrl
	;ServerLV_Menu.Build()
	;ListCtrl.OnEvent(ServerLV_Menu.Show.Bind(ServerLV_Menu), "ContextMenu")
	
	MainGui.add("text","ym")   
	MainGui.Font("s" . FontLarge)
	Maingui.add("Button", , "New World").OnEvent("Button_Main_NewServer")
	Maingui.add("Button",,"Play Selected World").OnEvent("SelectServer_Run")
	Maingui.add("Button",, "World Settings").OnEvent("SelectServer_Settings")
	Maingui.add("Button", , "Import World").OnEvent("SelectServer_Import")
	Maingui.add("Link",, "<a>Restore a backup</a>").OnEvent("SelectServer_Restore")
	Maingui.add("Link", , "<a>Help! Every time I try to`ncreate a new server it fails</a>").OnEvent("ReInstall")
	
	Maingui.Font("s" . FontNormal)
	ConnectionsWindow.Include(MainGui)

	MainGui.OnEvent(Func("MainGUIGUIClose"),"Close")
	MainGui.show("Autosize Center")
	ChooseServerWindow()
}


Class ServerLV_Menu {
	Build() {
		funcobj := ServerLV_Menu.ChooseItem.Bind(this)
		Menu, ServerLV_Menu, Add,Run,%funcobj%
		Menu, ServerLV_Menu, Default, Run
		Menu, ServerLV_Menu, Add,Settings,%funcobj%
	}
	Show(Event) {
		this.uniquename := GetChosenUniquename()
		Menu, ServerLV_Menu, Show
	}
	
	ChooseItem(ItemName,ItemPos,MenuName) {
		(ItemName = "Run") ? SelectServer_Run() : ""
		(ItemName = "Settings") ? SelectServer_Settings()
	}
}
{ ;Main window buttons

SelectServer_ListView(Event) {
	critical
	If (Event.GuiEvent = "ColClick") and (Event.EventInfo = 4) {
		;sort by date modified
		static inverse
		inverse := not inverse
		options := inverse ? "desc" : ""
		Event.Control.LV_ModifyCol(2, "Sort" . options)
	}
	Else If (Event.GuiEvent = "DoubleClick") {
		critical,off
		SelectServer_Run(Event)
		;run server
	}
}

Button_Main_NewServer() {

	CreatedServer := new Server("Server")
	If not CreatedServer.create()
	{
		return
	}
	ChooseServerWindow()
	CreatedServer.settings()
}

SelectServer_Run(Event := "") {
	uniquename := GetChosenUniquename()
	if not FileExist(uniquename . "\server.properties") {
		msb("Select a server")
		return
	}
	SelectedServer := new Server(uniquename)
	If not SelectedServer.uniquename
		return false
	SelectedServer.Start()
}

SelectServer_Settings() {
	uniquename := GetChosenUniquename()
	if not FileExist(uniquename . "\server.properties") {
		msb("Select a server")
		return
	}
	SelectedServer := new Server(GetChosenUniquename())
	If not SelectedServer.uniquename
		return false
	SelectedServer.Settings()
	return true
}

SelectServer_Import() {
	ImportGui := new Gui("-sysmenu","Import Server")
	ImportGui.font("s" . FontLarge)
	ImportGui.add("Button", , "Import Singleplayer World").OnEvent("ImportSinglePlayer")
	ImportGui.add("Button", "ym", "Import a Pre-existing Server").OnEvent("ImportExternalServer")
	ImportGui.add("Button", "ym", "Cancel")
	ImportGui.show("autosize center", "Import Server").OnEvent("ImportExternalServer")
	ImportGui.Wait()
	ImportGui.Destroy()
}

ImportSinglePlayer() {
	FileSelectFolder, Worldfolder, %A_AppData%\.minecraft\saves,,Import World Folder
	If ErrorLevel
		return
	If not FileExist(Worldfolder . "\Level.dat")
		throw Exception("Invalid World Folder",-1)
		
	CreatedServer := new Server("Server")
	If not CreatedServer.Create("Imported Server")
		return
	
	uniquename := CreatedServer.uniquename
	FileCreateDir, %uniquename%\world
	If CopyFilesAndFolders(Worldfolder . "\*.*",uniquename . "\world")
		msgbox, 0x10,Import World,Some world data could not be imported
		
		
	ChooseServerWindow()
	CreatedServer.Settings()
	return
}

ImportExternalServer() {
	FileSelectFolder, Worldfolder,,,Import Server Folder (folder should contain a server.properties file)
	If ErrorLevel
		return
	If not FileExist(Worldfolder . "\server.properties")
		throw Exception("Invalid World Folder",-1)
		
	CreatedServer := new Server("Server")
	If not CreatedServer.Create("Imported Server")
		return
	
	uniquename := CreatedServer.uniquename
	If CopyFilesAndFolders(Worldfolder . "\*.*",uniquename)
		msgbox, 0x10,Import World,Some world data could not be imported
		
		
	ChooseServerWindow()
	CreatedServer.Settings()
}

SelectServer_Restore() {
	FileSelectFile, SelectedFile, 1,,Restore Server Backup, QuickServer Backups (*.zip)
	If Errorlevel
		return
	SplashTextOn,,,Importing...
	FileCreateDir, %A_Temp%\.QuickServer\import
	runwait, tar.exe -x -f %SelectedFile%,%A_Temp%\.QuickServer\import,hide
	NewUniquename := UniqueFolderCreate("Server")
	OriginFolder := "null"
	Loop, Files, %A_Temp%\.QuickServer\import\Server_*, D
	{
		OriginFolder := A_LoopFileName
	}
	If not FileExist(A_Temp . "\.QuickServer\import\" . OriginFolder . "\server.properties") {
		SplashTextOff
		throw Exception("Could not open " . SelectedFile)
	}
	CopyFilesAndFolders(A_Temp . "\.QuickServer\import\" . OriginFolder . "\*.*", NewUniquename, true)
	FileRemoveDir, %A_Temp%\.QuickServer\import, true
	SplashTextOff
	ImportedServer := new Server(NewUniquename)
	ImportedServer.name := ImportedServer.name . "--backup"
	ImportedServer.Rename()
	ChooseServerWindow()
}

ReInstall() {
	InputBox, v, Reset and Reinstall QuickServer, This will reset the installation of Minecraft Server. It will NOT delete your servers`, but after resetting`, you will need to update/upgrade each of your servers before running them (go to: server settings>update/upgrade server). Type "confirm" below to confirm
	If not ErrorLevel and (v = "confirm")
	{
		SplashTextOn,,,Resetting...
		FileRemoveDir, BuildTools, true
		SplashTextOff
	}
}


MainGUIGUIClose(Event := "") {
	ExitApp
}

}

ExtractServerNames() {
	For index, uniquename in ServerList
	{
		NamesList := NamesList . "|" . IniRead(uniquename . "\QuickServer.ini", "QuickServer", "name", "Untitled server")
	}
	return StrReplace(NamesList,"|",,,1)
}

GetChosenUniquename() {
	global MainGui_ServerListView
	MainGui_ServerListView.LV_GetText(v, MainGui_ServerListView.LV_GetNext(,"Focused"),3)
	return v
}

GetServerList() {
	l_List := []
	Loop, Files, Server_*, D
	{
		If FileExist(A_LoopFileName . "\server.properties")
			l_List.Push(A_LoopFileName)
	}
	return l_List
}

}

Class NgrokHandler { ; --------------Ngrok-----------------------------------
	Run() {
		DetectHiddenWindows, on		
		If (this.enable = true) and not WinExist("ahk_exe ngrok.exe") {
			Run,ngrok tcp 25565,, % debug ? A_Space : "hide", ngrok_pid
			this.pid := ngrok_pid
		}
		Else if not this.enable {
			this.Stop()
		}
	}
	Stop() {
		detecthiddenwindows,on
		WinClose, ahk_exe ngrok.exe
	}
	Setup() {
		ngrokgui := new Gui("+alwaysOnTop", "Ngrok Setup")
		ngrokgui.Font("s" . FontNormal)
		ngrokgui.Add("Link",,"Ngrok is a free service to open your server to the public. Set up an ngrok account <a href=""https://ngrok.com/"">here</a>.`n`nAfter creating your ngrok account, enter your account AuthToken below.")
		this.authtokenctrl := ngrokgui.Add("Edit", "w150")
		this.enablectrl := ngrokgui.add("checkbox", "Checked" . this.Enable, "Use ngrok to connect to your server")
		ngrokgui.add("button","default", "   OK   ").OnEvent(this.onButtonOK.Bind(this))
		ngrokgui.OnEvent(this.onclose.bind(this), "Close")
		
		ngrokgui.Show("Autosize Center")
	}
	OnClose(event)
	{
		Event.Gui.Destroy()
	}
	OnButtonOK(Event) {
		ngrok_authtoken := this.authtokenctrl.Contents
		this.Enable := ngrok_enable := this.enablectrl.Contents
		If ngrok_authtoken
			runwait, ngrok authtoken %ngrok_authtoken%,,hide
		
		void := ngrok_enable ? this.run() : this.stop()
		If ngrok_enable and not FileExist("ngrok.exe")
			Throw Exception("Ngrok installation failed. Connect to the internet and restart QuickServer to try again")
		
		Event.Gui.Destroy()
	}
	
	Enable[] {
		get {
			return IniRead("QuickServer.ini", "ngrok", "ngrok_enable", -1)
		}
		set {
			IniWrite, %value%, QuickServer.ini, ngrok, ngrok_enable
			return value
		}
	}
	
	Pid := ""
}

{ ;----------------------------------Connections Window

class ConnectionsWindow {
	
	Include(Guiobj) {
		FileCreateDir, %A_Temp%\QuickServer
		Guiobj.Add("Text","xm","Click a connection below for more info and setup`nUse Ngrok if you don't know where to start.")
		width := FontNormal * 70
		this.ListCtrl := Guiobj.Add("ListView", "w" . width . " AltSubmit Count4 Grid R5 noSortHdr", "Name|Address|Status|Connectivity")
		
		this.ListCtrl.LV_Add("","Local Computer", "LOCALHOST", "Connected", "This computer only")
		this.ListCtrl.LV_Add("","LAN","","","This WiFi network only")
		this.ListCtrl.LV_Add("","Public IP Address   ","","","Public")
		this.ListCtrl.ngroklink := this.ngrok_CheckConnection()
		this.ListCtrl.LV_Add("","Ngrok","","", "Public")
		this.ListCtrl.LV_ModifyCol(1,"AutoHdr")
		this.ListCtrl.LV_ModifyCol(2,FontNormal * 20)
		this.ListCtrl.LV_ModifyCol(3,FontNormal * 15)
		this.ListCtrl.LV_ModifyCol(4,"AutoHdr")
		this.ListCtrl.OnEvent("ConnectionsWindowPress")
		
		this.refreshCtrl := Guiobj.Add("Button","Disabled","Refreshing...")
		this.refreshCtrl.OnEvent(ConnectionsWindow.Refresh.Bind(this))
	}
	
	Refresh() {
		this.refreshCtrl.Enabled := false
		this.refreshCtrl.Text := "Refreshing..."
		
		LANIP := (A_IPAddress1 = 0.0.0.0) ? "" : A_IPAddress1
		PublicIP := this.PublicIP_CheckConnection()
		If ngrok.Enable {
			ngroklink := this.ngrok_CheckConnection()
			ngrok_con := ngroklink ? "Connected" : "Not Connected"
		} else {
			ngroklink := ""
			ngrok_con := "Disabled"
		}
		
		this.ListCtrl.LV_Modify(2,"Col2",LANIP, this.LAN_CheckConnection() ? "Connected" : (LANIP ? "Probably not connected" : "Not connected"))
		this.ListCtrl.LV_Modify(3,"Col2",PublicIP,PublicIP ? "Unknown" : "Not connected")
		this.ListCtrl.LV_Modify(4,"Col2",ngroklink,ngrok_con)
		
		this.refreshCtrl.Text := "Refresh"
		this.refreshCtrl.Enabled := true
		
	}
	
	LAN_CheckConnection() {
		If (A_IPAddress1 = 0.0.0.0)
			return ""
			
		runwait,cmd.exe /c powershell Get-NetConnectionProfile > "%A_Temp%\QuickServer\LAN_CheckConnection.txt",,hide
		try FileRead, landata, %A_Temp%\QuickServer\LAN_CheckConnection.txt
		If not landata
			return ""
			
		Loop, Parse, landata, `n,`r%A_Space%%A_Tab%
		{
			sep := InStr(A_LoopField, ":")
			If (Trim(SubStr(A_LoopField,1,sep-1),"`r`n" . A_Space . A_Tab) = "NetworkCategory") {
				return (Trim(SubStr(A_LoopField,sep+1),"`r`n" . A_Space . A_Tab) = "private") ? A_IPAddress1 : "" ;returns empty string if false
			}
		}
	}
	
	PublicIP_CheckConnection() {
		FileDelete, %A_Temp%\QuickServer\PublicIP.tmp
		URLDownloadToFile, http://www.whatismyip.org/, %A_Temp%\QuickServer\PublicIP.tmp
		If not FileExist(A_Temp . "\QuickServer\PublicIP.tmp")
			return
		try FileRead, PublicIP, %A_Temp%\QuickServer\PublicIP.tmp
		PublicIP := SubStr(PublicIP,InStr(PublicIP, "<a href=""/my-ip-address"">"))
		PublicIP := SubStr(SubStr(PublicIP, 26, InStr(PublicIP,"</a>") - 26),1,25)
		return PublicIP
	}
	
	ngrok_CheckConnection() {
		FileDelete, %A_Temp%\QuickServer\ngrok_CheckConnection.json
		URLDownloadToFile, http://localhost:4040/api/tunnels/, %A_Temp%\QuickServer\ngrok_CheckConnection.json
		try FileRead, jsondata, %A_Temp%\QuickServer\ngrok_CheckConnection.json
		If not jsondata
			return
		Loop, Parse, jsondata, `,[, {}
		{
			sep := InStr(A_LoopField, ":")
			If (SubStr(A_LoopField,1,sep-1) = """Public_URL""") {
				address := Trim(SubStr(A_LoopField,sep+1), """")
				return StrReplace(address, "tcp://")
			}
		}
	}
}


ConnectionsWindowPress(Event) {
	critical
	
	If not (Event.EventType = "Normal")
		return
	
	If (Event.GuiEvent = "Normal")
	{
		critical off
		If (Event.EventInfo = 1) {
			msgbox,0x40000,Local Computer,If you are playing Minecraft on this computer, you can connect to the server by using LOCALHOST as the server address.
		}
		If (Event.EventInfo = 2) {
			msgbox,0x40000,LAN,Anyone else playing on your LAN (a.k.a. your WiFi network) can connect to this address. However, you might need to mark the network as "private" (on your computer go to Settings > Network and Internet > Change Connection Properties)
		}
		If (Event.EventInfo = 3) {
			publicIp := new Gui("AlwaysOnTop","Public IP Address")
			publicIp.font("s" . FontNormal)
			publicIp.add("Link",,"<a href=""https://www.wikihow.com/Set-Up-Port-Forwarding-on-a-Router"">Setup Port Forwarding</a> to use a permanent IP address for your server (note: Minecraft uses the port 25565)`n`nOnce you have set up port forwarding`, you can optionally connect it to a permanent`ncustom address (i.e. <a>MyServerIsCool.com</a>)")
			clsbtn := publicIp.add("Button", "default", "Ok")
			publicIp.Show("autosize center")
			publicIp.Wait()
			publicIp.Destroy()
		}
		If (Event.EventInfo = 4) {
			ngrok.setup()
		}
	}
}

ConnectionsGuiClose() {
	MsgBox, 0x40134,Close Connections,Are you sure you sure you want to quit? Your server may lose connection.
	IfMsgBox Yes
	{
		ConnectionsWindow.IsOpen := false
		ConnectionsWindow.Close()
	}
	return true
}
PublicIPGuiClose() {
	gui, destroy
}
}

class Server { ;---------------------Class Server-----------------------------------------------
	
	name[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "name", "Untitled Server")
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, name
		}
	}
	version[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "version", "latest") 
		}
		set {
			version := (StrLen(value) < 10) ? value : "ERROR"
			IniWrite, % version, % this.uniquename . "\QuickServer.ini", QuickServer, version
		}
	}
	DateModified[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "DateModified", A_Now)
		}
		set {
			IniWrite(value, this.uniquename . "\QuickServer.ini", "QuickServer", "DateModified")
		}
	}
	RAM[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "RAM")
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, RAM
		}
	}
	JarFile[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "JarFile") 
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, JarFile
		}
	}
	UseLatest[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "UseLatest") 
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, UseLatest
		}
	}
	Difficulty[] {
		get {
			If this.UHC
			{
				return "UHC"
			}
			If Bool(this.props["hardcore"])
			{
				return "Hardcore"
			}
			return this.props["difficulty"]
				
		}
		set {
			If (value = "UHC")
			{
				this.UHC := true
				this.props["hardcore"] := "true"
				return
			}
			If (value = "Hardcore")
			{
				this.UHC := false
				this.props["hardcore"] := "true"
				return
			}
			this.UHC := false
			this.props["difficulty"] := value
			this.props["hardcore"] := "false"
		}
	}
	UHC[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "UHC", false)
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, UHC
			If value
			{
				FileCreateDir, % this.uniquename . "\world\datapacks\"
				FileCopy, quickserveruhc.zip, % this.uniquename . "\world\datapacks\quickserveruhc.zip"
			}
			Else
			{
				FileDelete, % this.uniquename . "\world\datapacks\quickserveruhc.zip"
			}
		}
	}
	EULAAgree[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "EULAAgree", false) ? true : eulaAgree(this.uniquename)
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, EULAAgree
		}
	}
	props := {}
	
	__New(uniquename := "") {
		this.uniquename := uniquename
	}
	
		
	create(name := "New Server") {
		this.version := "latest"
		this.uniquename := UniqueFolderCreate("Server")
		if not this.uniquename
			throw Exception("Missing server", -1)
		this.name := name
		if not this.Rename()
			return false
		success := this.EULAAgree
		this.UpdateThisServer()
		this.props := new properties(this.uniquename . "\server.properties")
		this.LoadProps()
		this.props["motd"] := this.name
		this.FlushProps()
		this.RAM := defaultRAM
		this.DateModified := A_Now
		return true
	}
	
	start(Event := "") {
		If (Event.EventType = "Normal")
		{
			this.Save(Event)
		}
		if not this.EULAAgree
			return false
		RAM := this.RAM
		JarFile := this.JarFile
		If not FileExist(JarFile) or not InStr(JarFile, ".jar") {
			MsgBox, 0x14, % this.name, Could not find server installation. Install now?
			IfMsgBox No
				return
			this.UpdateThisServer()
			return
		}
		uniquename := this.uniquename
		cmd = java -Xmx%RAM%G -Xms%RAM%G -jar "%JarFile%" nogui 2> errorlog.log
		try FileDelete, % this.uniquename . "\errorlog.log"
		ServerPID := RunTer(cmd, this.name, uniquename)
		this.DateModified := A_Now
		
		sleep, 2000
		FileRead,errorlog, % this.uniquename . "\errorlog.log"
		if InStr(errorlog,"Outdated") {
			MsgBox, 52, Outdated Server, This server needs to be updated. Would you like to update it now?`nThe server will start in 20 seconds., 16
			IfMsgBox, Yes
			{
				this.UpdateThisServer()
				return false
			}
			IfMsgBox, Cancel
			{
				return false
			}
		}
		sleep, 5000
		ConnectionsWindow.Open()
		Process, WaitClose, %ServerPID%
		ConnectionsWindow.Close()
	}
	
	Ctrls := {}
	Ctrlprop := {}
	
	Settings() {
		this.LoadProps()
		
		settingsgui := new Gui(,"Server Properties")
		settingsgui.OnEvent(Server.Save.Bind(this),"Close")
		settingsgui.font("s" . FontLarge)
		settingsgui.add("Text",,this.name)
		settingsgui.font("s" . FontNormal)
		
		settingsgui.Add("Tab3","Choose2", "File|Edit|Plugins and Datapacks").OnEvent(Server.TabChange.Bind(this))
		settingsgui.Tab(1)
		settingsgui.add("Button", "section w" . FontNormal * 15, "Start Server!").OnEvent(Server.Start.Bind(this))
		settingsgui.add("Button","ys w" . FontNormal * 15, "Rename").OnEvent(Server.Rename.Bind(this))
		settingsgui.add("text","xs", "Current version: " . this.version . "`nPress the button below to either update the current version to the latest build`n(i.e. if the server says it is out of date) or upgrade the server to a newer`nversion of Minecraft.")
		settingsgui.add("Button","xs w" . FontNormal * 15, "Update/Upgrade").OnEvent(Server.UpdateThisServer.Bind(this))
		settingsgui.add("Button","xs section w" . FontNormal * 15, "Backup").OnEvent(Server.Backup.Bind(this))
		settingsgui.add("Button","ys w" . FontNormal * 15, "Duplicate").OnEvent(Server.Duplicate.Bind(this))
		settingsgui.add("Button","ys w" . FontNormal * 15, "Delete server").OnEvent(Server.Delete.Bind(this))
		
		
		settingsgui.tab(3)
		settingsgui.add("text",, "Easily import Spigot Plugins and datapacks!")
		settingsgui.Add("Link",,"You can find plugins at <a href=""https://www.spigotmc.org/resources/categories/spigot.4/?order=download_count""> www.spigotmc.org </a>`nOnce you have downloaded a plugin, click Import Plugins.`nIt is recommended that you backup your server before using plugins.")
		settingsgui.add("Button",, "Backup").OnEvent(Server.Backup.Bind(this))
		
		new PluginsGUI(settingsgui, "Plugins", this.uniquename)
		new PluginsGUI(settingsgui, "Datapacks", this.uniquename)
		
		
		
		settingsgui.tab(2)
		settingsgui.add("link",, "Server Description (a.k.a MOTD`; as seen on Multiplayer menu).`nGo to <a href=""https://minecraft.tools/en/motd.php"">https://minecraft.tools/en/motd.php</a> to generate nice-looking MOTD")
		this.ctrls["motd"] := settingsgui.add("Edit","w" . FontNormal * 70,this.props["motd"])
		
		this.ctrls["gamemode"] := settingsgui.add("DropDownList","section", "Survival|Creative|Adventure")
		settingsgui.add("text","ys", "Gamemode")
		this.ctrls["gamemode"].ChooseString(this.props["gamemode"])
		
		
		this.ctrlprop["difficulty"] := settingsgui.add("DropDownList", "xs section", "Peaceful|Easy|Normal|Hard|Hardcore|UHC")
		settingsgui.add("text"," ys", "Difficulty")
		this.ctrlprop["difficulty"].ChooseString(this.difficulty)
				
		this.ctrls["pvp"] := settingsgui.add("CheckBox","xs Checked" . Bool(this.props["pvp"]), "Allow PVP (player vs player)")
		this.ctrls["pvp"].IsBool := true
		
		
		this.ctrls["level-seed"] := settingsgui.add("Edit","xs section",this.props["level-seed"])
		settingsgui.add("text","ys", "Custom World Seed")
		
		settingsgui.add("Edit","xs section")
		this.ctrls["max-players"] := settingsgui.add("UpDown",, this.props["max-players"])
		settingsgui.add("text"," ys", "Maximum players")
		
		
		settingsgui.add("Edit","xs section")
		this.ctrls["spawn-protection"] := settingsgui.add("UpDown", , this.props["spawn-protection"])
		settingsgui.add("text","ys", "Spawn Grief-Protection Radius")
		
		this.ctrls["spawn-monsters"] := settingsgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-monsters"])
			, "Automatically Spawn Monsters")
		this.ctrls["spawn-monsters"].IsBool := true
		 
		this.ctrls["spawn-npcs"] := settingsgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-npcs"])
			, "Automatically Spawn NPCs (Villagers)")
		this.ctrls["spawn-npcs"].IsBool := true
		
		this.ctrls["spawn-animals"] := settingsgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-animals"])
			, "Automatically Spawn Animals")
		this.ctrls["spawn-animals"].IsBool := true
		
		this.ctrls["enable-command-block"] := settingsgui.add("CheckBox", "xs Checked" . Bool(this.props["enable-command-block"])
			, "Allow Command Blocks")
		this.ctrls["enable-command-block"].IsBool := true
		
		
		settingsgui.add("Edit","xs section")
		this.ctrlprop["RAM"] := settingsgui.add("UpDown", ,this.RAM)
		settingsgui.add("text","ys", "Maximum Server Memory (in Gigabytes)")
		
		settingsgui.add("Link", "xs section", "<a>Advanced Settings</a>`n").OnEvent(Server.s_Advanced.Bind(this))
		settingsgui.add("Link", "ys", "<a> Open the Server Folder </a>").OnEvent(Server.s_OpenFolder.Bind(this))
		
		settingsgui.add("Button", "xs default", "Revert Settings").OnEvent(Server.ReloadSettings.Bind(this))
		
		
		settingsgui.show("Autosize Center")
		this.SettingsWin := settingsgui
	}
	FlushProps() {
		FilePath := this.uniquename . "\server.properties"
		For key, ctrl in this.ctrls
		{
			this.props[key] := ctrl.IsBool ? String(ctrl.Contents) : ctrl.Contents
		}
		For key, ctrl in this.ctrlprop
		{
			this[key] := ctrl.Contents
		}
		For key, value in this.props
		{
			filewrite := filewrite . "`n" . key . "=" . value
		}
		try FileDelete, % FilePath
		FileAppend, % filewrite, % FilePath
	}
	LoadProps() {
		FilePath := this.uniquename . "\server.properties"
		If not FileExist(FilePath)
			DefaultPropertiesFile(FilePath)
		FileRead, completefile, % FilePath
		For index, val in StrSplit(completefile, "`n", "`r`t")
		{
			if not (val = "") and not (InStr(val, "#") = 1) ; not empty line and not comment line
			{
				v := StrSplit(val,"=",,2)
				this.props[v[1]] := v[2]
			}
		}
		
	}
	Save(Event := "") {
		this.FlushProps()
		this.DateModified := A_Now
		this.SettingsWin.Destroy()
	}
	
	ReloadSettings() {
		this.SettingsWin.Destroy()
		this.Settings()
	}
	
	UpdateThisServer(Event := "") {
		InputBox, newversion, Update or Select Version, Enter the desired version(example: 1.16.1).`n`nType "latest" to use the latest version.,,,,,,,, % this.version
		If not Errorlevel {
			UpdateResult := UpdateServer(newversion)
			if not UpdateResult.confirmed
				DownloadFailed(this)
			this.Version := UpdateResult.version
			this.JarFile := UpdateResult.uniquename
			this.UseLatest := UpdateResult.IsLatest
		}
		If (Event.EventType = "Normal") {
			this.Save()
			this.Settings()
		}
	}
	Backup() {
		backup_folder := this.uniquename
		FileSelectFile, v, S16, %backup_folder%.zip, Save Backup, Zip Archives (*.zip)
		If not Errorlevel
		{
			Run, tar -a -c -f %v% %backup_folder%,,hide
		}
	}
	
	Rename(Event := "") {
		
		InputBox, NewName, QuickServer, Enter a new name for your server.,,,,,,,, % this.name
		If Errorlevel
			return false
		this.name := SubStr(NewName,1,50)
		ChooseServerWindow()
		If (Event.EventType = "Normal")
		{
			this.SettingsWin.Destroy()
			this.Settings()
		}
		return true
	}
	
	Duplicate() {
		CreatedServer := new Server
		CreatedServer.uniquename := UniqueFolderCreate("Server")
		SplashTextOn,,,Copying Server...
		CopyFilesAndFolders(this.uniquename . "\*.*", CreatedServer.uniquename, true)
		SplashTextOff
		CreatedServer.name := this.name . " (Copy)"
		CreatedServer.Rename()
		CreatedServer.DateModified := A_Now
		ChooseServerWindow()
	}
	Delete() {
		
		msgbox,0x134,Warning, % "WARNING: Are you 100% sure you want to delete " this.name . "? You may be able to recover the world folder from the recycle bin."
		Ifmsgbox, Yes
		{
			FileRecycle, % this.uniquename
			ChooseServerWindow()
			this.SettingsWin.Destroy()
		}
	}
	
	AskSave(Event) {
		MsgBox, 262195, Server Settings, Would you like to save changes first?
		IfMsgBox, Yes
		{
			this.Save()
			Event.Gui.Destroy()
			return false
		}
		IfMsgBox, No
		{
			Event.Gui.Destroy()
			return false
		}
		IfMsgBox, Cancel
		{
			Event.NoClose := true
			return true
		}
	}

	s_Advanced(Event) {
		this.save()
		run, % "notepad.exe """ . this.uniquename . "\server.properties""",,max
	}

	s_OpenFolder(Event) {
		openfolder := this.uniquename
		run, explore %openfolder%
	}
	
}

Class PluginsGUI { ;-----------------Plugins Window ---
	__New(Guiobj, type, uniquename) {
		this.type := type
		this.uniquename := uniquename
		this.Folder := (type = "plugins") ? "plugins" : "world\datapacks"
		this.ext := (type = "plugins") ? ".jar" : ".zip"
		
		Guiobj.Add("Button",,"Import " . type).OnEvent(PluginsGUI.Import.Bind(this))
		this.LV := Guiobj.Add("ListView", "AltSubmit Checked R7 Sort", "Enabled " . type)
		this.LV.OnEvent(PluginsGUI.Modify.Bind(this), "Normal")
		this.LV.OnEvent(PluginsGUI.Import.Bind(this), "DropFiles")
		Loop, Files, % this.Folder . "\*" . this.ext
		{
			Options := " "
			If FileExist(this.uniquename . "\" . this.Folder . "\" . A_LoopFileName)
				Options .= "Check"
			this.LV.LV_Add(Options, A_LoopFileName)
		}
		
	}
	
	Modify(Event) {
		critical
		If not (Event.GuiEvent == "I")
			return
		
		If Instr(Event.ErrorLevel, "C", true) {
			critical, off
			this.LV.LV_GetText(PluginName, Event.EventInfo)
			FileCreateDir, % this.uniquename . "\" . this.Folder
			try FileCopy, % this.Folder . "\" . PluginName, % this.uniquename . "\" . this.Folder . "\" . PluginName
		}
		Else If InStr(Event.ErrorLevel, "c", true) {
			critical, off
			this.LV.LV_GetText(PluginName, Event.EventInfo)
			FileDelete, % this.uniquename . "\" . this.Folder . "\" . PluginName
		}
		critical, off
	}
	
	Import(Event) {
		FileCreateDir, % this.Folder
		FileCreateDir, % this.uniquename . "\" . this.Folder
		If (Event.EventType = "DropFiles")
		{
			For index, file in Event.FileArray
			{
				Filename := StrSplit(file, "\").Pop()
				this.LV.LV_Add("Check",Filename)
				FileCopy, % file, % this.Folder . "\" . Filename
				try FileCopy, % file, % this.uniquename . "\" . this.Folder . "\" . Filename
			}
		}
		Else if (Event.EventType = "Normal")
		{
			FileSelectFile, FileList,M 1,,% "Import " . this.type, % (this.type = "plugins") ? "Spigot Plugins (*.jar)" : "Minecraft Datapacks (*.zip)"
			If ErrorLevel
				return
			Loop, Parse, FileList, `n
			{
				if (A_Index = 1) {
					Container := A_LoopField
					continue
				}
				this.LV.LV_Add("Check",A_LoopField)
				FileCopy, % Container . "\" . A_LoopField, % this.Folder . "\" . A_LoopField
				try FileCopy, % this.Folder . "\" . A_LoopField, % this.uniquename . "\" . this.Folder . "\" . A_LoopField
			}
		}
	}
	
}


	
{ ;----------------------------------Technical----------

Bool(value) {
	if (value = "false")
		v := false
	else
		v := true
	return v
}

String(value) {
	if value
		v := "true"
	else
		v := "false"
	return v
}

GetDate(uniquename,formatted := false) {
	dateformat := IniRead(uniquename . "\QuickServer.ini", "QuickServer", "DateModified", A_Now)
	If not formatted
		return dateformat
	FormatTime, v, %dateformat%, MM/dd/yy h:mmtt
	return v
}

UniqueFolderCreate(DesiredName := "Server") {
	If not FileExist(DesiredName . "_1") {
		try FileCreateDir, %DesiredName%_1
		catch {
			return false
		}
		return DesiredName . "_1"
	}
	loop {
		attempt := 1 + A_Index
		tryname := DesiredName . "_" . attempt
		if not FileExist(tryname) {
			FileCreateDir, %tryname%
			return tryname
		}
	}
}


RunTer(command, windowtitle, startingdir := "") {
	run, cmd.exe /c %command%, %startingdir%,, cmdPID

	WinWait, ahk_pid %cmdPID%
	WinExist("ahk_pid " . cmdPID)
	WinBlur(100)
	WinSetTitle, %windowtitle%
	return cmdPID
}

IniRead(FileName, Section, Key, Default := "ERROR") {
	IniRead, v, % FileName, % Section, % Key, % Default
	return v
}

IniWrite(Value, FileName, Section, Key) {
	IniWrite, % Value, % FileName, % Section, % Key
}

GetFontDefault() {
	If (A_ScreenWidth > A_ScreenHeight) {
		ScreenSize := A_ScreenHeight
	}
	Else {
		ScreenSize := A_ScreenWidth
	}
	v := {}
	v.Small := Round(ScreenSize * 8 / 1080)
	v.Normal := Round(ScreenSize * 10 / 1080)
	v.Large := Round(ScreenSize * 13 / 1080)
	return v
}


}

{ ;----------------------------------EULA-----------------------

eulaAgree(ServerFolder) {
	static EULAIAgree
	global eulaAgree_finishEULA
	gui, eulaAgree:new,,QuickServer
	gui, font, s%FontNormal%
	gui, add, link,, Please read and agree to the <a href="https://account.mojang.com/documents/minecraft_eula">Minecraft EULA</a>
	gui, add, text,,   
	gui, add, checkbox, vEULAIAgree geulaAgree_changeaccept, I agree to the Minecraft EULA
	gui, add, button, veulaAgree_finishEULA default geulaAgree_finishEULA, OK
	guicontrol, disable, eulaAgree_finishEULA
	gui, show, Autosize Center
	gui, +LastFound
	WinWaitClose
	If EULAIAgree {
		try FileDelete, %ServerFolder%\eula.txt
		FileAppend, eula=true, %ServerFolder%\eula.txt
		return true
	}
	return false
}	
	
eulaAgree_changeaccept() {
	gui, eulaAgree:submit, nohide
	guicontrol, enable, eulaAgree_finishEULA
	return
}

eulaAgree_finishEULA() {
	gui, eulaAgree:default
	gui, submit
	gui, destroy
}

}

{ ;----------------------------------Update---------------
UpdateServer(version := "latest") {
	if not InStr(FileExist(DefaultDir . "\BuildTools"), "D") {
		filecreatedir, %DefaultDir%\BuildTools
	}
	UpdateServerRetry:
	try {
		runwait, curl -z BuildTools.jar -o BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar, %DefaultDir%\BuildTools
	}
	catch {
		msgbox, 0x15, QuickServer, Error. If you see this, try downloading and installing curl at https://curl.haxx.se/windows/ 
		Ifmsgbox, Retry
		{
			goto UpdateServerRetry
		}
		return false
	}
	try {
		runwait, %comspec% /c java -jar BuildTools.jar --rev %version%, %DefaultDir%\BuildTools
		
	}
	catch {
		msgbox, 0x15, QuickServer error, Install failed. Try reinstalling Java at https://java.com/en/download/
		Ifmsgbox, Retry
		{
			goto UpdateServerRetry
		}
		return false
	}
	ServerFile := BuildTools_getServerFile(version)
	return ServerFile
}

BuildTools_getServerFile(version) {
	If not FileExist(DefaultDir "\BuildTools\BuildTools.log.txt")
	{
		return {confirmed: false}
	}
	FileRead, LogFile, %DefaultDir%\BuildTools\BuildTools.log.txt
	FileNamePos := 15 + Instr(LogFile, "  - Saved as .\", 0)
	ServerFile := StrReplace(StrReplace(SubStr(LogFile, FileNamePos), "`n"), "`r")
	Serverinfo := {}
	Serverinfo.version := StrReplace(StrReplace(ServerFile, "spigot-"), ".jar")        ; spigot-1.16.1.jar becomes 1.16.1
	Serverinfo.confirmed := false
	Serverinfo.isLatest := true
	IfExist,%DefaultDir%\BuildTools\%ServerFile%
	{
		Serverinfo.confirmed := true
	}
	Else IfExist, %DefaultDir%\BuildTools\spigot-%version%.jar
	{
		Serverinfo.confirmed := true
		ServerFile = spigot-%version%.jar
	}
	If not (version = "latest")
	{
		Serverinfo.isLatest := false
		Serverinfo.version := version
	}
	Serverinfo.uniquename := DefaultDir . "\BuildTools\" . ServerFile
	
	return, Serverinfo
}

DownloadFailed(byref this) {
	msgbox, 0x14,QuickServer Error,Could not find server file.`nAre you connected to the internet?`n`nOtherwise, you may be able to find the correct file manually. Would you like to try?
	Ifmsgbox, Yes
	{
		FileSelectFile, newfile,1, % DefaultDir "\BuildTools\",,Java executables (*.jar)
	}
	Else
	{
		this.UpdateThisServer()
	}
}
}

{ ;----------------------------------Misc----------------

DefaultPropertiesFile(FilePath) {
	FileAppend,
	(
spawn-protection=16
max-tick-time=60000
query.port=25565
generator-settings=
sync-chunk-writes=true
force-gamemode=false
allow-nether=true
enforce-whitelist=false
gamemode=survival
broadcast-console-to-ops=true
enable-query=false
player-idle-timeout=0
difficulty=easy
spawn-monsters=true
broadcast-rcon-to-ops=true
op-permission-level=4
pvp=true
entity-broadcast-range-percentage=100
snooper-enabled=true
level-type=default
hardcore=false
enable-status=true
enable-command-block=true
max-players=20
network-compression-threshold=256
resource-pack-sha1=
max-world-size=29999984
function-permission-level=2
rcon.port=25575
server-port=25565
debug=false
server-ip=
spawn-npcs=true
allow-flight=false
level-name=world
view-distance=10
resource-pack=
spawn-animals=true
white-list=false
rcon.password=
generate-structures=true
max-build-height=256
online-mode=true
level-seed=
use-native-transport=true
prevent-proxy-connections=false
enable-jmx-monitoring=false
enable-rcon=false
motd=A Minecraft Server
), %FilePath%

}

msb(txt) {
	msgbox,0,, %txt%
}

WinBlur(Opacity := 0, BackgroundColor := 0x000000, WinTitle := "", Enable := true) {

	TargetWinHwnd := WinExist(WinTitle)
	If not TargetWinHwnd {
		return, false
		}
	If (Opacity > 255) {
		Opacity := 255
		}
	Else if (Opacity < 1) {
		Opacity := 0
		Enable := false
		}
	If (BackgroundColor > 0xffffff) {
		throw Exception("invalid color", -1)
		return false
		}
	Else If (BackgroundColor < 0) {
		throw Exception("invalid color", -1)
		return false
		}
	If Enable {
		accent_state := 4
		}
	Else {
		accent_state := 0
		}
	
	gradient_color := Opacity * 16777216 + BackgroundColor
	
	;external
	static pad := A_PtrSize = 8 ? 4 : 0, WCA_ACCENT_POLICY := 19
    accent_size := VarSetCapacity(ACCENT_POLICY, 16, 0)
    NumPut((accent_state > 0 && accent_state < 5) ? accent_state : 0, ACCENT_POLICY, 0, "int")

    NumPut(gradient_color, ACCENT_POLICY, 8, "int")

    VarSetCapacity(WINCOMPATTRDATA, 4 + pad + A_PtrSize + 4 + pad, 0)
    && NumPut(WCA_ACCENT_POLICY, WINCOMPATTRDATA, 0, "int")
    && NumPut(&ACCENT_POLICY, WINCOMPATTRDATA, 4 + pad, "ptr")
    && NumPut(accent_size, WINCOMPATTRDATA, 4 + pad + A_PtrSize, "uint")
    if !(DllCall("user32\SetWindowCompositionAttribute", "ptr", TargetWinHwnd, "ptr", &WINCOMPATTRDATA))
        {
		throw Exception("Failed to set transparency / blur", -1)
		return false
		}
    return true
	
	
}

CopyFilesAndFolders(SourcePattern, DestinationFolder, DoOverwrite = false)
{

    ; First copy all the files (but not the folders):
    FileCopy, %SourcePattern%, %DestinationFolder%, %DoOverwrite%
    ErrorCount := ErrorLevel
    ; Now copy all the folders:
    Loop, %SourcePattern%, 2  ; 2 means "retrieve folders only".
	{
		FileCopyDir, %A_LoopFileFullPath%, %DestinationFolder%\%A_LoopFileName%, %DoOverwrite%
        ErrorCount += ErrorLevel
	}
	return ErrorCount
}

}

{ ; -----------------------------    INCLUDES -------------------
	return
	#Include, %A_ScriptDir%\GuiObject.ahk
}