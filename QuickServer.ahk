;-------- Quick Modifications --------------

global DefaultDir := A_AppData "\.QuickServer"
global Enable_CheckForUpdates := true
global defaultRAM := 2
global debug := false

{ ;---------------------------  AUTORUN ----------------------------------


#NoTrayIcon
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
global ngrok_enable := Getngrok_enable()

If FileExist("QuickServer.ico") {
	menu, tray, icon, QuickServer.ico
}

If Enable_CheckForUpdates {
		CheckForUpdates()
}


OnExit("ExitFunc")

ChooseServerWindow()

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
	ngrok_stop()
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
	static
	global ChosenNumber
	ServerList := GetServerList()
	gui,MainGUI:destroy
	gui, MainGUI:new
	gui, Font, s%FontNormal%
	gui, add, text,,Select Server:
	LV_width := FontNormal * 50
	gui, add, ListView, % "R15 w" . LV_width . " gSelectServer_ListView vSelectServer_ListView -Multi Count" . ServerList.Length(), Name|DateFormat|uniquename|Date Modified
	guicontrol, -redraw, SelectServer_ListView
	Loop, % ServerList.Length()
	{
		DateFormat := GetDate(ServerList[A_Index])
		
		LV_Add("",IniRead(ServerList[A_Index] . "\QuickServer.ini", "QuickServer", "name", "Untitled server"),GetDate(ServerList[A_Index],false),ServerList[A_Index],GetDate(ServerList[A_Index],true))
	}
	LV_ModifyCol(1, FontNormal * 30)
	LV_ModifyCol(1, "Sort")
	LV_Modify(1, "Focus")
	LV_ModifyCol(2, 0)
	LV_ModifyCol(3, 0)
	LV_ModifyCol(4, "AutoHDR NoSort")
	guicontrol, +redraw, SelectServer_ListView
	
	
	gui, add, text,ym,   
	gui, Font, s%FontLarge%
	gui, add, Button, gButton_Main_NewServer, New Server
	gui, add, Button, gSelectServer_Run, Run Server
	gui, add, Button, gSelectServer_Settings, Edit Server
	gui, add, Button, gSelectServer_Import, Import World
	gui, add, Link, gSelectServer_Connections, <a>Click here to Setup`nConnection via Internet</a>
	gui, add, Link, gSelectServer_Restore, <a>Restore a backup</a>
	gui, add, Link, gReInstall, <a>Help! Every time I try to`ncreate a new server it fails</a>

	
	gui, show, Autosize Center
}



