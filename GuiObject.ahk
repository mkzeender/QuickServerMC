ho := new Gui()
x := ho.Add("Text",,"dkkkkkkkkkkaaaaaa`n`n`n`n`n`n`n`n")
ho.add("Button",,"Well")
ho.show("autosize center")
ho.OnEvent("e","Close")
loop
{
ho.Wait("Normal|ContextMenu","|Button","|Well|dkkkkkkkkkkaaaaaa`n`n`n`n`n`n`n`n")
MsgBox done
}
e:
ExitApp

{ ;------ GUI -----------


Class Gui {
	ControlList := []
	
	New(Options := "", Title := "") {
		return new Gui(options, Title)
	}
	__New(Options := "", Title := "") {
		local
		If not (crit := A_IsCritical)
			critical
		
		global GuiObj_GuiList
		If not IsObject(GuiObj_GuiList)
			GuiObj_GuiList := []
		
		
		GuiObj_GuiList.Push(this)
		gui, new, % Options, % Title
		gui, +HWNDhwnd +LabelGuiObj_EventHandler_
		this.HWND := hwnd
		Critical, % crit
	}
	__Call(SubCommand, param1 := "", param2 := "", param3 := "") {
		If SubCommand not in New,Add,OnEvent,Destroy,Options,Wait
		{
			try {
				gui, % this.Hwnd . ":" . subcommand, % param1, % param2, % param3
			}
			catch Exceptn{
				Throw Exception(Exceptn.Message, -1,Exceptn.Extra)
			}
			return ""
		}
	}
	
	Add(ControlType, options := "", text := "") {
		local
		ControlType := StrReplace(ControlType,A_Space)
		Try {
			If (ControlType = "ListView")
				ctrl := new this.GuiControl_ListView(ControlType, options, text, this)
			Else if (ControlType = "TreeView")
				ctrl := new this.GuiControl_TreeView(ControlType, options, text, this)
			Else
				ctrl := new this.GuiControl(ControlType, options, text, this)
			this.ControlList.Push(ctrl)
		}
		catch exceptn {
			If InStr(" " . options," v") or InStr(" " . options," g") {
				Throw Exception("Control should not have a v-Variable or g-Label. Use control.Contents or control.OnEvent() instead.", -1)
				return ""
			}
			Else {
				Throw Exception(Exceptn.Message, -1,Exceptn.Extra)
			}
		}
		return ctrl
	}
	
	Options(options) {
		try {
			gui, % this.Hwnd . ":" . options
		}
		catch, Exceptn {
			throw Exception(Exceptn.Message, -1,Exceptn.Extra)
		}
	}
	
	Destroy() {
		local
		global GuiObj_GuiList
		If not (crit := A_IsCritical)
			critical
		
		gui, % this.Hwnd . ":destroy"

		For index, obj in GuiObj_GuiList
		{
			if (obj.Hwnd = this.Hwnd) {
				GuiObj_GuiList.RemoveAt(index)
				break
			}
		}
		For index, ctrl in this.ControlList
		{
			ctrl.base := {}
		}
		this.base := {}
		Critical, % crit
		return
	}
	
	FocussedCtrl[] {
		get {
			local ClassNN, Hwnd
			GuiControlGet, ClassNN, Focus
			GuiControlGet, Hwnd, Hwnd, % ClassNN
			return GuiObj_GetFromHwnd(Hwnd, this.ControlList)
		}
		set {
			value.focus := true
			return this.FocussedCtrl
		}
	}
	
	EventHandlers := []
	EventTickets := []
	static OnEvent := Func("GuiObj_EventHandler_OnEvent")
	static Wait := Func("GuiObj_EventHandler_Wait")
	NoClose := 0

	
	Class GuiControl {
		__New(ControlType, options, text, ParentObj) {
			local
			If not (crit := A_IsCritical)
				critical
			this.Type := ControlType
			this.ParentHwnd := ParentObj.Hwnd
			try {
				gui, % this.ParentHwnd . ":add", % ControlType, % "hwndhwnd " . options, % text
			}
			catch, Exceptn {
				throw Exception(Exceptn.Message, -1,Exceptn.Extra)
			}
			funcobj := ObjBindMethod(this,"EventHandler") ; Gui.GuiControl.EventHandler.Bind(this)
			GuiControl, +g, % hwnd, %funcobj%
			this.Hwnd := Hwnd
			this.ControlID := Hwnd
			critical, % crit
			
		}
		
		ParentGui[] {
			get {
				global GuiObj_GuiList
				return GuiObj_GetFromHwnd(this.ParentHwnd, GuiObj_GuiList)
			}
			set {
				return this.ParentGui
			}
		}
		
		Contents[] {
			get {
				local v
				GuiControlGet, v,, % this.ControlID
				return v
			}
			set {
				GuiControl,, % this.ControlID, % value
				return this.Contents
			}
		}
		
		Text[] {
			get {
				local v
				GuiControlGet, v,, % this.ControlID, Text
				return v
			}
			set {
				GuiControl, Text, % this.ControlID, % value
				return this.Text
			}
		}
		
		
		MetaGetPosition(key) {
			local
			GuiControlGet, Pos, Pos, % this.ControlID
			v := Pos%key% ; dynamic variable
			return v
		}
		MetaSetPosition(key, value) {
			GuiControl, move, % this.ControlID, %key%%value%
		}
		
		X[] {
			get {
				return this.MetaGetPosition("X")
			}
			set {
				this.MetaSetPosition("X",value)
				return this.MetaGetPosition("X")
			}
		}
		Y[] {
			get {
				return this.MetaGetPosition("Y")
			}
			set {
				this.MetaSetPosition("Y",value)
				return this.MetaGetPosition("Y")
			}
		}
		W[] {
			get {
				return this.MetaGetPosition("W")
			}
			set {
				this.MetaSetPosition("W",value)
				return this.MetaGetPosition("W")
			}
		}
		H[] {
			get {
				return this.MetaGetPosition("H")
			}
			set {
				this.MetaSetPosition("H",value)
				return this.MetaGetPosition("H")
			}
		}
		
		
		Focus[] {
			get {
				local
				GuiControlGet, ClassNN, Focus
				GuiControlGet, Hwnd, Hwnd, % ClassNN
				return (Hwnd = this.Hwnd)
			}
			set {
				If value
					GuiControl, Focus, % this.ControlID
				return this.Focus
			}
		}
		
		Enabled[] {
			get {
				local v
				GuiControlGet, v, Enabled, % this.ControlID
				return v
			}
			set {
				If value
					GuiControl, Enable, % this.ControlID
				else
					GuiControl, Disable, % this.ControlID
				return this.Enabled
			}
		}
		Visible[] {
			get {
				local v
				GuiControlGet, v, Visible, % this.ControlID
				return v
			}
			set {
				If value
					GuiControl, Show, % this.ControlID
				else
					GuiControl, Hide, % this.ControlID
				return this.Visible
			}
		}
		Choose(N) {
			GuiControl, Choose, % this.ControlID, % N
		}
		ChooseString(String) {
			GuiControl, ChooseString, % this.ControlID, % String
		}
		Options(options) {
			try {
				GuiControl, %options%, % this.ControlID
			}
			catch, Exceptn {
				throw Exception(Exceptn.Message, -1,Exceptn.Extra)
			}
		}
		
	
	
		EventHandler(CtrlHwnd, GuiEvent, EventInfo, ErrLevel := "") {
			local
			Event := {Gui : this.ParentGui, Control : this
				, EventType : "Normal", EventInfo : EventInfo, GuiEvent : GuiEvent, ErrorLevel : ErrLevel}
			GuiObj_EventHandler_PostEvent(Event, Event.Control)
			GuiObj_EventHandler_PostEvent(Event, Event.Gui)
		}
		
		EventHandlers := []
		EventTickets := []
		static OnEvent := Func("GuiObj_EventHandler_OnEvent")
		static Wait := Func("GuiObj_EventHandler_Wait")
	}
	
	Class GuiControl_ListView extends Gui.GuiControl {
		
		__Call(function, params*) {
			local
			If (InStr(function, "LV_") = 1) and not (function = "LV_GetText") {
				If not (crit := A_IsCritical) {
					Critical
				}
				gui, % this.ParentHwnd . ":default"
				gui, % this.ParentHwnd . ":ListView", % this.Hwnd
				v := %function%(params*)
				Critical, % crit
				return v
			}
		}
	
		LV_GetText(byref outputvar, params*) {
			local
			If not (crit := A_IsCritical)
				Critical
			gui, % this.ParentHwnd . ":default"
			Gui, % this.ParentHwnd . ":ListView", % this.Hwnd
			v := LV_GetText(outputvar, params*)
			Critical, % crit
			return v
		}
	}
	
	Class GuiControl_TreeView extends Gui.GuiControl {
		
		__Call(function, params*) {
			local
			If (InStr(function,"TV_") = 1) and not (function = "TV_GetText") {
				If not (crit := A_IsCritical)
					Critical
				Gui, % this.ParentHwnd . ":Default"
				Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
				v := %function%(params*)
				
				Critical, % crit
				return v
			}
		}
		
		TV_GetText(ByRef outputvar, params*) {
			local
			If not (crit := A_IsCritical)
				Critical
			Gui, % this.ParentHwnd . ":Default"
			Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
			v := TV_GetText(outputvar, params*)
			Critical, % crit
			return v
		}
	}
	
	Class MenuObj {
		
		__New(item_tree) {
			local
			this.MenuName := "GuiObj_Menu_object_" . ++this.MenuCount
			this.AddMenu(item_tree)
		}

		AddMenu(item_tree) {
			For index, item in item_tree
			{
				If IsObject(item)
					action := this.AddMenu(item*)
				else
					action := ObjBindMethod(this, "ItemClick").Bind(item)
				Menu, % this.MenuName, add, g
			}
		
		}
		static MenuCount := 0
		static GuiObj_IsMenuObj := true
	}
}
}


