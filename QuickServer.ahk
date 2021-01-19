{ ;----------------------------------- Quick Modifications --------------
  ;----------------------date := 1/18/2021  - 2
global             DefaultDir := A_AppData "\.QuickServer"
global                   Temp := A_Temp . "\.QuickServer"
global Enable_CheckForUpdates := true
				   defaultRAM := "1.5GB"
global                  debug := false
}

{ ;--------------------------------  AUTORUN ----------------------------------

{ ;AutoExec section
SetBatchLines, -1
#NoTrayIcon
#NoEnv
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
FileCreateDir, %Temp%

global ServerList
global SelectedUniquename
global ngrok := new NgrokHandler

try {
	menu, tray, icon, QuickServer.ico
}

If Enable_CheckForUpdates {
	(new UpdateManager).Check()
	
	if not InStr(FileExist(DefaultDir . "\BuildTools"), "D") {
		inf := UpdateServer("latest")
		FileCreateDir, Installations
		If inf.confirmed
			FileCopy, % inf.uniquename, % "Installations\" . inf.version . ".jar"
	}
}


OnExit("ExitFunc")


BuildServerWindow()
SetBatchLines, 20ms
ngrok.run()
ConnectionsWindow.Refresh()

return
}


class UpdateManager {
	Finished := false
	TimeOut := false
	Check() {
		this.req := ComObjCreate("Msxml2.XMLHTTP")
		this.req.open("GET", "https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/build.txt", true)
		this.req.onreadystatechange := UpdateManager.ReadyState.Bind(this)
		this.req.Send()
		loop, 30
		{
			sleep, 200
			If this.finished {
				break
			}
		}
		this.TimeOut := true
	}
	ReadyState() {
		if (this.req.readyState != 4)  ; Not done yet.
			return
		if (this.req.status == 200) {
			this.Finished := true
			this.latestbuild := StrReplace(StrReplace(this.req.responseText,"`n"),"`r")
			CurrentBuild := IniRead("QuickServer.ini", "version", "build", 0)
			If (this.latestbuild != CurrentBuild) {
				If this.Timeout
				{
					MsgBox, 262148, QuickServer Update, There is a newer update of QuickServer available. Would you like to install it now?
					IfMsgBox Yes
					{
						this.Update()
					}
				}
				else
				{
					this.Update()
				}
			}
		}
	}
	Update() {
		try FileDelete, QuickServer-setup.ahk
		URLDownloadToFile,https://raw.githubusercontent.com/mkzeender/QuickServerMC/master/QuickServer-setup.ahk, QuickServer-setup.ahk
		If not FileExist("QuickServer-setup.ahk") {
			fail := true
		}
		try run, QuickServer.exe QuickServer-setup.ahk
		catch
		{
			try FileCopy, %A_ScriptDir%\QuickServer.exe, QuickServer.exe
			try run, QuickServer.exe QuickServer-setup.ahk %opts%
			catch
			{
				fail := true
			}
		}
		
		If not fail {
			IniWrite, % this.LatestBuild, QuickServer.ini, version, build
			ExitApp
		}
	}
	
}

CheckPortableMode() {
	UsePortable := IniRead(A_ScriptDir . "\QuickServer.ini", "QuickServer", "EnablePortableMode", -1)
	If (UsePortable = -1) ;----prompt for installation
	{
		msgbox, 0x23, Install QuickServer, Would you like to install QuickServer? Press Yes to install. Press No to use QuickServer Portable.
		IfMsgBox Cancel
			ExitApp
		IfMsgBox No
		{
			DefaultDir := A_ScriptDir
			Enable_CheckForUpdates := false
			IniWrite(true, A_ScriptDir . "\QuickServer.ini", "QuickServer", "EnablePortableMode")
			
			If not FileExist("ngrok.exe") {
				If A_Is64bitOS {
					URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-amd64.zip, ngrok.zip
				}
				Else {
					URLDownloadToFile, https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-windows-386.zip, ngrok.zip
				}
				try runwait, tar.exe -x -f ngrok.zip,,hide
				FileDelete, ngrok.zip
			}
		}
		IfMsgBox Yes
		{
			IniWrite(false, DefaultDir . "\QuickServer.ini", "QuickServer", "EnablePortableMode")
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
	Clear_Temp_Files()
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
	global mainbtns
	mainbtns.Run.Enabled := false
	mainbtns.Settings.Enabled := false
	
	ServerList := GetServerList()
	
	Loop, % ServerList.Length()
	{
		DateFormat := GetDate(ServerList[A_Index])
		
		ListCtrl.LV_Add("",IniRead(ServerList[A_Index] . "\QuickServer.ini", "QuickServer", "name", "Untitled server"),GetDate(ServerList[A_Index],false),ServerList[A_Index],GetDate(ServerList[A_Index],true))
	}
	If (ServerList.Length() = 1) {
		ListCtrl.LV_Modify(1,"Select")
	}
	
	
}

BuildServerWindow() {
	ServerLV_Menu.Build()
	ConnectionsLV_Menu.Build()
	
	global MainGui
	MainGui := new Gui(, "QuickServer")
	MainGui.Font("s" . FontNormal)
	MainGui.Add("link",,"<a href=""https://www.gofundme.com/f/keep-quickservermc-up-to-date-with-new-features?utm_source=customer&utm_medium=copy_link&utm_campaign=p_cf+share-flow-1"">Donate Now</a>")
	
	LV_width := FontNormal * 50
	Listctrl := MainGui.add("ListView", "altsubmit R15 w" . LV_width . " -Multi", "World|DateFormat|Uniquename|Date Modified")

	Listctrl.LV_ModifyCol(1, FontNormal * 30)
	Listctrl.LV_ModifyCol(1, "Sort")
	Listctrl.LV_ModifyCol(2, 0)
	Listctrl.LV_ModifyCol(3, 0)
	Listctrl.LV_ModifyCol(4, "AutoHDR NoSort")
	Listctrl.OnEvent("SelectServer_ListView", "Normal")
	global MainGui_ServerListView
	MainGui_ServerListView := Listctrl
	ListCtrl.OnEvent(ServerLV_Menu.Show.Bind(ServerLV_Menu), "ContextMenu")
	
	global mainbtns := {}
	MainGui.add("text","ym")
	MainGui.Font("s" . FontLarge)
	Maingui.add("Button","w" . FontLarge * 15 , "Create New World").OnEvent("Button_Main_NewServer","Normal")
	mainbtns.Run := Maingui.add("Button","disabled w" . FontLarge * 15, "Play Selected World")
	mainbtns.Run.OnEvent("SelectServer_Run","Normal")
	mainbtns.Settings := Maingui.add("Button","disabled w" . FontLarge * 15, "Edit World")
	mainbtns.Settings.OnEvent("SelectServer_Settings","Normal")
	Maingui.add("Button","w" . FontLarge * 15, "Import...").OnEvent("SelectServer_Import","Normal")
	Maingui.add("Link",, "<a>Restore a backup</a>").OnEvent("SelectServer_Restore","Normal")
	Maingui.add("Link",, "<a>Help! Every time I try to`ncreate a new server it fails</a>").OnEvent("ReInstall","Normal")
	
	Maingui.Font("s" . FontNormal)
	ConnectionsWindow.Include(MainGui)
	
	Maingui.add("button","hidden default","Enter").OnEvent("SelectServer_Default","normal")
	MainGui.OnEvent("MainGUIGUIClose","Close")
	MainGui.OnEvent("SelectServer_DropFiles", "DropFiles")
	MainGui.show("Autosize Center")
	ChooseServerWindow()
	mainbtns.Run.Focus := true
}

Class ServerLV_Menu {
	Build() {
		funcobj := ServerLV_Menu.ChooseItem.Bind(this)
		Menu, ServerLV_Menu, Add,Play,%funcobj%
		Menu, ServerLV_Menu, Default, Play
		Menu, ServerLV_Menu, Add, Edit, %funcobj%
		Menu, ServerLV_Menu, Add
		Menu, ServerLV_Menu, Add, Backup,%funcobj%
		Menu, ServerLV_Menu, Add, Duplicate,%funcobj%
		Menu, ServerLV_Menu, Add, Delete,%funcobj%
		Menu, ServerLV_amb, Add, New World, %funcobj%
		Menu, ServerLV_amb, Add, Import World, %funcobj%
		Menu, ServerLV_amb, Add, Restore Backup, %funcobj%
	}
	Show(Event) {
		If not (Event.Control.LV_GetNext() = 0) {
			Event.Control.LV_GetText(v,Event.Control.LV_GetNext(),3)
			this.uniquename := v
			Menu, ServerLV_Menu, Show
		}
		Else {
			Menu, ServerLV_amb, Show
		}
	}
	
	ChooseItem(ItemName,ItemPos,MenuName) {
		  (ItemName = "Open")			? SelectServer_Run()
		: (ItemName = "Edit") 	        ? SelectServer_Settings()
		: (ItemName = "Duplicate")		? this.Duplicate()
		: (ItemName = "Backup")			? this.Backup()
		: (ItemName = "New World")		? Button_Main_NewServer()
		: (ItemName = "Import World") 	? SelectServer_Import()
		: (ItemName = "Restore Backup")	? SelectServer_Restore()
		: (ItemName = "Delete")			? this.Delete()
	}
	Duplicate() {
		(new Server(SelectedUniquename)).Duplicate()
	}
	Backup() {
		(new Server(SelectedUniquename)).Backup()
	}
	Delete() {
		(new Server(SelectedUniquename)).Delete()
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
		UpdateChosenUniquename(Event)
	}
	Else If (Event.GuiEvent = "DoubleClick") {
		critical,off
		UpdateChosenUniquename(Event)
		SelectServer_Run(Event)
	}
	If (Event.GuiEvent == "I") and InStr(Event.Errorlevel, "S")
	{
		UpdateChosenUniquename(Event)
		return
	}

	
}
UpdateChosenUniquename(Event) {
	global SelectedUniquename
	If (found := Event.Control.LV_GetNext())
		Event.Control.LV_GetText(SelectedUniquename, found, 3)
	else
		SelectedUniquename := ""
	
	global mainbtns
	mainbtns.Run.Enabled := found
	mainbtns.Settings.Enabled := found
}

SelectServer_Default(Event := "") {
	If ConnectionsWindow.ListCtrl.Focus
	{
		ConnectionsWindow.ConnectionProps()
	}
	else
	{
		SelectServer_Run(Event)
	}
}

Button_Main_NewServer() {
	new NewServerWin
}
Button_Main_NewServer_OLD() {

	CreatedServer := new Server("Server")
	If not CreatedServer.create()
	{
		return
	}
	ChooseServerWindow()
	CreatedServer.settings()
}

SelectServer_Run(Event := "") {
	uniquename := SelectedUniquename
	if not FileExist(uniquename . "\server.properties") {
		return
	}
	SelectedServer := new Server(uniquename)
	If not SelectedServer.uniquename
		return false
	SelectedServer.Start()
}

SelectServer_Settings() {
	uniquename := SelectedUniquename
	if not FileExist(uniquename . "\server.properties") {
		return
	}
	SelectedServer := new Server(uniquename)
	If not SelectedServer.uniquename
		return false
	SelectedServer.Settings()
	return true
}

SelectServer_DropFiles(Event) {
	errlvl := (new ImportServerWin).Drop(Event)
}

SelectServer_Import(Event := "") {
	new ImportServerWin
}

SelectServer_Restore() {
	FileSelectFile, SelectedFile, 1,,Restore Server Backup, QuickServer Backups (*.zip)
	If Errorlevel
		return
	SplashTextOn,,,Importing...
	
	tmp := Temp . "\import"
	FileCreateDir, % tmp
	runwait, tar.exe -x -f "%SelectedFile%", % tmp ,hide
	NewUniquename := UniqueFolderCreate("Server")
	OriginFolder := "null"
	Loop, Files, % tmp . "\Server_*", D
	{
		OriginFolder := A_LoopFileFullPath
	}
	If not FileExist(OriginFolder . "\server.properties") {
		SplashTextOff
		throw Exception("Could not open " . SelectedFile)
	}
	CopyFilesAndFolders(OriginFolder . "\*.*", NewUniquename, true)
	FileRemoveDir, % OriginFolder, true
	SplashTextOff
	ImportedServer := new Server(NewUniquename)
	ImportedServer.name := ImportedServer.name . "--backup"
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

Class NewServerWin {
	ctrls := {}
	props := {}
	Finished := false
	DoCancel := false
	__New() {
		this.gui := g := new gui(, "Create new world")
		g.Font("s" . FontLarge)
		this.tab := g.add("Tab3",,"<--| | ")
		
		g.tab(1)
		g.add("Text",,"World Name")
		this.ctrls.NAME := g.add("Edit","w" . FontLarge * 30, "New World")
		
		g.add("Text","section","Gamemode:")
		this.ctrls.gamemode := g.add("DropDownList","w" . FontLarge * 15,"survival|creative|adventure|spectator")
		this.ctrls.gamemode.ChooseString("survival")
		
		this.ctrls.cheats := g.add("CheckBox","Check3 CheckedGray", "Allow Cheats")
		
		g.add("text","ys", "Difficulty:")
		this.ctrls.difficulty := g.add("DropDownList", "w" . FontLarge * 15, "peaceful|easy|normal|hard|hardcore|UHC")
		this.ctrls.difficulty.ChooseString("normal")
		
		g.add("Button", "xs section w" . FontLarge * 15, "Datapacks/Plugins").OnEvent(ObjBindMethod(this.tab, "Choose", 3), "normal")
		
		g.add("Button","ys w" . FontLarge * 15, "More World Options...").OnEvent(ObjBindMethod(this.tab, "Choose", 2), "Normal")
		
		
		
		
		
		g.tab(2)
		g.Font("s" . FontLarge)
		g.Add("text",, "Seed:")
		this.ctrls["level-seed"] := g.Add("Edit", "w" . FontLarge * 30)
		this.ctrls["generate-structures"] := g.Add("CheckBox","section Checked" . true . " w" . FontLarge * 15, "Generate Structures")
		g.add("Text","ys","World Type:")
		this.ctrls["level-type"] := g.add("ComboBox", "w" . FontLarge * 15,"default|flat|largeBiomes|amplified|buffet")
		this.ctrls["level-type"].ChooseString("default")
		this.ctrls["level-type"].OnEvent(ObjBindMethod(this, "Change_Level_Type"), "Normal")
		g.add("link","disabled","Customize: (generator code)")
		this.ctrls["generator-settings"] := g.add("Edit","disabled w" . FontLarge * 15, this.props["generator-settings"])
		
		
		g.tab(3)
		g.Font("s" FontNormal)
		PluginMan := new PluginsGui(g, "plugins"  ,"tmp",false)
		DatapkMan := new PluginsGui(g, "datapacks","tmp",false)
		g.Font("s" FontLarge)
		
		
		
		g.tab()
		g.add("Button","section", "Create New World").OnEvent(ObjBindMethod(this, "Create"), "Normal")
		g.add("Button", "ys", "Cancel").OnEvent(ObjBindMethod(this, "Cancel"), "Normal")
		g.OnEvent(ObjBindMethod(this, "Cancel"), "Close")
		g.show()
		While not this.Finished
		{
			sleep, 50
		}
		If this.DoCancel {
			g.Destroy()
			return ""
		}
		
		
		CreatedServer := new Server
		CreatedServer.Create()
		
		CreatedServer.difficulty := this.ctrls.difficulty.Contents
		CreatedServer.name       := this.ctrls.NAME.Contents
		
		CreatedServer.props["gamemode"]            := this.ctrls.gamemode.Contents
		CreatedServer.props["level-seed"]          := this.ctrls["level-seed"].Contents
		CreatedServer.props["generate-structures"] := String(this.ctrls["generate-structures"].Contents)
		CreatedServer.props["level-type"]          := this.ctrls["level-type"].Text
		CreatedServer.props["generator-settings"]  := this.ctrls["generator-settings"].Contents
		
		v := this.ctrls.cheats.Contents
		this.doCheats := (v = -1) ? (this.props["gamemode"] != "survival") : v
		
		g.Destroy()
		
		PluginMan.uniquename := CreatedServer.uniquename
		DatapkMan.uniquename := CreatedServer.uniquename
		PluginMan.Save()
		DatapkMan.Save()
		
		If this.doCheats
		{
			this.GetCheatsPerson(CreatedServer)
		}
			
		CreatedServer.FlushProps()
		ChooseServerWindow()
		CreatedServer.start()
	}
	GetCheatsPerson(Server) {
		cached := IniRead(DefaultDir . "\QuickServer.ini", "Cache", "CheatsUserName", "&")
		InputBox, playername, Enable Cheats, Enter your username to enable cheats:,,,,,,,, % (cached = "&") ? "" : cached
		If not playername or Errorlevel
		{
			this.doCheats := false
			return
		}
		IniWrite(playername, DefaultDir . "\QuickServer.ini", "Cache", "CheatsUserName")
		Try {
			plwn := new PlayersWindow(Server,,true)
			plwn.LoadPlayerList()
			plwn.AddPlayer(playername).OP()
			plwn.SavePlayerList()
		}
		Catch e {
			If debug
				throw e
			else
				MsgBox, 262160, Error, Could not find player
		}
		
	}
	
	Change_Level_Type() {
		v := this.ctrls["level-type"].Text
		val := (v = "default") or (v = "largeBiomes") or (v = "amplified")
		this.ctrls["generator-settings"].Enabled := not val
		this.customizetxt.Enabled := not val
	}
	Cancel(Event := "") {
		this.Finished := true
		this.DoCancel := true
	}
	Create(Event := "") {
		this.Finished := true
	}
	
	
}

Class ImportServerWin {
	static savesdir := A_AppData . "\.minecraft\saves"
	__New() {
		this.Gui := new Gui("","Import Server")
		this.Gui.font("s" . FontNormal)
		v := this.Gui.add("Text",,"Select a singleplayer world below, or drop a world folder, server folder, or .zip file here")
		this.LVctrl := this.Gui.add("ListView","-multi -hdr r10 altSubmit w" . v.w, "Folder")
		Loop, Files, % this.savesdir . "\*.*", D
		{
			this.LVctrl.LV_Add(,A_LoopFileName)
		}
		this.LVctrl.OnEvent(ObjBindMethod(this,"LVClick"), "Normal")
		this.Pathctrl := this.Gui.add("Edit", "section w" . v.w)
		
		this.Gui.add("Button","xs section w" . FontNormal * 15, "Browse for a Folder").OnEvent(ObjBindMethod(this,"Browse"), "Normal")
		this.Gui.add("Button", "ys w" . FontNormal * 15, "Browse for a zip file").OnEvent(ObjBindMethod(this, "ZipButton"), "Normal")
		this.Gui.add("Button", "xs section default w" . FontNormal * 10, "Import").OnEvent(ObjBindMethod(this, "ImportBtn"), "normal")
		this.Gui.add("Button","ys w" . FontNormal * 10, "Cancel").OnEvent(ObjBindMethod(this.Gui,"Destroy"), "normal")
		this.Gui.OnEvent(ObjBindMethod(this,"Drop"), "DropFiles")
		this.Gui.NoClose := -1
		this.Gui.show("autosize center")
	}
	
	Drop(Event) {
		this.Pathctrl.Contents := Event.FileArray[1]
	}
	
	ImportBtn(Event) {
		errlvl := this.ImportGen(this.PathCtrl.Contents)
		If errlvl
			this.Gui.Destroy()
	}
	
	ImportGen(filepath) {
		Attribs := FileExist(filepath)
		If not Attribs or not filepath
			return errlvl := 1
		IsDir := InStr(Attribs, "D")
		If IsDir and FileExist(filepath . "\level.dat")
		{
			this.Import(filepath)
		}
		Else If IsDir and FileExist(filepath . "\server.properties")
		{
			this.ImportEx(filepath)
		}
		Else {
			Loop, Files, % filepath
			{
				If (A_LoopFileExt = "zip") {
					tempFolder := Temp . "\importDropFile"
					FileRemoveDir, % tempFolder, true
					FileCreateDir, % tempFolder
					runwait, tar.exe -x -f "%filepath%", % tempFolder, hide
					
					If FileExist(tempFolder . "\level.dat")
						this.Import(tempFolder)
					Else If FileExist(tempFolder . "\server.properties")
						this.ImportEx(tempFolder)
					Else {
						Loop, Files, % tempFolder . "\*.*", D
						{
							If FileExist(A_LoopFilePath . "\level.dat") {
								this.Import(A_LoopFilePath)
								break
							}
							Else If FileExist(A_LoopFilePath . "\server.properties") {
								this.ImportEx(A_LoopFilePath)
								break
							}
							Else
							{
								ErrLvl += 1
							}
						}
					}
					FileRemoveDir, % tempFolder, true
				}
				Else {
					ErrLvl += 1
				}
				break
			}
		}
		If ErrLvl
			MsgBox, 16, Import World, Import failed
	}
	
	LVClick(Event) {
		If not (s := this.LVctrl.LV_GetNext()) {
			Event.NoClose := true
			return
		}
		this.LVctrl.LV_GetText(worldname,s)
		worldpath := this.savesdir . "\" . worldname
		If (Event.GuiEvent = "DoubleClick") {
			this.ImportGen(worldpath)
		}
		else {
			this.Pathctrl.Contents := worldpath
		}
	}
	Browse(Event) {
		r := SelectFolderEx(A_AppData . "\.Minecraft\saves", "Import World",, "Select Folder"
			,,,, A_AppData . "\.Minecraft\saves")
		If r.SelectedDir
			this.Pathctrl.Contents := r.SelectedDir
	}
	
	Import(WorldFolder) {
		If not FileExist(Worldfolder . "\Level.dat")
			throw Exception("Invalid World Folder",-1)
		this.gui.Destroy()
		CreatedServer := new Server("Server")
		name := "Imported World"
		Loop, Files, % WorldFolder, D
			name := A_LoopFileName
		
		If not CreatedServer.Create(name)
			return
		
		uniquename := CreatedServer.uniquename
		FileCreateDir, %uniquename%\world
		If CopyFilesAndFolders(Worldfolder . "\*.*",uniquename . "\world")
			msgbox, 48,Import World,Some world data could not be imported
		Try
			FileMove, % uniquename . "\world\icon.png", % uniquename . "\server-icon.png"
			
		ChooseServerWindow()
		CreatedServer.Settings()
		return
	}
	
	ZipButton(Event) {
		FileSelectFile, ZipFile,,,Import a world or server in a zip file, Zip archives (*.zip)
		If ErrorLevel
			return
		this.Pathctrl.Contents := ZipFile
	}
	ImportEx(WorldFolder) {
		If not FileExist(Worldfolder . "\server.properties")
			throw Exception("Invalid World Folder",-1)
		CreatedServer := new Server("Server")
		If not CreatedServer.Create("Imported Server")
			return
		
		uniquename := CreatedServer.uniquename
		If CopyFilesAndFolders(Worldfolder . "\*.*",uniquename, true)
			msgbox, 48,Import World,Some world data could not be imported
			
		ChooseServerWindow()
		CreatedServer.Settings()
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
		
		ConnectionsWindow.Refresh()
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
		this.tmp := Temp "\Connections"
		FileCreateDir, % this.tmp
		
		Guiobj.Add("Text","xm","Click a connection below for more info and setup`nUse Ngrok if you don't know where to start.")
		width := FontNormal * 70
		this.ListCtrl := Guiobj.Add("ListView", "w" . width . " AltSubmit Count4 Grid R4 noSortHdr", "Name|Address|Status|Connectivity")
		
		this.ListCtrl.LV_Add("","Local Computer", "LOCALHOST", "Connected", "This computer only")
		this.ListCtrl.LV_Add("","LAN","","","This WiFi network only")
		this.ListCtrl.LV_Add("","Public IP Address   ","","","Public")
		this.ListCtrl.ngroklink := this.ngrok_CheckConnection()
		this.ListCtrl.LV_Add("","Ngrok","","", "Public")
		this.ListCtrl.LV_ModifyCol(1,"AutoHdr")
		this.ListCtrl.LV_ModifyCol(2,FontNormal * 20)
		this.ListCtrl.LV_ModifyCol(3,FontNormal * 15)
		this.ListCtrl.LV_ModifyCol(4,"AutoHdr")
		this.ListCtrl.OnEvent(ConnectionsWindow.LVEvent.Bind(this))
		
		this.refreshCtrl := Guiobj.Add("Button","section Disabled","Refreshing...")
		this.refreshCtrl.OnEvent(ConnectionsWindow.Refresh.Bind(this))
		
		this.propertiesctrl := Guiobj.Add("Button","ys","Setup Connection")
		this.propertiesctrl.OnEvent(ConnectionsWindow.ConnectionProps.Bind(this),"Normal")
		this.copylinkctrl := Guiobj.Add("Button","ys","Copy Link")
		this.copylinkctrl.OnEvent(ConnectionsWindow.Copylink.Bind(this),"Normal")
		
	}
	
	Refresh() {
		this.refreshCtrl.Enabled := false
		this.refreshCtrl.Text := "Refreshing..."
		
		LANIP := !(A_IPAddress1 = "0.0.0.0") and !(A_IPAddress1 = "127.0.0.1")
		PublicIP := this.PublicIP_CheckConnection()
		If ngrok.Enable {
			ngroklink := this.ngrok_CheckConnection()
			ngrok_con := ngroklink ? "Connected" : "Not Connected"
		} else {
			ngroklink := ""
			ngrok_con := "Disabled"
		}
		
		this.ListCtrl.LV_Modify(2,"Col2"
			, A_IPAddress1
			, this.LAN_CheckConnection()   ? "Connected"
			: (A_IPAddress1 = "0.0.0.0")   ? "Not connected"
			: (A_IPAddress1 = "127.0.0.1") ? "Not connected"
			:                               "Possibly connected")
			
		this.ListCtrl.LV_Modify(3,"Col2",PublicIP,PublicIP ? "Unknown" : "Not connected")
		this.ListCtrl.LV_Modify(4,"Col2",ngroklink,ngrok_con)
		
		this.refreshCtrl.Text := "Refresh"
		this.refreshCtrl.Enabled := true
		this.ListCtrl.LV_Modify(4,"Select")
	}
	
	LVEvent(Event) {
		If (Event.EventType = "ContextMenu")
		{
			this.updateSelection()
			ConnectionsLV_Menu.Show(Event)
			return
		}
		If (Event.GuiEvent = "DoubleClick")
		{
			this.updateSelection()
			this.ConnectionProps()
		}
		If (Event.GuiEvent == "I") and InStr(Event.Errorlevel, "S") {
			this.updateSelection()
		}
	}
	
	updateSelection() {
		this.Selection := this.ListCtrl.LV_GetNext()
	}
	
	ConnectionProps() {
		If (this.selection = 1) {
			msgbox,0x40000,Local Computer,If you are playing Minecraft on this computer, you can connect to the server by using LOCALHOST as the server address.
		}
		If (this.selection = 2) {
			msgbox,0x40000,LAN,Anyone else playing on your LAN (a.k.a. your WiFi network) can connect to this address. However, you might need to mark the network as "private" (on your computer go to Settings > Network and Internet > Change Connection Properties)
		}
		If (this.selection = 3) {
			publicIp := new Gui("AlwaysOnTop","Public IP Address")
			publicIp.font("s" . FontNormal)
			publicIp.add("Link",,"<a href=""https://www.wikihow.com/Set-Up-Port-Forwarding-on-a-Router"">Setup Port Forwarding</a> to use a permanent IP address for your server (note: Minecraft uses the port 25565)`n`nOnce you have set up port forwarding`, you can optionally connect it to a permanent`ncustom address (i.e. <a>MyServerIsCool.com</a>)")
			clsbtn := publicIp.add("Button", "default", "Ok")
			publicIp.Show("autosize center")
			publicIp.Wait()
			publicIp.Destroy()
		}
		If (this.selection = 4) {
			ngrok.setup()
		}
	}
	
	CopyLink() {
		this.ListCtrl.LV_GetText(v, this.Selection, 2)
		Clipboard := v
	}
	
	
	
	LAN_CheckConnection() {
		If (A_IPAddress1 = "0.0.0.0")
			return ""
		tmp := this.tmp
		runwait,cmd.exe /c powershell Get-NetConnectionProfile > "%tmp%\LAN_CheckConnection.txt",,hide
		try FileRead, landata, %tmp%\LAN_CheckConnection.txt
		If not landata
			return ""
			
		Loop, Parse, landata, `n,`r%A_Space%%A_Tab%
		{
			sep := InStr(A_LoopField, ":")
			If (Trim(SubStr(A_LoopField,1,sep-1),"`r`n" . A_Space . A_Tab) = "NetworkCategory") {
				return (Trim(SubStr(A_LoopField,sep+1),"`r`n" . A_Space . A_Tab) = "private") ? A_IPAddress1 : "" ;false returns empty
			}
		}
	}
	
	PublicIP_CheckConnection() {
		tmp := this.tmp
		FileDelete, %tmp%\PublicIP.tmp
		URLDownloadToFile, http://www.whatismyip.org/, %tmp%\PublicIP.tmp
		If not FileExist(tmp . "\PublicIP.tmp")
			return
		try FileRead, PublicIP, %tmp%\PublicIP.tmp
		PublicIP := SubStr(PublicIP,InStr(PublicIP, "<a href=""/my-ip-address"">"))
		PublicIP := SubStr(SubStr(PublicIP, 26, InStr(PublicIP,"</a>") - 26),1,25)
		return PublicIP
	}
	
	ngrok_CheckConnection() {
		tmp := this.tmp
		FileDelete, %tmp%\ngrok_CheckConnection.json
		URLDownloadToFile, http://localhost:4040/api/tunnels/, %tmp%\ngrok_CheckConnection.json
		try FileRead, jsondata, %tmp%\ngrok_CheckConnection.json
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


Class ConnectionsLV_Menu {
	Build() {
		funcobj := ConnectionsLV_Menu.ChooseItem.Bind(this)
		Menu, PluginsLV, Add, Connection Properties, %funcobj%
		Menu, PluginsLV, Default, Connection Properties
		Menu, PluginsLV, Add, Copy Link, %funcobj%
	}
	Show(Event) {
		Menu, PluginsLV, Show
	}
	ChooseItem(ItemName,ItemPos,MenuName) {
		 (ItemName = "Connection Properties") ? ConnectionsWindow.ConnectionProps()
		:(ItemName = "Copy Link") ? ConnectionsWindow.CopyLink()
	}
	
}
}

class Server { ;---------------------Server-----------------------------------------------
    ;------Properties
	
	name[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "name", "Untitled Server")
		}
		set {
			IniWrite, % value, % this.uniquename . "\QuickServer.ini", QuickServer, name
		}
	}
	NiceName[] {
		get {
			txt := ""
			For index, char in StrSplit(this.Name)
			{
				txt .= InStr("abcdefghijklmnopqrstuvwxyz0123456789 _-'.!", char) ? char : ""
			}
			return txt
		}
	}
	version[] {
		get {
			return, IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "version", "latest") 
		}
		set {
			version := value
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
			global DefaultRam
			return IniRead(DefaultDir . "\QuickServer.ini", "QuickServer", "RAM", DefaultRam)
		}
		set {
			v := ""
			vGB := StrReplace(value, "GB")
			vMB := StrReplace(value, "MB")
			If vGB is number
			{
				v := vGB . "GB"
			}
			Else If vMB is number
			{
				v := (vMB / 1024) . "GB"
			}
			If v
				IniWrite, % v, % DefaultDir . "\QuickServer.ini", QuickServer, RAM
		}
	}
	NoGui[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "NoGui", true)
		}
		set {
			IniWrite(value, this.uniquename . "\QuickServer.ini", "QuickServer", "NoGui")
		}
	}
	BonusChest[] {
		get {
			return IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "BonusChest", false)
		}
		set {
			IniWrite(value, this.uniquename . "\QuickServer.ini", "QuickServer", "BonusChest")
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
				return "hardcore"
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
			If (value = "hardcore")
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
	Op_level[] {
		get {
		
		}
		set {
			this.props["op-permission-level"] := (value = "No Commands") ? 1
				: (value = "Singleplayer Commands") ? 2
				: (value = "Singleplayer and Multiplayer Commands") ? 3
				: (value = "All Commands") ? 4
			return 
		}
	}
	EULAAgree[] {
		get {
			If IniRead(this.uniquename . "\QuickServer.ini", "QuickServer", "EULAAgree", false)
				return true
			
			v := (new eulaWindow(this.uniquename)).IAgree
			IniWrite(v,this.uniquename . "\QuickServer.ini","QuickServer","EULAAgree")
			return v
		}
		set {
			IniWrite(v,this.uniquename . "\QuickServer.ini","QuickServer","EULAAgree")
		}
	}
	Enable_Status[] {
		get {
			return (this.props["enable-status"] = "true") ? "Online" : "Incognito"
		}
		set {
			this.props["enable-status"] := (value = "Online") ? "true" : "false"
		}
	}
	props := {}
	
	__New(uniquename := "") {
		this.uniquename := uniquename
	}
	
	
	create(name := "New World") {
		this.version := "latest"
		this.uniquename := UniqueFolderCreate("Server")
		if not this.uniquename
			throw Exception("Missing server", -1)
		this.name := name
		this.Upgrade()
		this.props_init()
		this.DateModified := A_Now
		return true
	}
	
	props_init() {
		this.LoadProps()
		this.props["enable-command-block"] := "true"
		this.props["level-name"]           := "world"
		this.props["motd"]                 := "\u00A7rMade using \u00A7b\u00A7lQuickServerMC"
		this.props["spawn-protection"]     := "0"
		this.FlushProps()
	}
	
	start(Event := "", force := false) {
		If (Event.EventType = "Normal")
		{
			this.Save(Event)
		}
		if not this.EULAAgree
			return false
		If (this.version = "latest")
			this.Upgrade()
		JarFile := DefaultDir . "\Installations\" . this.version . ".jar"
		If not FileExist(JarFile) {
			MsgBox, 0x14, % this.name, Could not find server installation. Install now?
			IfMsgBox No
				return
			this.Upgrade()
		}
		Critical
		this.about_to_run := true
		CurrentlyRunningServer()
		If IsObject(CurrentlyRunningServer()) and not force
		{
			If (CurrentlyRunningServer.uniquename != this.uniquename)
			{
				MsgBox, 16, % this.name, You are already running a server! Please close that world and then open this one.
			}
			return false
		}
		CurrentlyRunningServer(this)
		
		nogui := (!debug and this.NoGui) ? "nogui" : ""
		RAM := Round(StrReplace(this.RAM, "GB") * 1024)
		RamInit := (RAM < 512) ? RAM : (RAM / 3 > 512) ? Round(RAM / 3) : 512
		
		batch = 
		( LTrim
			:Go
			java -Xmx%RAM%M -Xms%RAMInit%M -jar "%JarFile%" %nogui% 2> errorlog.log
			echo. 
			echo. 
			echo. 
			echo Server Stopped
			echo Enter 'Start' to restart the server, 'Log' to view the server log, or 'Exit' to exit.
			:cmdLoop
			set /p doCommand=">"
			If `%doCommand`%==Start goto Go
			If `%doCommand`%==start goto Go
			If `%doCommand`%==Log notepad "logs\latest.log"
			If `%doCommand`%==log notepad "logs\latest.log"
			If `%doCommand`%==Log goto cmdLoop
			If `%doCommand`%==log goto cmdLoop
			`%doCommand`%
			goto cmdLoop
		)
		try FileDelete, % this.uniquename . "\errorlog.log"
		this.WinID := RunTer(batch, this.NiceName " - Minecraft Server " . this.version, this.uniquename)
		this.DateModified := A_Now
		(new Tutorial.Console).Show()
		this.about_to_run := false
		Critical, off
		
		sleep, 2000
		FileRead,errorlog, % this.uniquename . "\errorlog.log"
		if InStr(errorlog,"Outdated") {
			this.Stop()
			try this.Update()
			this.Start(, true)
		}
		
	}
	Stop() {
		If not this.WinID
			return
		WinClose, % "ahk_id " . this.WinID
		CurrentlyRunningServer("")
	}
	
	IsRunning[] {
		get {
			If this.about_to_run
				return true
			
			return WinExist("ahk_id " . this.WinID)
		}
		set {
		}
	}
	
	Ctrls := {}
	Ctrlprop := {}
	
	Settings() { ;  ------------------Settings---------------
		this.LoadProps()
		{ ; <Setup>
			Lgui := new Gui(,"Server Properties")
			this.SettingsWin := Lgui
			Lgui.OnEvent(Server.Save.Bind(this),"Close")
			Lgui.OnEvent(Server.SettingModify.Bind(this),"Normal")
			Lgui.font("s" . FontLarge)
			this.ctrlprop["name"] := Lgui.add("Edit","w" . FontNormal * 70,this.name)
			Lgui.font("s" . FontNormal)
			
			tab := Lgui.Add("Tab3","Choose1"
				, "File|Status|Gameplay|Plugins/Datapacks|Resource Pack|Security|Players|Performance")
			tab.OnEvent(Server.TabChange.Bind(this))
			tabct := 0
		}
		
		{ ; General
		Lgui.Tab(++tabct)
			Lgui.add("Button", "section w" . FontNormal * 15, "Start Server!").OnEvent(Server.Start.Bind(this))
			
			Lgui.add("text","xs", "`nCurrent version: " . this.version . "`nPress the Update button below to update the current version to the latest build`n(i.e. if the server says it is out of date)")
			v := Lgui.add("Button","xs section w" . FontNormal * 15, "Update")
			v.OnEvent(Server.Update.Bind(this))
			v.Enabled := (this.version = "latest") or InstallationsWin.IsValidVersion(this.version)
			
			Lgui.add("Button","ys w" . FontNormal * 15, "Change Version").OnEvent(Server.Upgrade.Bind(this))
			Lgui.add("text","xs"," ")
			
			
			
			Lgui.add("Button","xs section w" . FontNormal * 15, "Backup").OnEvent(Server.Backup.Bind(this))
			Lgui.add("Button","ys w" . FontNormal * 15, "Duplicate").OnEvent(Server.Duplicate.Bind(this))
			Lgui.add("Button","ys w" . FontNormal * 15, "Delete server").OnEvent(Server.Delete.Bind(this))
			Lgui.add("text","xs section","`n")
		}
		
		{ ; Status
			Lgui.Tab(++tabct)
			this.ctrlprop["Enable_Status"] := Lgui.Add("ListBox","section r2","Online|Incognito")
			this.ctrlprop["Enable_Status"].ChooseString(this.Enable_Status)
			Lgui.add("text","ys","Status")
			
			
			Lgui.add("text",,"`n""Message of the Day"" (MOTD)")
			this.motdmaker := new motdmaker(Lgui,this.uniquename,this.props["motd"])
			this.ctrls["motd"] := this.motdmaker.motd
			
			this.ctrlprop["Enable_Status"].OnEvent(this.motdmaker.ChangeStatus.Bind(this.motdmaker,this.ctrlprop["Enable_Status"]),"Normal")
			this.motdmaker.ChangeStatus(this.ctrlprop["Enable_Status"])
		}
		
		{ ; Gameplay
		Lgui.tab(++tabct)
						
			this.ctrls["gamemode"] := Lgui.add("DropDownList","section", "survival|creative|adventure|spectator")
			Lgui.add("text","ys", "Default Gamemode")
			this.ctrls["gamemode"].ChooseString(this.props["gamemode"])
			
			this.Add_CheckBox("force-gamemode","Force Gamemode (players' gamemodes reset to default when they rejoin)")
			
			this.ctrlprop["difficulty"] := Lgui.add("DropDownList", "xs section", "peaceful|easy|normal|hard|hardcore|UHC")
			Lgui.add("text"," ys", "Difficulty")
			this.ctrlprop["difficulty"].ChooseString(this.difficulty)
					
			this.ctrls["pvp"] := Lgui.add("CheckBox","xs Checked" . Bool(this.props["pvp"]), "Allow PVP (player vs player)")
			this.ctrls["pvp"].IsBool := true
			
			Lgui.add("text","xs"," ")
			
			
			
			this.ctrls["spawn-monsters"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-monsters"])
				, "Automatically Spawn Monsters")
			this.ctrls["spawn-monsters"].IsBool := true
			
			this.ctrls["spawn-npcs"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-npcs"])
				, "Automatically Spawn NPCs (Villagers)")
			this.ctrls["spawn-npcs"].IsBool := true
			
			this.ctrls["spawn-animals"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["spawn-animals"])
				, "Automatically Spawn Animals")
			this.ctrls["spawn-animals"].IsBool := true
			
			this.ctrls["generate-structures"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["generate-structures"])
				, "Generate Structures (in new chunks)")
			this.ctrls["generate-structures"].IsBool := true
		}
		
		
		{ ; Plugins and Datapacks
		Lgui.tab(++tabct)
			Lgui.add("text",, "Easily import Spigot Plugins and datapacks!")
			Lgui.Add("Link",,"You can find plugins at <a href=""https://www.spigotmc.org/resources/categories/spigot.4/?order=download_count""> www.spigotmc.org </a>`nOnce you have downloaded a plugin, click Import Plugins.`nIt is recommended that you backup your server before using plugins.")
			Lgui.add("Button",, "Backup").OnEvent(Server.Backup.Bind(this))
			
			this.PlGui_Plugins   := new PluginsGUI(Lgui, "Plugins", this.uniquename,false)
			this.PlGui_Datapacks := new PluginsGUI(Lgui, "Datapacks", this.uniquename,true)
			this.PlGui_Plugins.OnEdit   := ObjBindMethod(this, "SettingModify")
			this.PlGui_Datapacks.OnEdit := ObjBindMethod(this, "SettingModify")
		}
		{ ; Resource packs
		Lgui.tab(++tabct)
			Lgui.add("text","section","Include a resource pack (texture pack) in this server`n`nPaste a valid downloadable link to a resource/texture pack")
			this.ctrls["resource-pack"] := Lgui.Add("Edit","xs section w" . FontNormal * 60, this.props["resource-pack"])
			Lgui.add("text","xs"," ")
			
			this.Add_Edit("resource-pack-sha1","SHA-1 -- Paste the file's SHA-1 hash here")
			
			this.Add_CheckBox("require-resource-pack","Require resource pack (Players will be kicked if they refuse the resource pack)")
			
			Lgui.add("Link","xs section","`nTry this link for help:`n<a href=""https://nodecraft.com/support/games/minecraft/adding-a-resource-pack-to-a-minecraft-server"">https://nodecraft.com/support/games/minecraft/adding-a-resource-pack-to-a-minecraft-server</a>")
			
		
		}
		
		{ ; Security
			Lgui.Tab(++tabct)
			
			Lgui.add("Edit","section")
			this.ctrls["max-players"] := Lgui.add("UpDown",, this.props["max-players"])
			Lgui.add("text"," ys", "Maximum players")
			
			this.Add_CheckBox("white-list","Private (Use the /whitelist command to grant people access)")
			
			this.Add_UpDown("op-permission-level","Default Operator Level","Range1-4")
			txt = 
				( LTrim
				Use the /op command to make players operators
				Level 1 OPs can only bypass grief-protection
				Level 2 OPs	can use singleplayer commands, such as /tp, /give, and /kill
				Level 3 OPs can also use multiplayer commands, such as /whitelist, /ban, and /op
				Level 4 OPs can use all commands, including /stop and /save[on/off/all]
				See the "players" menu to view the OPs
				
				)
			Lgui.add("text","xs section", txt)
				
			
			tmp := Lgui.add("Edit","xs section")
			TruWidth := tmp.w
			this.ctrls["spawn-protection"] := Lgui.add("UpDown", , this.props["spawn-protection"])
			Lgui.add("text","ys", "Spawn Grief-Protection Radius")
			
			
			this.Add_CheckBox("online-mode","Check Player ID (players may not be in ""offline mode"")")
			this.Add_CheckBox("allow-flight","Permit Flight-Hacks (otherwise, illegally flying players are kicked)")
			
			this.ctrls["allow-nether"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["allow-nether"]), "Enable Nether Portals")
			this.ctrls["allow-nether"].IsBool := true
			
			this.ctrls["enable-command-block"] := Lgui.add("CheckBox", "xs Checked" . Bool(this.props["enable-command-block"])
				, "Allow Command Blocks")
			this.ctrls["enable-command-block"].IsBool := true
			
		}
		
		{ ; Players
			Lgui.Tab(++tabct)
			this.PlayersWin := (new PlayersWindow(this, Lgui))
		}
		
		{ ; Performance
			Lgui.tab(++tabct)
			ww := this.ctrls["spawn-protection"].w
			hh := this.ctrls["spawn-protection"].h
			
			tme := this.ctrlprop["RAM"] := Lgui.add("Edit","section w" TruWidth - ww, this.RAM)
			tmu := this.RAM_Ctrl_UpDown := Lgui.add("UpDown"
				,"-16 x" . tme.x + tme.w . " y" . tme.y . " w" . ww . " h" . hh)
				
			tme.OnEvent(ObjBindMethod(this, "RAM_Ctrl_Get", false),"normal")
			tmu.OnEvent(ObjBindMethod(this, "RAM_Ctrl_Get", true), "Normal")
			this.RAM_Ctrl_Get(,,false)
			
			Lgui.add("text","ys", "Maximum Server RAM (applies to all worlds)")
			
			this.ctrlprop["NoGui"] := Lgui.add("CheckBox","xs section Checked" . this.NoGui
				, "Hide Server Window (may improve performance)")
			
			this.Add_UpDown("view-distance", "Render Distance","Range3-32")
			
			this.Add_UpDown("entity-broadcast-range-percentage","Entity render distance (percentage)", "Range0-500")
			
			this.Add_UpDown("player-idle-timeout","AFK limit (kicks anyone who is away for __ minutes; 0 = disabled)")
			
			this.Add_UpDown("max-world-size","World Size (radius, in blocks)", "Range1-29999984")
			this.Add_UpDown("max-build-height", "World Height (in blocks)", "Range1-256")
		}
		
		{ ; <post>
			Lgui.tab()
			Lgui.Add("Button","section default w" . FontNormal * 10,"OK").OnEvent(Server.Save.Bind(this),"Normal")
			Lgui.add("Button", "ys w" . FontNormal * 10, "Cancel").OnEvent(Server.ReloadSettings.Bind(this))
			this.applybtn := Lgui.add("Button", "ys w" . FontNormal * 10,"Apply")
			this.applybtn.OnEvent(Server.Apply.Bind(this),"Normal")
			
			
			Lgui.add("Link", "ys", "<a>Advanced Settings</a>`n").OnEvent(Server.s_Advanced.Bind(this))
			Lgui.add("Link", "ys", "<a> Open the Server Folder </a>").OnEvent(Server.s_OpenFolder.Bind(this))
			sleep, -1
			this.applybtn.Enabled := false
			Lgui.show("Autosize Center")
		}
	}
	
	RAM_Ctrl_Get(UpDnToEdit := false, Event := "", doFocus := true) {
		Edt := this.ctrlprop["RAM"]
		Updn := this.RAM_Ctrl_UpDown
		If UpDnToEdit {
			Edt.Contents := v := Format("{1:.4}",Updn.Contents / 10) . "GB"
		}
		Else If !doFocus or Edt.Focus {
			vGB := StrReplace(Edt.Contents, "GB")
			vMB := StrReplace(Edt.Contents, "MB")
			If vGB is number
			{
				UpDn.Contents := v := Round(vGB * 10)
			}
			Else If vMB is number
			{
				UpDn.Contents := v := Round(vMB / 102.4)
			}
		}
		return v
	}
	SettingModify(Event := "") {
		If not Event or (InStr("Edit|CheckBox|UpDown|DropDownList|ListBox",Event.Control.Type) and (Event.Control.Type != ""))
		{
			this.applybtn.Enabled := true
		}
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
	Apply(Event := "") {
		this.applybtn.Enabled := false
		this.BegForMoney()
		this.FlushProps()
		this.PlayersWin.SavePlayerList()
		this.DateModified := A_Now
		this.PlGui_Plugins.Save()
		this.PlGui_Datapacks.Save()
		
		ChooseServerWindow()
		
		If (CurrentlyRunningServer().Uniquename = this.uniquename) {
			MsgBox, 262208, Server Properties, Use the /reload command or restart the server to apply changes, 10
		}
	}
	Save(Event := "") {
		this.Apply(Event)
		this.ReloadSettings()
	}
	
	ReloadSettings() {
		this.SettingsWin.Destroy()
		this.PlayersWin := ""  ;releases object
	}
	
	
	Upgrade(Event := "") {
		
		UpdateResult := new InstallationsWin(this.Version)
		if UpdateResult.Canceled
		{
			return
		}
		if not UpdateResult.confirmed {
			DownloadFailed(this)
			return
		}
		else {
			this.Version := UpdateResult.version
			this.JarFile := UpdateResult.uniquename
			this.UseLatest := UpdateResult.IsLatest
		}
		If (Event.EventType = "Normal") {
			this.Save()
			this.Settings()
		}
	}
	Update(Event := "") {
		UpdateResult := UpdateServer(this.version)
		if not UpdateResult.confirmed {
			throw Exception("Update Failed")
			return
		}
		this.version := (this.version = "latest") ? UpdateResult.version : this.version
		FileCreateDir, Installations
		FileCopy, % UpdateResult.uniquename, % DefaultDir . "\Installations\" . this.version . ".jar", true
	}
	Backup() {
		backup_folder := this.nicename
		FileSelectFile, v, S16, %backup_folder%.zip, Save Backup, Zip Archives (*.zip)
		If ErrorLevel
			return
		Loop, Files, % v
		{
			If !(A_LoopFileExt = "zip")
				v .= ".zip"
			break
		}
		
		Run, tar -a -c -f "%v%" "%backup_folder%",,hide
		
	}
	
	
	Duplicate() {
		CreatedServer := new Server
		CreatedServer.uniquename := UniqueFolderCreate("Server")
		SplashTextOn,,,Copying Server...
		CopyFilesAndFolders(this.uniquename . "\*.*", CreatedServer.uniquename, true)
		SplashTextOff
		CreatedServer.name := this.name . " (Copy)"
		CreatedServer.DateModified := A_Now
		ChooseServerWindow()
		CreatedServer.Settings()
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
	
	OpenFile(filename, Event) {
		run, % "notepad.exe """ . this.uniquename . "\" . filename . """",,max
	}

	Add_CheckBox(key,label) {
		this.ctrls[key] := this.SettingsWin.add("CheckBox", "xs section Checked" . Bool(this.props[key]), label)
		this.ctrls[key].IsBool := true
	}
	Add_Edit(key,label) {
		this.ctrls[key] := this.SettingsWin.add("Edit","xs section",this.props[key])
		this.SettingsWin.add("text","ys", label)
	}
	Add_UpDown(key,label,opts := "") {
		this.SettingsWin.add("Edit","xs section")
		this.ctrls[key] := this.SettingsWin.add("UpDown",opts, this.props[key])
		this.SettingsWin.add("text","ys", label)
	}
	
	BegForMoney() {
		n := this.ctrls["max-players"].Contents
		If (n > 8) and (n > this.props["max-players"])
			(new Tutorial.Donate).Show()
	}
}

CurrentlyRunningServer(server := "") {
	static curr_server := ""
	curr_server := server.IsRunning ? server : curr_server.IsRunning ? curr_server : ""
	
	return curr_server
}

class InstallationsWin {
	__New(currentversion := "latest") {
		this.currentversion := currentversion
		this.gui := new Gui("AlwaysOnTop", "Installations")
		this.gui.Font("s" . FontNormal)
		this.gui.add("Text",,"Enter the desired version (example: 1.16.4).`nType ""latest"" to use the latest version.`n")
		
		v := this.gui.add("Link",
		,"You can also download and import a modded server (i.e., Forge or Paper).`n<a>Click here to import installation</a>")
		v.OnEvent(ObjBindMethod(this, "ImportBtn"), "Normal")
		
		this.versctrl := this.gui.add("ComboBox","w" . FontNormal * 20, "latest|" . this.GetVersions(true))
		this.versctrl.Text := this.currentversion
		this.versctrl.focus := true
		
		this.gui.add("Button","default section w" . FontNormal * 10, "OK").OnEvent(ObjBindMethod(this, "OKbtn"), "Normal")
		this.gui.add("Button","ys w" . FontNormal * 10, "Cancel").OnEvent(ObjBindMethod(this, "CancelBtn"), "Normal")
		
		this.gui.NoClose := true
		this.gui.OnEvent(ObjBindMethod(this, "CancelBtn"), "Close")
		this.gui.OnEvent(ObjBindMethod(this, "Drop"), "DropFiles")
		this.waiting := true
		this.gui.Show()
		Critical, off
		While (this.waiting = true)
		{
			sleep, 50
		}
		If this.Canceled {
			this.Confirmed := false
			this.gui.Destroy()
			return this
		}
		newversionraw := this.versctrl.Text
		newversion := StrReplace(newversionraw, A_Space)
		this.gui.Destroy()
		
		If !(newversion = "latest") and FileExist(DefaultDir . "\Installations\" . newversionraw . ".jar") {
			this.JarFile := "\Installations\" . newversionraw . ".jar"
			this.Version := newversionraw
			this.Confirmed := true
		}
		Else If !(newversion = "latest") and FileExist(DefaultDir . "\Installations\" . newversion . ".jar") {
			this.JarFile := "\Installations\" . newversion . ".jar"
			this.Version := newversion
			this.Confirmed := true
		}
		Else If (newversion = "latest") or this.IsValidVersion(newversion) {
			UpdateResult := UpdateServer(newversion)
			this.confirmed := UpdateResult.confirmed
			this.Version := UpdateResult.version
			PreJarFile := UpdateResult.uniquename
			this.UseLatest := UpdateResult.IsLatest
			If not this.confirmed
				return this
			
			FileCreateDir, Installations
			FileCopy, % PreJarFile, % "Installations\" this.Version . ".jar", true
			this.JarFile := "Installations\" this.Version . ".jar"
		}
		else
		{
			this.confirmed := false
		}
		return this
	}
	IsValidVersion(ver) {
		If not (InStr(ver, "1.") = 1)
			return false
		subver := SubStr(ver, 3)
		If subver is number
			return true
		else
			return false
	}
	OKBtn(Event) {
		this.Waiting := false
		this.Canceled := false
	}
	CancelBtn(Event) {
		this.Waiting := false
		this.Canceled := true
	}
	Drop(Event) {
		If not Event.FileArray[1]
			return
		
		this.Import(Event.FileArray[1])
	}
	ImportBtn(Event) {
		FileSelectFile,file,,,Import an installation of Minecraft Server, Java Executables (*.jar)
		If Errorlevel
			return
		this.Import(File)
	}
	Import(File) {
		Loop, Files, % File
		{
			If not (A_LoopFileExt = "jar")
				continue
			
			version := SubStr(A_loopFileName, 1, StrLen(A_LoopFileName) - 4)
			FileCopy, % A_LoopFilePath, % DefaultDir . "\Installations\" . A_LoopFileName
			this.versctrl.Contents := version
			this.versctrl.Text := version
		}
	}
	
	GetVersions(parse := false) {
		list := []
		parselist := ""
		Loop, Files, % DefaultDir . "\Installations\*.jar"
		{
			name := SubStr(A_LoopFileName, 1,StrLen(A_LoopFileName) - 4)
			list.Push(name)
			parselist .= (A_Index = 1) ? name : "|" . name
		}
		return parse ? parselist : list
	}
}

class PlayersWindow { ;--------------Players Window
	__New(server, inclgui := "", NoRender := false) {
		this.server := server
		this.IsEmbedded := IsObject(inclgui)
		this.gui := NoRender ? "" : this.IsEmbedded ? inclgui : new Gui
		void := NoRender ? "" : this.Init()
	}
	Init() {
		g := this.gui
		
		this.LV := g.add("ListView","altsubmit grid r10 w" . FontNormal * 65
			,"Name|Clearance|More Info|User ID")
		this.LV.LV_ModifyCol(1, FontNormal * 15)
		this.LV.LV_ModifyCol(2, FontNormal * 15)
		this.LV.LV_ModifyCol(3, FontNormal * 20)
		this.LV.OnEvent(ObjBindMethod(this,"LV_EditPlayer"),"Normal")
		
		g.add("Button","section", "Add Player ").OnEvent(ObjBindMethod(this,"LV_AddPlayer"), "Normal")
		g.add("Button","ys", "Edit Player").OnEvent(ObjBindMethod(this,"LV_EditPlayer"), "Normal")
		
		this.LoadPlayerList()
		this.LV_Refresh()
		this.server.ctrls["white-list"].OnEvent(ObjBindMethod(this, "LV_Refresh"), "Normal")
	}
	
	LV_AddPlayer(Event := "") {
		InputBox, plName, Add Player, Username:
		If ErrorLevel
			return
		player := this.AddPlayer(plName)
		this.LV_Refresh()
		player.EditWindow()
	}
	AddPlayer(plName) {
		UUID := this.GetUUID(plName)
		player := this.GetPlayer(UUID)
		If (player = "")
		{
			try
				name := this.GetName(UUID)
			catch
				name := plName
			this.raw.users.Push({name : name, uuid : UUID})
			return new this.Player(UUID, this)
			
		}
	}
	LV_EditPlayer(Event) {
		If (Event.GuiEvent = "Normal" or Event.GuiEvent = "RightClick") and (v := this.LV.LV_GetNext())
		{
			this.LV.LV_GetText(uuid, v, 4)
			this.GetPlayer(uuid).EditWindow()
		}
	}
	LV_Refresh() {
		this.LV.LV_Delete()
		For index, p in this.GetPlayerList()
		{
			stat := p.GetStatus()
			this.LV.LV_Add(,p.name, stat.Clear, stat.Inf, p.UUID)
		}
		
		If not This.IsEmbedded
		{
			this.gui.add("Button","w" . FontNormal * 10,"Save").OnEvent(ObjBindMethod(this,"SavePlayerList"), "Normal")
			this.gui.NoClose := -1
			this.gui.Show()
		}
	}
	GetPlayer(uuid) {
		For index, player in this.raw.users
		{
			If (uuid = player.uuid)
				return new this.player(player.uuid, this)
		}
	}
	GetPlayerList() {
		l := []
		For index, playerr in this.raw.users
		{
			l.Push(new this.player(playerr.uuid, this))
		}
		return l
	}
	LoadPlayerList() {
		this.raw := {}
		this.raw.ForceWhiteList := Bool(this.server.props["white-list"])
		this.raw.uniquename := this.Server.uniquename
		
		try
			FileRead, plistjsn, % DefaultDir "\" this.Server.uniquename "\usercache.json"
		catch
			plistjsn := "[]"
		this.raw.usercache := JSON.Load(plistjsn)
		try 
			FileRead, banlistjsn, % DefaultDir "\" this.Server.uniquename "\banned-players.json"
		catch
			banlistjsn := "[]"
		this.raw.Banned_Players := JSON.Load(banlistjsn)
		try
			FileRead, whitelistjsn, % DefaultDir "\" this.Server.uniquename "\whitelist.json"
		catch
			whitelistjsn := "[]"
		This.raw.WhiteList := JSON.Load(whitelistjsn)
		
		try
			FileRead, opsjsn, % DefaultDir "\" this.Server.uniquename "\ops.json"
		catch
			opsjsn := "[]"
		this.raw.Ops := JSON.Load(opsjsn)
		
		try
			FileRead, addedjsn, % DefaultDir "\" this.Server.uniquename "\QS_Player_List.json"
		catch
			addedjsn := "[]"
		this.raw.users := JSON.Load(addedjsn)
		
		For indexa, playercache in this.raw.usercache
		{
			addToList := true
			For indexb, player in this.raw.users
			{
				If (player.uuid = playercache.uuid)
				{
					player.name := playercache.name
					addToList := false
				}
			}
			If addToList {
				this.raw.users.Push({uuid : playercache.uuid, name : playercache.name})
			}
		}
	}
	SavePlayerList(Event := "") {
		FileMove, % DefaultDir "\" this.Server.uniquename "\QS_Player_List.json", % DefaultDir "\" this.Server.uniquename "\*.json_old", true
		FileAppend, % JSON.Dump(this.raw.users,,4), % DefaultDir "\" this.Server.uniquename "\QS_Player_List.json"
		FileMove, % DefaultDir "\" this.Server.uniquename "\banned-players.json", % DefaultDir "\" this.Server.uniquename "\*.json_old", true
		FileAppend, % JSON.Dump(this.raw.Banned_Players,,4), % DefaultDir "\" this.Server.uniquename "\banned-players.json"
		FileMove, % DefaultDir "\" this.Server.uniquename "\whitelist.json", % DefaultDir "\" this.Server.uniquename "\*.json_old", true
		FileAppend, % JSON.Dump(this.raw.WhiteList,,4), % DefaultDir "\" this.Server.uniquename "\whitelist.json"
		FileMove, % DefaultDir "\" this.Server.uniquename "\ops.json", % DefaultDir "\" this.Server.uniquename "\*.json_old", true
		FileAppend, % JSON.Dump(this.raw.Ops,ObjBindMethod(this,"JSONMakeBoolean"),4), % DefaultDir "\" this.Server.uniquename "\ops.json"
		
		
		If not this.IsEmbedded and (Event.EventType = "Normal")
		{
			this.gui.Destroy()
		}
	}
	GetUUID(name) {
		uuid := ""
		For index, player in this.GetPlayerList()
		{
			If (name = player.name)
			{
				UUID := player.uuid
			}
		}
		If (UUID = "") {
			tmp := Temp . "\UUIDDownload.tmp"
			try FileDelete, % tmp
			URLDownloadToFile, % "https://minecraft-techworld.com/admin/api/uuid?action=uuid&username=" . name, % tmp
			
			FileRead, temptxt, % tmp
			jsn := SubStr(temptxt, v := InStr(temptxt, "{"), InStr(temptxt, "}",,-1) - v)
			try
				inf := JSON.Load(jsn)
			catch ex
				throw Exception("Could not find user. Make sure you are connected to the internet",,ex.Message)
			If not inf.success
				throw Exception(inf.error ? inf.error : "Could not find user.")
			uuid := inf.output
		}
		return uuid
	}
	GetName(UUID) {
		name := ""
		For index, player in this.GetPlayerList()
		{
			If (UUID = player.UUID)
			{
				name := player.name
				break
			}
		}
		
		If (name = "") {
			tmp := Temp . "\UsernameDownload.tmp"
			FileDelete, % tmp
			URLDownloadToFile, % "https://minecraft-techworld.com/admin/api/uuid?action=username&uuid=" . UUID, % tmp
			
			FileRead, temptxt, % tmp
			jsn := SubStr(temptxt, v := InStr(temptxt, "{"), InStr(temptxt, "}",,-1) - v)
			inf := JSON.Load(jsn)
			If not inf.success
				throw Exception(inf.error)
			name := inf.output
		}
		return name
	}
	
	JSONMakeBoolean(obj, key, value, inf) {
		If !(key = "bypassesPlayerLimit")
			return value
		inf.DoRaw := true
		return value ? "true" : "false"
	}
	class Player {
		__New(UUID, parent) {
			this.UUID := UUID
			this.raw := parent.Raw
			this.parent := parent
		}
		
		EditWindow() {
			If this.WindowIsShown
				return
			this.WindowIsShown := true
			lgui := new GUI("+alwaysOnTop", this.name)
			lgui.Font("s" . FontNormal)
			
			lgui.add("Edit", "section w" . FontNormal * 15)
			v := this.OpStatus
			oplvlctrl := lgui.add("UpDown","range0-4", v ? v.level : 0)
			lgui.add("Text", "ys", "Operator Level")
			v := this.BanStats
			banctrl := lgui.add("CheckBox","xs section Checked" . IsObject(v), "Ban")
			reasonctrl := lgui.add("Edit","xs section", IsObject(v) ? v.reason : "Banned by an Operator.")
			lgui.add("text","ys","Ban Reason")
			
			wlctrl := lgui.add("Checkbox","xs section Checked" . this.IsWhiteListed, "Whitelist")
			
			lgui.add("text", "xs section", "See the security tab for more info.")
			
			lgui.add("Button", "xs section w" . FontNormal * 10, "OK").OnEvent(ObjBindMethod(this, "EW_Close", true), "Normal")
			lgui.add("Button", "ys w" . FontNormal * 10, "Cancel").OnEvent(ObjBindMethod(this, "EW_Close", false), "normal")
			lgui.add("Button", "ys w" . FontNormal * 10, "Reset Player").OnEvent(ObjBindMethod(this, "EW_Reset"), "normal")
			
			
			lgui.NoClose := true
			this.EW_DoSave := false
			lgui.OnEvent(ObjBindMethod(this, "EW_Close", false), "Close")
			lgui.show()
			Critical, off
			While this.WindowIsShown
			{
				sleep, 50
			}
			If this.EW_DoSave {
				this.Ban(not banctrl.Contents, reasonctrl.Contents)
				this.WhiteList(not wlctrl.Contents)
				this.OP(oplvlctrl.Contents = 0, oplvlctrl.Contents)
				
				this.parent.LV_Refresh()
				this.parent.server.SettingModify()
			}
			lgui.destroy()
		}
		EW_Close(doSave, Event := "") {
			this.EW_DoSave := doSave
			this.WindowIsShown := false
		}
		EW_Reset(Event := "") {
			MsgBox, 262452, Reset player, This will delete the player's items`, location`, etc. This cannot be undone. Continue?
			IfMsgBox, Yes
			{
				UN := this.parent.server.uniquename
				FileDelete, % DefaultDir . "\" . UN . "\world\advancements\" . this.uuid . ".json"
				FileDelete, % DefaultDir . "\" . UN . "\world\stats\"        . this.uuid . ".json"
				FileDelete, % DefaultDir . "\" . UN . "\world\playerdata\"   . this.uuid . ".dat"
				this.BanStats := ""
				this.IsWhiteListed := false
				this.OpStatus := ""
				
				For index, player in this.raw.users
				{
					If (this.uuid = player.uuid) {
						this.raw.users.RemoveAt(index)
						break
					}
				}
				this.parent.LV_Refresh()
				this.WindowIsShown := false
			}
		}
		
		Ban(un := false, reason := "Banned by an operator.") {
			If un {
				this.BanStats := ""
			}
			else {
				this.BanStats := {created : ""
								, expires : "forever"
								, name    : this.Name
								, reason  : reason
								, source  : "Server"
								, uuid    : this.uuid}
			}
		}
		WhiteList(un := false) {
			this.IsWhiteListed := not un
		}
		OP(un := false, level := 4, bpl := false) {
			If un
				this.OpStatus := ""
			else
				this.OpStatus := {level : level, bypassesplayerlimit : bpl}
		}
		
		GetStatus() {
			stat := []
			l_ban := this.BanStats
			If l_ban {
				stat.Clear := "Banned"
				stat.inf := l_ban.reason
				return stat
			}
			Else if this.parent.server.ctrls["white-list"].Contents and not this.IsWhiteListed {
				return {Clear : "Banned", inf : "You are not whitelisted on this server!"}
			}
			Else if (op := this.OpStatus) {
				lim := op.bypassesplayerlimit ? "Ignores Player Limit" : "Abides by Player Limit"
				return {Clear : "Level " . op.level . " Operator", inf : lim}
			}
			else
			{
				return {Clear : "Player", inf : ""}
			}
		}
		Name[] {
			get {
				For index, player in this.raw.users
				{
					If (player.uuid = this.uuid)
						return player.name
				}
			}
			set {
				
			}
		}
		BanStats[] {
			get {
				Ban := ""
				For index, banplayer in this.raw.Banned_Players
				{
					If (banplayer.uuid = this.uuid)
					{
						Ban := banplayer
						break
					}
				}
				return Ban
			}
			set {
				addToList := true
				For index, banplayer in this.raw.Banned_Players
				{
					If (banplayer.uuid = this.uuid)
					{
						addToList := false
						If value
						{
							this.raw.banned_Players[index] := value
						}
						else
						{
							this.raw.Banned_Players.RemoveAt(index)
						}
						break
					}
				}
				If addToList and value {
					this.raw.Banned_Players.Push(value)
				}
			}
		}
		IsWhiteListed[] {
			get {
				For index, player in this.raw.WhiteList
				{
					If (player.UUID = this.UUID) {
						return true
					}
				}
				return false
			}
			set {
				addToList := true
				For index, player in this.raw.WhiteList
				{
					If (player.UUID = this.UUID)
					{
						addToList := false
						If not value {
							this.raw.WhiteList.RemoveAt(index)
						}
						break
					}
				}
				If value and addToList {
					this.raw.WhiteList.Push({name : this.name, uuid : this.uuid})
				}
			}
		}
		OpStatus[] {
			get {
				For index, player in this.raw.Ops
				{
					If (player.UUID = this.UUID) {
						return {level : player.level, bypassesplayerlimit : player.bypassesplayerlimit}
					}
				}
				return ""
			}
			set {
				addToList := true
				For index, player in this.raw.OPs
				{
					If (player.UUID = this.UUID) {
						addToList := false
						If value {
							this.raw.OPs[index] := {level : value.level
								, bypassesplayerlimit : value.bypassesplayerlimit
								, name : this.name
								, uuid : this.uuid}
						}
						else {
							this.raw.OPs.RemoveAt(index)
						}
						break
					}
				}
				If addToList and value {
					this.raw.OPs.Push({level : value.level
						, bypassesplayerlimit : value.bypassesplayerlimit
						, name : this.name
						, uuid : this.uuid})
				}
			}
		}
	}
}

Class PluginsGUI { ;-----------------Plugins Window ---
	IsModified := false
	EnableList := []
	__New(Guiobj, type, uniquename,append := false) {
		this.type := type
		this.uniquename := uniquename
		this.Folder := (type = "plugins") ? "plugins" : "world\datapacks"
		this.ext := (type = "plugins") ? ".jar" : ".zip"
		
		Guiobj.Add("Button",append ? "ys" : "section","Import " . type).OnEvent(PluginsGUI.Import.Bind(this))
		this.LV := Guiobj.Add("ListView", "AltSubmit Checked R7 Sort", "Enabled " . type)
		this.LV.OnEvent(PluginsGUI.Modify.Bind(this), "Normal")
		this.LV.OnEvent(PluginsGUI.Import.Bind(this), "DropFiles")
		Loop, Files, % this.Folder . "\*" . this.ext
		{
			Options := " "
			If FileExist(this.uniquename . "\" . this.Folder . "\" . A_LoopFileName) {
				Options .= "Check"
				this.EnableList.Push(A_LoopFileName)
			}
			this.LV.LV_Add(Options, A_LoopFileName)
		}
		
	}
	
	Modify(Event) {
		critical
		If not (Event.GuiEvent == "I")
			return
		
		If Instr(Event.ErrorLevel, "C", true) {
			
			this.LV.LV_GetText(PluginName, Event.EventInfo)
			If not InArray(this.EnableList, PluginName)
				this.EnableList.Push(PluginName)
			this.IsModified := true
			this.OnEdit.Call()
		}
		Else If InStr(Event.ErrorLevel, "c", true) {
			
			this.LV.LV_GetText(PluginName, Event.EventInfo)
			If (pos := InArray(this.EnableList, PluginName))
				this.EnableList.RemoveAt(pos)
			this.IsModified := true
			this.OnEdit.Call()
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
				this.EnableList.Push(FileName)
				this.IsModified := true
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
				this.EnableList.Push(A_LoopField)
				this.IsModified := true
			}
		}
	}
	
	Save() {
		If not this.IsModified
			return
		FileCreateDir, % DefaultDir . "\" . this.uniquename . "\" . this.Folder
		Loop, Files, % DefaultDir . "\" . this.Folder . "\*.*"
		{
			file := DefaultDir . "\" . this.uniquename . "\" . this.Folder . "\" . A_LoopFileName
			Enabled := InArray(this.EnableList, A_LoopFileName)
			WasEnabled := FileExist(file)
			If Enabled and not WasEnabled
			{
				try FileCopy, % A_LoopFilePath, % file
			}
			Else If not Enabled and WasEnabled
			{
				FileDelete, % file
			}
		}
	}
}

class MotdMaker {  ;-----------------Motd Maker    ----
	__New(guiobj, uniquename, initial) {
		this.temphtml := DefaultDir . "\" . uniquename . "_MOTD.html"
		
		this.gui := guiobj
		this.editor := this.gui.add("Edit","xs section r2 +WantReturn w450")
		this.applybtn := this.gui.add("Button","xs","^^^ Apply Formatting ^^^")
		this.applybtn.OnEvent(MotdMaker.AddFormat.Bind(this),"Normal")
		this.Colrctrl := this.gui.add("DropDownList","xs section Choose9",	this.styleKeyColorName_Parse)
		this.Boldctrl := this.gui.add("CheckBox",    ,"Bold"        )
		this.Undectrl := this.gui.add("CheckBox","ys","Underlined  ")
		this.Italctrl := this.gui.add("CheckBox",    ,"Italic"      )
		this.Strictrl := this.gui.add("CheckBox","ys","Strike-thru" )
		this.Corrctrl := this.gui.add("CheckBox",    ,"Corrupted"   )
		
		this.editor.OnEvent(ObjBindMethod(this, "EditIt"), "normal")
		
		this.picturectrl := this.gui.add("picture", "xs section h64 w64", this.GetPicture(uniquename))
		xx := this.picturectrl.x + 64, xx := xx ? xx : 64
		yy := this.picturectrl.y, yy := yy ? yy : "120"
		this.renderer := this.gui.add("ActiveX","x" . xx . " y" . yy . " h64 w386","shell.Explorer").Contents
		this.gui.add("Button", "xs section", "Change Picture").OnEvent(ObjBindMethod(this, "SetPicture", uniquename), "Normal")
		this.gui.add("text","ys", "(Must be a 64x64 pixel .PNG file)")
		this.renderer.silent := true
		this.motd := {}
		this.motd.Contents := initial
		this.parseraw()
		this.render()
	}
	EditIt() {
		Critical
		this.motd.Contents := StrReplace(StrReplace("&r" . this.editor.Contents,"`n","\n&r"),"&","\u00A7")
		this.Render()
	}
	
		
	Render(Event := "", online := true) {
		If online
			linelist := StrSplit(this.motd.Contents, "\n")
		else
			linelist := ["\u00A7cCan't connect to server",""]
		Line_1 := this.ConvertToHtml(linelist[1])
		Line_2 := this.ConvertToHtml(linelist[2])
		html =
			( LTrim
				<html>
					<head>
						<style>
							@font-face {
								font-family: mcFont;
								  src: url('mcFont.eot'); /* IE9 Compat Modes */
								  src: url('mcFont.eot?#iefix') format('embedded-opentype'), /* IE6-IE8 */
									   }
						</style>
						<style>
							span.normal {
								line-height: 1.1;
							}
						</style>
					</head>
					<body style="background-image: Url('Motd_Background.jpg'); font-family: mcFont; font-size:80`%; color: DarkGray">
						<span class="normal">
							<span style="color: white">A Minecraft Server</span>
							<br>
							%Line_1%
							</br>
							%Line_2%
						</span>
					</body>
				</html>
			)
		FileDelete, % this.temphtml
		FileAppend, % html, % this.temphtml
		this.renderer.Navigate("file:///" . this.temphtml)
	}
	GetPicture(uniquename) {
		pth := DefaultDir . "\" . uniquename . "\server-icon.png"
		If FileExist(pth) {
			return pth
		}
		FileCopy, % DefaultDir . "\server-icon.png", % pth
		return pth
	}
	SetPicture(uniquename, Event := "") {
		pth := DefaultDir . "\" . uniquename . "\server-icon.png"
		FileSelectFile, newpic,,, Change Picture, 64x64 PNG files (*.png)
		If Errorlevel
			return
		
		Loop, Files, % newpic
		{
			If (A_LoopFileExt = "png") {
				FileCopy, % A_LoopFileFullPath, % pth, 1
				this.PictureCtrl.Contents := pth
				break
			}
		}
	}
	parseraw() {
		v := StrReplace(StrReplace(this.motd.Contents,"\u00A7","&"),"\n&r","`n")
		v := StrReplace(v, "\n","`n")
		v := (InStr(v,"&r") = 1) ? Substr(v, 3) : v
		this.editor.Contents := v
	}
	
	ConvertToHtml(motd) {
		l_html_a := ""
		
		stree := []
		For ind_b, ascii in StrSplit("8" . motd,"\u00A7")
		{
			For ind_c, val in StrSplit(ascii, "\u")
			{
				If (A_Index = 1)
					stext := val
				Else {
					stext := stext . "$" . SubStr(val, 5)
				}
			}
			
			l_style := SubStr(stext, 1, 1)
			l_text := StrReplace(SubStr(stext, 2), A_Space, "<span style=""color:black"">_</span>") ;renders spaces as invisible _'s
		;	MsgBox,,,% l_style . l_text
			If not this.stylekeyreset[l_style] {
				
			}
			Else {
				l_html_b := ""
				For ind_c, l_text_b in stree
				{
					l_html_b .= l_text_b
				}
				l_html_a .= l_html_b
				stree := []
			}
			stree.InsertAt(ind_b, this.stylekey[l_style] . l_text, this.styleendkey[l_style])
		}
		l_html_b := ""
		For ind_c, l_text_b in stree
		{
			l_html_b .= l_text_b
		}
		l_html_a .= l_html_b
		return l_html_a
	}
	
	AddFormat(Event := "") {
		Critical
		colname := this.Colrctrl.Contents
		For l_colcode, l_colname in this.styleKeyColorName
		{
			If (colname = l_colname)
			{
				colcode := "&" . l_colcode
				break
			}
		}
		bold := this.boldctrl.Contents ? "&l" : ""
		unde := this.undectrl.Contents ? "&n" : ""
		ital := this.italctrl.Contents ? "&o" : ""
		stri := this.strictrl.Contents ? "&m" : ""
		corr := this.corrctrl.Contents ? "&k" : ""
		this.editor.Contents .= colcode . bold . unde . ital . stri . corr
	}
	
	static stylekey := {nulll : ""
		, 0 : "<span style=""color:     Black"">"
		, 1 : "<span style=""color:  DarkBlue"">"
		, 2 : "<span style=""color: DarkGreen"">"
		, 3 : "<span style=""color:  DarkCyan"">"
		, 4 : "<span style=""color:   DarkRed"">"
		, 5 : "<span style=""color:    Indigo"">"
		, 6 : "<span style=""color:    Orange"">"
		, 7 : "<span style=""color: LightGray"">"
		, 8 : "<span style=""color:  DarkGray"">"
		, 9 : "<span style=""color:      Blue"">"
		, a : "<span style=""color:     Green"">"
		, b : "<span style=""color:      Cyan"">"
		, c : "<span style=""color:       Red"">"
		, d : "<span style=""color:    Purple"">"
		, e : "<span style=""color:    Yellow"">"
		, f : "<span style=""color:     White"">"
		
		, l : "<b>"
		, n : "<ins>"
		, o : "<i>"
		, m : "<del>"
		, k : "<b><ins><i><del>"
		, r : ""}
	static styleendkey := {nulll : ""
		, 0 : "</span>"
		, 1 : "</span>"
		, 2 : "</span>"
		, 3 : "</span>"
		, 4 : "</span>"
		, 5 : "</span>"
		, 6 : "</span>"
		, 7 : "</span>"
		, 8 : "</span>"
		, 9 : "</span>"
		, a : "</span>"
		, b : "</span>"
		, c : "</span>"
		, d : "</span>"
		, e : "</span>"
		, f : "</span>"
		
		, l : "</b>"
		, n : "</ins>"
		, o : "</i>"
		, m : "</del>"
		, k : "</del></i></ins></b>"
		, r : ""}
	static stylekeyreset := {nulll : ""
		, 0 : true
	    , 1 : true
	    , 2 : true
	    , 3 : true
	    , 4 : true
	    , 5 : true
	    , 6 : true
	    , 7 : true
	    , 8 : true
	    , 9 : true
	    , a : true
	    , b : true
	    , c : true
	    , d : true
	    , e : true
	    , f : true
	    
	    , l : false
	    , n : false
	    , o : false
	    , m : false
	    , k : false
	    , r : true}
	static styleKeyColorName := {0 : "Black", 1 : "Dark Blue", 2 : "Dark Green", 3 : "Dark Cyan", 4 : "Dark Red", 5 : "Indigo"
			, 6 : "Orange",7 : "Light Gray", 8 : "Dark Gray", 9 : "Blue", a : "Green", b : "Cyan", c : "Red", d : "Purple"
			, e : "Yellow", f : "White"}
		
	styleKeyColorName_Parse[] {
		get {
			v := ""
			For index, ColrName in this.styleKeyColorName
			{
				v .= (A_index = 1) ? ColrName : "|" . ColrName
			}
			return v
		}
	}
	
	ChangeStatus(controlobj) {
		v := (controlobj.Contents = "Online")
		this.applybtn.Enabled := v
		this.colrCtrl.Enabled := v
		this.Boldctrl.Enabled := v
		this.UndeCtrl.Enabled := v
		this.ItalCtrl.Enabled := v
		this.StriCtrl.Enabled := v
		this.CorrCtrl.Enabled := v
		this.editor.Enabled   := v
		this.motd.Enabled     := v
		this.Render("", v)
	}
	
	__Delete() {
		FileDelete, % this.temphtml
	}
}

class Tutorial {   ;-----------------Tutorial
	Class T_Type {
		Show() {
			If this.NoShow
				return
			
			this.gui := new gui("AlwaysOnTop -sysmenu","Tutorial")
			this.gui.Font("s" . FontNormal)
			this.gui.Add("Link",,this.LinkText())
			If not this.SuppressNoShow {
				this.hidctrl := this.gui.Add("CheckBox",,"Don't show this again")
			}
			this.gui.Add("Button",,"  OK  ").OnEvent(Tutorial.Console.Close.Bind(this))
			this.gui.OnEvent(Tutorial.Console.Close.Bind(this),"Close")
			this.Extra()
			this.gui.Show("AutoSize Center")
		}
		Close(Event := "") {
			this.NoShow := this.hidctrl.Contents
			this.gui.Destroy()
		}
	}
	Class Console extends Tutorial.T_Type {
		NoShow[] {
			get {
				return IniRead("QuickServer.ini", "Tutorial", "Console", false)
			}
			set {
				IniWrite(value,"QuickServer.ini","Tutorial","Console")
			}
		}
		LinkText() {
			v =
				( LTrim ,
				The console window allows you to run commands ("cheats"). Commands should NOT begin with a slash (/) when used here.
				
				Useful commands:
				/gamerule <rule> <value> --- changes gamerules
				/op <players>            --- enable cheat commands for the players
				/ban <players>           --- bans the players
				/kick <players>          --- disconnects the players
				/whitelist add <players> --- allows players to join (if the server is private)
				/say <message>           --- puts a message into chat
				/stop                    --- closes the server
				
				For a complete guide to Minecraft commands, <a href="https://minecraft.gamepedia.com/Commands">click here</a>
				
				)
			return v
		}
	}
	
	class Donate extends Tutorial.T_Type {
		static SuppressNoShow := true
		static NoShow := false
		LinkText() {
			v = 
				( LTrim
				Dear Player,
				
				It seems like you are enjoying QuickServer!
				I'm glad to see that you are enjoying QuickServer.
				
				Please consider donating because it really helps me keep this software going. 
				
				Thanks!
				~Developer
				
				<a href="https://www.gofundme.com/f/keep-quickservermc-up-to-date-with-new-features?utm_source=customer&utm_medium=copy_link&utm_campaign=p_cf+share-flow-1">Donate Now</a>
				
				)
			return v
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


RunTer(command, windowtitle, startingdir := "", wait := false, minmaxhide := "") {
	static tmpcount := 0
	
	batch =
		(Ltrim
		@echo off
		title %windowtitle%
		%command%
		)
	tmp := Temp . "\RunTer_" . tmpcount++ . ".bat"
	try FileDelete, % tmp
	FileAppend, % batch, % tmp
	If wait
	{
		runwait, cmd.exe /c %tmp%, %startingdir%,%minmaxhide%, cmdPID
		return 0
	}
	run, cmd.exe /c %tmp%, %startingdir%,%minmaxhide%, cmdPID
	
	WinWait, ahk_pid %cmdPID%,,3
	winHWND := WinExist()
	try WinBlur(100)
	return winHWND
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

InArray(array, value) {
	For index, val in array
	{
		If (val = value)
			return index
	}
	return 0
}

Clear_Temp_Files() {
	FileRemoveDir, % Temp, 1
	FileDelete, % DefaultDir . "\*_MOTD.html"
}
}

class eulaWindow { ;-----------------EULA-----------------------
	waiting := true
	__New(uniquename) {
		this.guiobj := new gui
		this.guiobj.Font("s" . FontNormal)
		this.guiobj.add("link",,"Please read and agree to the <a href=""https://account.mojang.com/documents/minecraft_eula"">Minecraft EULA</a>")
		this.guiobj.add("text",,"     ")
		this.IAgreeCtrl := this.guiobj.add("checkbox",,"I agree to the Minecraft EULA")
		this.guiobj.add("button",,"  OK  ").OnEvent(eulaWindow.continue.bind(this),"Normal")
		this.guiobj.OnEvent(eulaWindow.continue.bind(this),"Close")
		this.guiobj.Show("autosize center","QuickServer")
		Critical,off
		While this.waiting
		{
			sleep,50
		}
		If this.IAgree {
			FileDelete, %uniquename%\eula.txt
			FileAppend, eula=true, %uniquename%\eula.txt
		}
	}
	
	continue(Event := "") {
		this.IAgree := this.IAgreeCtrl.Contents and not (Event.EventType = "Close")
		this.guiobj.destroy()
		this.waiting := false
	}
}

class Spigot { ;    -----------------Spigot installation
	class Installation {
		__New(version) {
			version := StrReplace(version,A_Space)
			If (InStr(version,"1.") = 1)
			{
				subv := StrReplace(version, "1.",,, 1)
				If subv is number
				{
					this.version := version
				}
			}
		}
		Confirmed[] {
			get {
				return (not this.version and FileExist(this.JarFile))
			}
		}
		JarFile[] {
			get {
				return DefaultDir . "\BuildTools\spigot-" . this.version . ".jar"
			}
		}
	}
	
	Choose_Inst_Window(defaultversion := "latest") {
		l_gui := new gui(,"Installations")
		l_gui.Font("s" . FontNormal)
		l_gui.add("Text",,"Enter the desired version (example: 1.16.4).`n`nType ""latest"" to use the latest version")
		
		l_list := "latest"
		For index, inst in Spigot.GetInstallations()
		{
			l_list .= "|" . inst
		}
		versctrl := l_gui.add("ComboBox",,l_list)
		versctrl.Text := Defaultversion
		
		btn := l_gui.add("Button","default w" . FontNormal * 10, "OK")
		
		l_gui.NoClose := true
		while not ((e := l_gui.Wait()).Control.Type = "Button") and not (e.EventType = "Close")
		{
		}
		newVersion := versctrl.Text
		l_gui.destroy()
		return new Spigot.Installation(newVersion)
	}
	
	GetInstallations() {
		inst_array := []
		Loop, Files, %DefaultDir%\BuildTools\spigot-*.jar
		{
			inst_array.Push(new Spigot.Installation(StrReplace(StrReplace(A_LoopFileName,".jar"), "spigot-")))
		}
		return inst_array
	}
}

{ ;----------------------------------Update---------------
UpdateServer(version := "latest", Force := true) {
	
	if not InStr(FileExist(DefaultDir . "\BuildTools"), "D") {
		filecreatedir, %DefaultDir%\BuildTools
	}
	try FileDelete, % DefaultDir . "\BuildTools\spigot-" . version . ".jar"
	
	UpdateServerRetry:
	;try {
	;	runwait, curl -z BuildTools.jar -o BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar, %DefaultDir%\BuildTools
	;}
	SplashTextOn,,110, Installing..., Installing Spigot for Minecraft.`nThis may take several minutes...
	URLDownloadToFile
		,https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
		, %DefaultDir%\BuildTools\BuildTools.jar
		
	try FileDelete, %DefaultDir%\BuildTools\BuildTools.log.txt
	try {
		ForceArg := Force ? "" : "--compile-if-changed"
		runwait, %comspec% /c java -jar BuildTools.jar %ForceArg% --rev %version%, %DefaultDir%\BuildTools
	}
	catch {
		SplashTextOff
		msgbox, 0x15, QuickServer error, Install failed. Try reinstalling Java at https://java.com/en/download/
		Ifmsgbox, Retry
		{
			goto UpdateServerRetry
		}
		return false
	}
	SplashTextOff
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
	
	
	attribs := FileExist(DefaultDir . "\BuildTools\spigot-" . version . ".jar")
	If attribs and !(version = "latest")
	{
		Serverinfo.confirmed := true
		ServerFile = spigot-%version%.jar
		ServerFile.version := version
	}
	Else if FileExist(DefaultDir . "\BuildTools\spigot-" . Serverinfo.version . ".jar") and InstallationsWin.IsValidVersion(Serverinfo.version)
	{
		Serverinfo.confirmed := true
	}
	
	;IfExist,%DefaultDir%\BuildTools\%ServerFile%
	;{
	;	Serverinfo.confirmed := true
	;}
	;Else IfExist, %DefaultDir%\BuildTools\spigot-%version%.jar
	;{
	;	Serverinfo.confirmed := true
	;	ServerFile = spigot-%version%.jar
	;}
	;If not (version = "latest")
	;{
	;	Serverinfo.isLatest := false
	;	Serverinfo.version := version
	;}
	
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
	}
}
}

{ ;----------------------------------Misc----------------

DefaultPropertiesFile(FilePath) {
	FileAppend,
	( Ltrim
		enable-jmx-monitoring=false
		rcon.port=25575
		level-seed=
		gamemode=survival
		enable-command-block=true
		enable-query=false
		generator-settings=
		level-name=world
		motd=Made Using QuickServerMC
		query.port=25565
		pvp=true
		generate-structures=true
		difficulty=easy
		network-compression-threshold=256
		max-tick-time=60000
		max-players=8
		use-native-transport=true
		online-mode=true
		enable-status=true
		allow-flight=false
		broadcast-rcon-to-ops=true
		view-distance=10
		max-build-height=256
		server-ip=
		allow-nether=true
		server-port=25565
		enable-rcon=false
		sync-chunk-writes=true
		op-permission-level=4
		prevent-proxy-connections=false
		resource-pack=
		entity-broadcast-range-percentage=100
		rcon.password=
		player-idle-timeout=0
		force-gamemode=false
		rate-limit=0
		hardcore=false
		white-list=false
		broadcast-console-to-ops=true
		spawn-npcs=true
		spawn-animals=true
		snooper-enabled=true
		function-permission-level=2
		level-type=default
		spawn-monsters=true
		enforce-whitelist=false
		resource-pack-sha1=
		spawn-protection=16
		max-world-size=29999984
		require-resource-pack=false
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
	#Include, %A_ScriptDir%\SelectFolderEx.ahk
	#Include, %A_ScriptDir%\GuiObject.ahk
	#Include, %A_ScriptDir%\JSON.ahk
}