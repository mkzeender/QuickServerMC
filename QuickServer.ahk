global DefaultDir := A_AppData "\.QuickServer\"
global defaultRAM := 2
#NoTrayIcon
FileCreateDir, %DefaultDir%
SetWorkingDir, %DefaultDir%
#persistent
#singleinstance, Off

If FileExist("QuickServer.ico") {
	menu, tray, icon, QuickServer.ico
}
OnError("ErrorFunc")
OnExit("ExitFunc")
CheckForUpdates()
AutoRun()
return



;---------------------------  AUTORUN ----------------------------------
AutoRun() {

global ServerList := GetServerList()
global ngrok_enable := Getngrok_enable()

If WinExist("ahk_exe QuickServer.exe")
{
	WinActivate
	ExitApp
}
Else If not A_IsCompiled and WinExist("QuickServer.ahk ahk_exe Autohotkey.exe")
{
	WinActivate
	ExitApp
}

ChooseServerWindow()
return
}

CheckForUpdates() {
	FileRead, CurrentBuild, build.txt
	URLDownloadToFile,https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/build.txt, build.txt
	FileRead, LatestBuild, build.txt
	If not (LatestBuild = CurrentBuild) {
		try FileDelete, QuickServer-setup.ahk
		URLDownloadToFile,https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/QuickServer-setup.ahk, QuickServer-setup.ahk
		If not FileExist("QuickServer-setup.ahk") {
			fail := true
		}
		try run, QuickServer.exe QuickServer-setup.ahk
		catch
		{
			fail := true
		}
		If not fail {
			ExitApp
		}
	}
}


ExitFunc() {
	IniWrite, %ServerList%, QuickServer.ini, Servers, ServerList
}

ErrorFunc(exception) {
	FormatTime, t,, MM/dd/yyyy hh:mm:ss tt
	ErrorMsg := "[" . t . "] Something went wrong because I am dumb. Error message: " . exception.Message
	msgbox,0x10,, %ErrorMsg%
	FileAppend, %ErrorMsg%`n, QuickServer.log
	return true
}




;----------------------------------Main GUI (SelectServer) Window-------------------------------- 
{
;----------ngrok----------------
{

ngrok_run() {
	global
	if ngrok_enable
		RunTer("ngrok tcp 25565", "ngrok")
}

ngroksetup() {
	global
	gui, ngroksetup:new
	gui, font, s10
	gui, add, Link,, Ngrok is a free service to open your server to the public. Set up an ngrok account <a href="https://ngrok.com/"> here </a>.`n`nAlternatively, you can use <a href="https://www.wikihow.com/Set-Up-Port-Forwarding-on-a-Router"> Port Forwarding </a> for a permanent IP address (or website!).`n`nAfter creating your ngrok account, enter your account AuthToken below.`nYour server's link will be labeled as "forwarding" and will look something like 3.tcp.ngrok.io:12345 (ignore the "tcp://")
	gui, add, Edit, vngrok_authtoken w150
	gui, add, CheckBox, vngrok_enable Checked%ngrok_enable%, Use ngrok to connect to your server
	gui, font, s12
	gui, add, Button, gButton_ngrok_OK, OK
	gui, show, Autosize Center
}

Button_ngrok_OK() {
	global
	gui, ngroksetup:submit
	run, ngrok authtoken %ngrok_authtoken%,,hide
	IniWrite, %ngrok_enable%, QuickServer.ini, ngrok, ngrok_enable
	gui, ngroksetup:destroy
	ngrok_run()
	If ngrok_enable and not FileExist("ngrok.exe") {
		Throw Exception("Ngrok installation failed. Connect to the internet and restart QuickServer to try again")
	}
}

Getngrok_enable() {
	return IniRead("QuickServer.ini", "ngrok", "ngrok_enable", true)
}

}

ChooseServerWindow() {
	global ChosenNumber
	gui, MainGUI:new
	gui, Font, s13
	gui, add, Button, gButton_Main_NewServer, New Server
	gui, add, text,,`n Select Server:
	gui, add, DropDownList, vChosenNumber Choose1 altsubmit, % ExtractServerNames()
	gui, add, Button, gSelectServer_Run, Run Server
	gui, add, Button, gSelectServer_Settings, Edit Server
	gui, add, Button, gSelectServer_Delete, Delete Server
	gui, add, Link, gngroksetup, <a> How do my friends and I connect to my server? </a>`n
	gui, add, Link, gReInstall, <a>Help! Every time I try to create a new server it fails</a>
	gui, show, Autosize Center
}



; Main window buttons
{

Button_Main_NewServer() {

	CreatedServer := new Server("Server")
	If not CreatedServer.create()
	{
		return
	}
	gui,MainGUI:destroy
	ServerList := ServerList . "|" . CreatedServer.uniquename
	ChooseServerWindow()
	CreatedServer.settings()
}

SelectServer_Run() {
	gui,MainGui:submit,nohide
	SelectedServer := new Server(GetChosenUniquename())
	SelectedServer.Start()
}

SelectServer_Settings() {
	gui,MainGUI:submit,nohide
	SelectedServer := new Server(GetChosenUniquename())
	SelectedServer.Settings()
}

SelectServer_Delete() {
	gui,MainGUI:submit,nohide
	SelectedServer := GetChosenUniquename()
	msgbox,0x134,QuickServer,Are you sure you want to delete %SelectedServer%? You may be able to recover the world folder from the recycle bin.
	Ifmsgbox, Yes
	{
		FileRecycle, %SelectedServer%
		replacetxt = |%SelectedServer%
		ServerList := StrReplace(ServerList, replacetxt)
	}
	gui,MainGUI:destroy
	ChooseServerWindow()
}


ReInstall() {
	InputBox, v, Reset and Reinstall QuickServer, This will reset the installation of Minecraft Server. It will NOT delete your servers`, but after resetting`, you will need to update/upgrade each of your servers before running them (go to: server settings>update/upgrade server). Type "confirm" below to confirm
	If not ErrorLevel and (v = "confirm")
	{
		FileRemoveDir, BuildTools, true
	}
}


MainGUIGUIClose() {
	ExitApp
}

}