{ ;------ Event handling Functions
GuiObj_GetFromHwnd(Hwnd, list) {
	local
	For index, obj in list
	{
		if (obj.Hwnd = Hwnd) {
			return obj
		}
	}
	return ""
}
GuiObj_EventHandler_OnEvent(this, Function, EventType := "All") {
		local
		handler := {Function : Function,EventType : EventType}
		this.EventHandlers.Push(handler)
		return handler
}
GuiObj_EventHandler(EventType, GuiHwnd, EventInfo := "", CtrlHwnd := "", X := "", Y := "", ErrLevel := "", FileArray := "") {
	local
	Event := {EventType : EventType, EventInfo : EventInfo
		, X : X, Y : Y, GuiEvent : A_GuiEvent, ErrorLevel : ErrLevel
		, FileArray : FileArray, Width : A_GuiWidth, Height : A_GuiHeight}
	
	global GuiObj_GuiList
	Event.Gui := GuiObj_GetFromHwnd(GuiHwnd,GuiObj_GuiList)
	Event.Control := GuiObj_GetFromHwnd(CtrlHwnd, Event.Gui.ControlList)
	Event.NoClose := Event.Gui.NoClose
	
	GuiObj_EventHandler_PostEvent(Event, Event.Control)
	GuiObj_EventHandler_PostEvent(Event, Event.Gui)
	If (Event.EventType = "Close") and (Event.NoClose = -1)
		Event.Gui.Destroy()
	
	ErrorLevel := Event.ErrorLevel
	return Event.NoClose
}
GuiObj_EventHandler_PostEvent(Event, InObject) {
	local
	If not IsObject(InObject)
		return ""
	For index, EventHandler in InObject.EventHandlers
	{
		If (EventHandler.EventType = Event.EventType) Or (EventHandler.EventType = "All") {
			l_fn := IsObject(EventHandler.Function) ? EventHandler.Function 
			     :  IsFunc(EventHandler.Function) ? Func(EventHandler.Function)
				 :  IsLabel(EventHandler.Function) ? Func("GuiObj_EventHandler_Gosub").Bind(EventHandler.Function)
				 :  {}
			l_fn.Call(Event)
		}
	}
	
	If not (crit := A_IsCritical)
		critical
	ct := 0
	ia := Func("GuiObj_Misc_InArray")
	For index, Tkt in InObject.EventTickets
	{
		If    %ia%(Tkt.EventTypes  , Event.EventType   )
		  and %ia%(Tkt.ControlTypes, Event.Control.Type)
		  and %ia%(Tkt.ControlTexts, Event.Control.Text)
		  and %ia%(Tkt.EventInfos  , Event.EventInfo  )
		  and %ia%(Tkt.GuiEvents   , Event.GuiEvent   )
		  and %ia%(Tkt.ErrorLevels , Event.ErrorLevel )
		{
			Tkt.Event := Event
			Tkt.Is_Handled := 1
			
		}
		;MsgBox,,, % %ia%(Tkt.EventTypes  , Event.EventType  ) . "`n" . tkt.EventTypes.Length()
	}
	For index in InObject.EventTickets
	{
		While (InObject.EventTickets[index].Is_Handled = 2) {
			InObject.EventTickets.RemoveAt(index)
		}
	}
	Critical, % crit
}
GuiObj_Misc_InArray(Array, Value) {
	local
	If not Array.Length()
		return -1
	
	For index, val in Array
	{
		If (val = Value)
			return index
	}
	return 0
}
GuiObj_EventHandler_Gosub(Label, l_Event) {
	local
	global Gui_ThisEvent
	static s_PrevEvents := []
	If not (crit := A_IsCritical)
		Critical
	
	s_PrevEvents.Push(Gui_ThisEvent)
	Gui_ThisEvent := l_Event
	Critical, % crit
	
	gosub, % Label
	Gui_ThisEvent := s_PrevEvents.Pop()
}
{ ;Event handler functions
GuiObj_EventHandler_Close(GuiHwnd) {
	return GuiObj_EventHandler("Close",GuiHwnd)
}
GuiObj_EventHandler_Escape() {
	local
	Gui, +HWNDhwnd
	GuiObj_EventHandler("Escape", hwnd)
}
GuiObj_EventHandler_Size(GuiHwnd,EventInfo) {
	GuiObj_EventHandler("Size",GuiHwnd, EventInfo,,,,ErrorLevel)
}
GuiObj_EventHandler_ContextMenu(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y) {
	GuiObj_EventHandler("ContextMenu",GuiHwnd,EventInfo,CtrlHwnd, X, Y)
}
GuiObj_EventHandler_DropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {
	GuiObj_EventHandler("DropFiles",GuiHwnd,A_EventInfo,CtrlHwnd,X,Y,ErrorLevel,FileArray)
}
}

GuiObj_EventHandler_Wait(this, EventTypes := "", ControlTypes := "", ControlTexts := "", EventInfos := "", GuiEvents := "", ErrorLevels := "") {
	local
	EventTicket := {Is_Handled : 0
		, EventTypes     : StrSplit(EventTypes,   "|")
		, ControlTypes   : StrSplit(ControlTypes, "|")
		, ControlTexts   : StrSplit(ControlTexts, "|")
		, EventInfos     : StrSplit(EventInfos,   "|")
		, GuiEvents      : StrSplit(GuiEvents,    "|")
		, ErrorLevels    : StrSplit(ErrorLevels,  "|")}
	this.EventTickets.Push(EventTicket)
	crit := A_IsCritical
	Critical, off
	Loop {
		sleep, 20
	} until not (EventTicket.Is_Handled = 0)
	EventTicket.Is_Handled := 2
	Critical, % crit
	return EventTicket.Event
}

}

{
}