; Main window buttons
{

SelectServer_ListView() {
	critical
	If (A_GuiEvent = "ColClick") and (A_EventInfo = 4) {
		;sort by date modified
		static inverse
		inverse := not inverse
		options := inverse ? "desc" : ""
		LV_ModifyCol(2, "Sort" . options)
	}
	Else If (A_GuiEvent = "DoubleClick") {
		critical,off
		LV_GetText(uniquename, A_EventInfo,3)
		SelectServer_Run()
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

SelectServer_Run() {
	gui,MainGui:submit,nohide
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
	gui,MainGUI:submit,nohide
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
	MsgBox,0x1,Import Server,Select a Minecraft world folder to import. They are usually found in the folder %appdata%\.minecraft\saves
	IfMsgBox Cancel
		return
	FileSelectFolder, Worldfolder, %A_AppData%\.minecraft\saves,,Import World Folder
	If ErrorLevel
		return
	If not FileExist(Worldfolder . "\Level.dat")
		throw Exception("Invalid World Folder",-1)
	uniquename := UniqueFolderCreate()
	FileCreateDir, %uniquename%\world
	If CopyFilesAndFolders(Worldfolder . "\*.*",uniquename . "\world")
		msgbox, 0x10,Import World,Some world data could not be imported
	CreatedServer := new Server(uniquename)
	CreatedServer.name := "Imported Server"
	If not CreatedServer.Rename()
		return
	If not eulaAgree(CreatedServer.uniquename)
		return
	CreatedServer.UpdateThisServer()
	CreatedServer.props := new properties(CreatedServer.uniquename . "\server.properties")
	CreatedServer.props.setKey("motd", CreatedServer.name)
	CreatedServer.RAM := defaultRAM
	CreatedServer.DateModified := A_Now
	ChooseServerWindow()
	CreatedServer.Settings()
	return
}

SelectServer_Connections() {
	ngrok_run()
	ConnectionsWindow.Open()
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


MainGUIGUIClose() {
	If ConnectionsWindow.IsOpen {
		MsgBox, 0x40134,Close Connections,Are you sure you sure you want to quit? Your server may lose connection.
		IfMsgBox, No
		{
			ChooseServerWindow()
			return
		}
	}
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
	gui,MainGUI:default
	LV_GetText(v, LV_GetNext(,"Focused"),3)
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


{ ;----------------------------------------------ngrok----------------

ngrok_run() {
	global ngrok_pid
	detecthiddenwindows,on
	if ngrok_enable and not WinExist("ahk_exe ngrok.exe")
		Run,ngrok tcp 25565,, % debug ? A_Space : "hide", ngrok_pid
}

ngrok_stop() {
	global ngrok_pid
	detecthiddenwindows,on
	WinClose, ahk_exe ngrok.exe
}

ngroksetup() {
	global
	gui, ngroksetup:new
	gui, +AlwaysOnTop
	gui, font, s%FontNormal%
	gui, add, Link,, Ngrok is a free service to open your server to the public. Set up an ngrok account <a href="https://ngrok.com/">here</a>.`n`nAfter creating your ngrok account, enter your account AuthToken below.
	gui, add, Edit, vngrok_authtoken w150
	gui, add, CheckBox, vngrok_enable Checked%ngrok_enable%, Use ngrok to connect to your server
	gui, font, s%FontLarge%
	gui, add, Button, gButton_ngrok_OK, OK
	gui, show, Autosize Center
}

Button_ngrok_OK() {
	global ngrok_authtoken
	gui, ngroksetup:submit
	runwait, ngrok authtoken %ngrok_authtoken%,,hide
	IniWrite, %ngrok_enable%, QuickServer.ini, ngrok, ngrok_enable
	gui, ngroksetup:destroy
	toggle := ngrok_enable ? ngrok_run() : ngrok_stop()
	If ngrok_enable and not FileExist("ngrok.exe") {
		Throw Exception("Ngrok installation failed. Connect to the internet and restart QuickServer to try again")
	}
}

Getngrok_enable() {
	return IniRead("QuickServer.ini", "ngrok", "ngrok_enable", true)
}

}


{ ;----------------------------------------Connections Window

class ConnectionsWindow {
	static IsOpen := false
	
	Close() {
		this.IsOpen := (this.IsOpen <= 0) ? 0 : this.IsOpen - 1
		if not this.IsOpen {
			gui, Connections:destroy
			ngrok_stop()
		}
	}
	
	Open() {
		static
		global ConnectionsWindowPress
		this.IsOpen += 1
		ngrok_run()
		FileCreateDir, %A_Temp%\QuickServer
		gui, Connections:new
		gui, +LastFound +AlwaysOnTop
		WinSetTitle, Connections
		gui, font, % "s" . FontNormal
		width := FontNormal * 70
		gui, add, Text,, Click a connection to set it up or modify it.`n`nNgrok is recommended for first-time users.
		gui, add, ListView, % "w" . width . " AltSubmit Count4 Disabled vConnectionsWindowPress gConnectionsWindowPress Grid R5 noSortHdr", Name|Address|Status|Connectivity
		guicontrol, -Redraw, ConnectionsWindowPress
		LV_Add("","Local Computer", "LOCALHOST", "Connected", "This computer only")
		LV_Add("","LAN","","","This WiFi network only")
		LV_Add("","Public IP Address   ","","","Public")
		ngroklink := this.ngrok_CheckConnection()
		LV_Add("","Ngrok","","", "Public")
		LV_ModifyCol(1,"AutoHdr")
		LV_ModifyCol(2,FontNormal * 20)
		LV_ModifyCol(3,FontNormal * 15)
		LV_ModifyCol(4,"AutoHdr")
		gui, add, Text, vConnectionsWindowRefreshing,Refreshing...
		gui, add, Button, gConnectionsWindowRefresh vConnectionsWindowRefresh, Refresh
		Gui, show, Autosize Center
		this.Refresh()
	}
	
	Refresh() {
		global ConnectionsWindowPress, ConnectionsWindowRefresh, ConnectionsWindowRefreshing
		If not this.IsOpen
			return
		
		guicontrol, disable, ConnectionsWindowRefresh
		guicontrol,,ConnectionsWindowRefreshing, Refreshing...
		guicontrol, disable, ConnectionsWindowPress
		guicontrol, -Redraw, ConnectionsWindowPress
		LANIP := (A_IPAddress1 = 0.0.0.0) ? "" : A_IPAddress1
		LV_Modify(2,"Col2",LANIP, this.LAN_CheckConnection() ? "Connected" : (LANIP ? "Probably not connected" : "Not connected"))
		PublicIP := this.PublicIP_CheckConnection()
		LV_Modify(3,"Col2",PublicIP,PublicIP ? "Unknown" : "Not connected")
		ngroklink := this.ngrok_CheckConnection()
		LV_Modify(4,"Col2",ngroklink,ngroklink ? "Connected" : "Not Connected")
		guicontrol, enable, ConnectionsWindowPress
		guicontrol, +Redraw, ConnectionsWindowPress
		guicontrol,,ConnectionsWindowRefreshing, % A_Space
		guicontrol, enable, ConnectionsWindowRefresh
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

ConnectionsWindowRefresh() {
	ConnectionsWindow.Refresh()
}

ConnectionsWindowPress() {
	critical
	If (A_GuiEvent = "Normal")
	{
		critical off
		If (A_EventInfo = 1) {
			msgbox,0x40000,Local Computer,If you are playing Minecraft on this computer, you can connect to the server by using LOCALHOST as the server address.
		}
		If (A_EventInfo = 2) {
			msgbox,0x40000,LAN,Anyone else playing on your LAN (a.k.a. your WiFi network) can connect to this address. However, you might need to mark the network as "private" (on your computer go to Settings > Network and Internet > Change Connection Properties)
		}
		If (A_EventInfo = 3) {
			gui, PublicIP:new
			gui, +AlwaysOnTop
			gui, font, s%FontNormal%
			gui, add, Link,,<a href="https://www.wikihow.com/Set-Up-Port-Forwarding-on-a-Router">Setup Port Forwarding</a> to use a permanent IP address for your server (note: Minecraft uses the port 25565)`n`nOnce you have set up port forwarding`, you can optionally connect it to a permanent`ncustom address (i.e. <a>MyServerIsCool.com</a>)
			gui, add, Button, default gPublicIPGuiClose, Ok
			gui, show, autosize center
		}
		If (A_EventInfo = 4) {
			ngroksetup()
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





class Server { ;-------------------------Class Server-----------------------------------------------
	
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
			If Bool(this.props.getKey("hardcore"))
			{
				return "Hardcore"
			}
			return this.props.getKey("difficulty")
				
		}
		set {
			If (value = "UHC")
			{
				this.UHC := true
				this.props.setKey("hardcore", "true")
				return
			}
			If (value = "Hardcore")
			{
				this.UHC := false
				this.props.setKey("hardcore", "true")
				return
			}
			this.UHC := false
			this.props.setKey("difficulty", value)
			this.props.setKey("hardcore", "false")
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
	
	__New(uniquename := "") {
		this.uniquename := uniquename
		this.props := new properties(this.uniquename . "\server.properties")
	}
	
		
	create() {
		this.version := "latest"
		this.uniquename := UniqueFolderCreate(this.uniquename)
		if not this.uniquename
			throw Exception("Missing server", -1)
		this.name := "New Server"
		if not this.Rename()
			return false
		If not eulaAgree(this.uniquename)
			return false
		this.UpdateThisServer()
		this.props := new properties(this.uniquename . "\server.properties")
		this.props.setKey("motd", this.name)
		this.RAM := defaultRAM
		this.DateModified := A_Now
		return true
	}
	
	start() {
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
		cmd = java -Xmx%RAM%G -Xms%RAM%G -jar "%JarFile%" nogui
		ServerPID := RunTer(cmd, this.name, uniquename)
		this.DateModified := A_Now
		
		ngrok_run()
		sleep, 10000
		ConnectionsWindow.Open()
		Process, WaitClose, %ServerPID%
		ConnectionsWindow.Close()
	}
	
	Settings(flush := false) {
		static
		If flush {
			this.props.setKey("motd", motd)
			this.props.setKey("gamemode", gamemode)
			this.props.setKey("level-seed", level_seed)
			this.props.setKey("max-players", max_players)
			this.props.setKey("spawn-protection", spawn_protection)
			this.props.setKey("spawn-monsters", String(spawn_monsters))
			this.props.setKey("spawn-npcs", String(spawn_npcs))
			this.props.setKey("spawn-animals", String(spawn_animals))
			this.props.setKey("pvp", String(pvp))
			this.RAM := RAM
			this.difficulty := difficulty
			gui, %settingsname%:destroy
			return
		}
		
		;settings menu
		settingsname := this.uniquename
		buttonname := ""
		btn_func := Func("SettingsButtonPush").Bind(this, buttonname, settingsname)
		
		
		gui, %settingsname%:new
		gui, +LastFound
		gui, font, s%FontLarge%
		gui, add, Text,, % this.name
		gui, font, s%FontNormal%
		gui, add, Button, vs_Start, Start Server!
		guicontrol, +g, s_Start, %btn_func%
		gui, add, Button, vs_Rename, Rename Server
		guicontrol, +g, s_Rename, %btn_func%
		gui, add, text, vs_version, % "Current version: " . this.version . "`nPress the button below to either update                         `nthe current version to the latest build`n(i.e. if the server says it is out of date)`nor upgrade the server to a newer`nversion of Minecraft."
		gui, add, Button, vs_Update, Change version or update to latest build
		guicontrol, +g, s_Update, %btn_func%
		gui, add, Button, vs_Backup, Create a backup of this server
		guicontrol, +g, s_Backup, %btn_func%
		gui, add, Button, vs_Duplicate, Duplicate this server
		guicontrol, +g, s_Duplicate, %btn_func%
		gui, add, Button, vs_Delete, Delete this server
		guicontrol, +g, s_Delete, %btn_func%
		
		gui, add, text,ym,   
		
		
		
		gui, add, link, vs_Plugins, <a>Server Plugins</a> -- Easily import and manage plugins!
		guicontrol, +g, s_Plugins, %btn_func%
		gui, add, text,, Server Description (appears on Multiplayer menu)
		gui, add, Edit, Limit59 vmotd
		guicontrol,, motd, % this.props.getKey("motd")
		gui, add, text,, Gamemode
		gui, add, DropDownList, vgamemode, Survival|Creative|Adventure
		guicontrol, ChooseString, gamemode, % this.props.getKey("gamemode")
		gui, add, text,, Difficulty
		gui, add, DropDownList, vdifficulty, Peaceful|Easy|Normal|Hard|Hardcore|UHC
		guicontrol, ChooseString, difficulty, % this.difficulty
		pvp := Bool(this.props.getKey("pvp"))
		gui, add, CheckBox, vpvp Checked%pvp%, Allow PVP (player vs player)
		gui, add, text,, Custom World Seed
		gui, add, Edit, vlevel_seed, % this.props.getKey("level-seed")
		gui, add, text,, Maximum players
		gui, add, Edit
		gui, add, UpDown, vmax_players, % this.props.getKey("max-players")
		
		gui, add, text,, Spawn Grief-Protection Radius
		gui, add, Edit
		gui, add, UpDown, vspawn_protection, % this.props.getKey("spawn-protection")
		spawn_monsters := Bool(this.props.getKey("spawn-monsters"))
		gui, add, CheckBox, vspawn_monsters Checked%spawn_monsters%, Automatically Spawn Monsters
		spawn_npcs := Bool(this.props.getKey("spawn-npcs"))
		gui, add, CheckBox, vspawn_npcs Checked%spawn_npcs%, Automatically Spawn NPCs (Villagers)
		spawn_animals := Bool(this.props.getKey("spawn-animals"))
		gui, add, CheckBox, vspawn_animals Checked%spawn_animals%, Automatically Spawn Animals
		gui, add, text,, Maximum Server Memory (in Gigabytes)
		gui, add, Edit
		RAM := this.RAM
		gui, add, UpDown, vRAM, %RAM%
		gui, add, Link, vs_Advanced, <a>Advanced Settings</a>`n
		guicontrol, +g, s_Advanced, %btn_func%
		gui, add, Link, vs_OpenFolder, <a> Open the Server Folder </a>
		guicontrol, +g, s_OpenFolder, %btn_func%
		
		
		
		gui, add, Button, default vs_Save, Save Settings
		guicontrol, +g, s_Save, %btn_func%
		gui, show, Autosize Center
	}
	
	Save() {
		this.settings(true) ;saves the settings onto the disk
		this.DateModified := A_Now
	}
	
	UpdateThisServer() {
		InputBox, newversion, Update or Select Version, Enter the desired version(example: 1.16.1).`n`nType "latest" to use the latest version.,,,,,,,, % this.version
		If not Errorlevel {
			UpdateResult := UpdateServer(newversion)
			if not UpdateResult.confirmed
				DownloadFailed(this)
			this.Version := UpdateResult.version
			this.JarFile := UpdateResult.uniquename
			this.UseLatest := UpdateResult.IsLatest
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
	
	Rename() {
		InputBox, NewName, QuickServer, Enter a new name for your server.,,,,,,,, % this.name
		If Errorlevel
			return false
		this.name := SubStr(NewName,1,50)
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
		}
	}
}

SettingsButtonPush(byref this, byref buttonname, settingsname) {
	gui, %settingsname%:default
	buttonname := A_GuiControl
	If (buttonname = "s_Plugins") {
		PluginsGUI(this)
		return
	}
	gui, submit
	ChooseServerWindow()
	this.save()
	If (buttonname = "s_Delete") {
		this.Delete()
	}
	Else If (buttonname = "s_Duplicate") {
		this.Duplicate()
	}
	Else If (buttonname = "s_Advanced") {
		run, % "notepad.exe """ . this.uniquename . "\server.properties""",,max
	}
	Else if (buttonname = "s_Update") {
		this.UpdateThisServer()
		this.Settings()
	}
	Else if (buttonname = "s_Start") {
		this.Start()
	}
	Else if (buttonname = "s_OpenFolder") {
		openfolder := this.uniquename
		run, explore %openfolder%
	}
	Else if (buttonname = "s_Backup") {
		this.backup()
	}
	Else if (buttonname = "s_Rename") {
		this.Rename()
		this.settings()
	}
}

{ ;--------------------------------------Plugins Window ---

PluginsGUI(byref this) {
	static
	msgbox, 0x33, Plugins, It is recommended to backup your world before you modify plugins. Do this now?
	IfMsgBox, Cancel
		return "cancel"
	IfMsgBox, Yes
		this.backup()
		
		
	Gui, plugins:destroy
	
	Gui, plugins:new
	Gui, font, s%FontNormal%
	Gui, add, link,, Browse for Plugins at <a href="https://www.spigotmc.org/resources/categories/spigot.4/?order=download_count"> www.spigotmc.org </a>`nOnce you have downloaded a plugin, click Import Plugins.
	Gui, add, Button,vImportButton gPluginsGUI_Import,Import Plugins
	ImportFunc := Func("PluginsGUI_Import").Bind(this)
	GuiControl, +g, ImportButton, %ImportFunc%
	Gui, add, Text,,Plugins on this server (checkmark = enabled):
	Gui, add, ListView,vpluginlist AltSubmit Checked R15 Sort -Hdr, Name
	CheckFunc := Func("PluginsGUI_Modify").Bind(this)
	GuiControl, +g, pluginlist, %CheckFunc%
	Loop, Files, plugins\*.jar
	{
		Options := " "
		If FileExist(this.uniquename . "\plugins\" . A_LoopFileName)
			Options .= "Check"
		LV_Add(Options, StrReplace(A_LoopFileName,".jar"))
	}
	Gui, show, autosize center
	
	
}

PluginsGUI_Modify(byref this) {
	critical
	Event := ErrorLevel
	If not (A_GuiEvent == "I")
		return
	If InStr(Event, "C", true) {
		LV_GetText(PluginName, A_EventInfo)
		FileCreateDir, % this.uniquename . "\plugins"
		try FileCopy, % "plugins\" . PluginName . ".jar", % this.uniquename . "\plugins\" . PluginName . ".jar"
	}
	Else If InStr(Event, "c", true) {
		LV_GetText(PluginName, A_EventInfo)
		FileDelete, % this.uniquename . "\plugins\" . PluginName . ".jar"
	}
	critical, off
}

PluginsGUI_Import(byref this) {
	FileCreateDir, plugins
	FileCreateDir, % this.uniquename . "\plugins"
	FileSelectFile, FileList,M 1,,Import Plugins,Spigot Plugins (*.jar)
	If ErrorLevel
		return
	Loop, Parse, FileList, `n
	{
		if (A_Index = 1) {
			Container := A_LoopField
			continue
		}
		LV_Add("Check",StrReplace(A_LoopField,".jar"))
		FileCopy, % Container . "\" . A_LoopField, % "plugins\" . A_LoopField
		try FileCopy, % "plugins\" . A_LoopField, % this.uniquename . "\plugins\" . A_LoopField
	}
}

}

class properties {
		
	__New(FilePath) {
		this.FilePath := FilePath
		If not FileExist(this.FilePath)
			DefaultPropertiesFile(this.FilePath)
	}

	GetKey(key) {
			FileRead, completeproperties, % this.FilePath
			completeproperties := "`r`n" . completeproperties
			startwkey := Substr(completeproperties, Instr(completeproperties, "`n" . key . "="))
			split := StrSplit(startwkey, ["=" , "`r`n"])
			value := split[2]
			return value
	}
	
	SetKey(Key, Value) {
		FileRead, completeproperties, % this.FilePath
		Position := 1 + Instr(completeproperties, "`n" . Key . "=")
		firsthalf := Substr(completeproperties, 1, Position - 1)
		startwkey := startwkey := Substr(completeproperties, Position)
		split := StrSplit(startwkey, "`r`n")
		
		filerecreate := firsthalf . key . "=" . Value
		For Index, fileline in split {
			If not (Index = 1)
				filerecreate = %filerecreate%`r`n%fileline%
			
		}
		try FileDelete, % this.FilePath
		FileAppend, %filerecreate%, % this.FilePath
	}
	
}
	
{ ;---------------------------------------Technical----------

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

{ ;-----------------------------------------EULA-----------------------

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



{ ;-------------------------------------Update---------------
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

{ ;-------------------------------------Misc----------------

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
enable-command-block=false
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