ExtractServerNames() {
	global ServerListArray := StrSplit(StrReplace(ServerList,"|",,,1), "|")
	For index, uniquename in ServerListArray
	{
		NamesList := NamesList . "|" . IniRead(uniquename . "\QuickServer.ini", "QuickServer", "name", "Untitled Server")
	}
	return StrReplace(NamesList,"|",,,1)
}

GetChosenUniquename() {
	Global ServerListArray
	Global ChosenNumber
	return ServerListArray[ChosenNumber]
}


GetServerList() {
	return IniRead("QuickServer.ini", "Servers", "ServerList", A_Space)
}



}




class Server {
	
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
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, version
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
		return true
	}
	
	start() {
		RAM := this.RAM
		JarFile := this.JarFile
		uniquename := this.uniquename
		cmd = java -Xmx%RAM%G -Xms%RAM%G -jar "%JarFile%" nogui
		RunTer(cmd, this.name, uniquename)
		ngrok_run()
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
		gui, font, s10
		gui, add, Button, vs_Start, Start Server!
		guicontrol, +g, s_Start, %btn_func%
		gui, add, Button, vs_Rename, Rename Server
		guicontrol, +g, s_Rename, %btn_func%
		gui, add, text, vs_version, % "Currently running " . this.version . ". press the button below to either update the current version (i.e. if the server says it is out of date)`nor upgrade the server to a newer version of minecraft"
		gui, add, Button, vs_Update, Change version or update to latest build
		guicontrol, +g, s_Update, %btn_func%
		gui, add, Button, vs_Backup, Create a backup of this server
		guicontrol, +g, s_Backup, %btn_func%
		
		gui, add, text,x100 y150,`n
		
		
		gui, add, text,, Server Description (appears on Multiplayer menu)
		gui, add, Edit, vmotd, % this.props.getKey("motd")
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
		
		
		
		gui, add, Button, vs_Save, Save Settings
		guicontrol, +g, s_Save, %btn_func%
		gui, add, Link, vs_OpenFolder, <a> Open the Server Folder </a> to access more advanced settings, access the "plugins" folder, and access the world folder`n
		guicontrol, +g, s_OpenFolder, %btn_func%
		gui, show, Autosize Center
	}
	
	Save() {
		this.settings(true) ;saves the settings onto the disk
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
		this.name := NewName
		return true
	}
	
}

SettingsButtonPush(byref this, byref buttonname, settingsname) {
	gui, %settingsname%:default
	gui, submit
	buttonname := A_GuiControl
	this.save()
	if (buttonname = "s_Update") {
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
		gui, MainGUI:destroy
		ChooseServerWindow()
		this.settings()
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

UniqueFolderCreate(DesiredName) {
	If not FileExist(DesiredName) {
		try FileCreateDir, %DesiredName%
		catch {
			return false
		}
		return DesiredName
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

eulaAgree(ServerFolder) {
	static EULAIAgree
	global eulaAgree_finishEULA
	gui, eulaAgree:new,,QuickServer
	gui, font, s10
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


UpdateServer(version := "latest") {
	if not InStr(FileExist(A_AppData "\.QuickServer\BuildTools"), "D") {
		filecreatedir, %A_AppData%\.QuickServer\BuildTools
	}
	UpdateServerRetry:
	try {
		runwait, curl -z BuildTools.jar -o BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar, %A_AppData%\.QuickServer\BuildTools
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
		runwait, %comspec% /c java -jar BuildTools.jar --rev %version%, %A_AppData%\.QuickServer\BuildTools
		
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
	If not FileExist(A_AppData "\.QuickServer\BuildTools\BuildTools.log.txt")
	{
		return {confirmed: false}
	}
	FileRead, LogFile, %A_AppData%\.QuickServer\BuildTools\BuildTools.log.txt
	FileNamePos := 15 + Instr(LogFile, "  - Saved as .\", 0)
	ServerFile := StrReplace(StrReplace(SubStr(LogFile, FileNamePos), "`n"), "`r")
	Serverinfo := {}
	Serverinfo.version := StrReplace(StrReplace(ServerFile, "spigot-"), ".jar")        ; spigot-1.16.1.jar becomes 1.16.1
	Serverinfo.confirmed := false
	Serverinfo.isLatest := true
	IfExist,%AppData%\.QuickServer\BuildTools\%ServerFile%
	{
		Serverinfo.confirmed := true
	}
	Else IfExist, %AppData%\.QuickServer\BuildTools\spigot-%version%.jar
	{
		Serverinfo.confirmed := true
		ServerFile = spigot-%version%.jar
	}
	If not (version = "latest")
	{
		Serverinfo.isLatest := false
		Serverinfo.version := version
	}
	Serverinfo.uniquename := A_AppData "\.QuickServer\BuildTools\" . ServerFile
	
	return, Serverinfo
}

DownloadFailed(byref this) {
	msgbox, 0x14,QuickServer Error,Could not find server file.`nAre you connected to the internet?`n`nOtherwise, you may be able to find the correct file manually. Would you like to try?
	Ifmsgbox, Yes
	{
		FileSelectFile, newfile,1, % A_AppData "\.QuickServer\BuildTools\",,Java executables (*.jar)
	}
	Else
	{
		this.UpdateThisServer()
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
blogliifj=yay
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