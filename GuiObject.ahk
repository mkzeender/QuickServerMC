
{ ;------ GUI -----------


Class Gui {
	ControlList := []
	
	New(Options := "", Title := "") {
		return new Gui(options, Title)
	}
	__New(Options := "", Title := "") {
		crit := A_IsCritical
		critical
		global GuiObj_GuiList
		If not IsObject(GuiObj_GuiList)
			GuiObj_GuiList := []
		
		
		GuiObj_GuiList.Push(this)
		gui, new, % Options, % Title
		gui, +HWNDhwnd +LabelGuiObj_EventHandler_
		this.HWND := hwnd
		if not crit
			Critical, off
	}
	__Call(SubCommand, param1 := "", param2 := "", param3 := "") {
		If SubCommand not in New,Add,OnEvent,Destroy,Options,Wait
		{
			gui, % this.Hwnd . ":" . subcommand, % param1, % param2, % param3
			return ""
		}
	}
	
	Add(ControlType, options := "", text := "") {
		If (ControlType = "ListView")
			ctrl := new GuiControl_ListView(ControlType, options, text, this)
		Else if (ControlType = "TreeView")
			ctrl := new GuiControl_TreeView(ControlType, options, text, this)
		Else
			ctrl := new GuiControl(ControlType, options, text, this)
		this.ControlList.Push(ctrl)
		return ctrl
	}
	
	Options(options) {
		gui, % this.Hwnd . ":" . options
	}
	
	Destroy() {
		crit := A_IsCritical
		critical
		gui, % this.Hwnd . ":destroy"
		global GuiObj_GuiList
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
		if not crit
			Critical,off
		return
	}
	
	EventHandlers := []
	EventTickets := []
	static OnEvent := Func("GuiObj_EventHandler_OnEvent")
	static Wait := Func("GuiObj_EventHandler_Wait")
}

Class GuiControl {
	__New(ControlType, options, text, ParentObj) {
		crit := A_IsCritical
		critical
		this.Type := ControlType
		this.ParentHwnd := ParentObj.Hwnd
		gui, % this.ParentHwnd . ":add", % ControlType, % "hwndhwnd " . options, % text
		
		funcobj := GuiControl.EventHandler.Bind(this)
		GuiControl, +g, % hwnd, %funcobj%
		this.Hwnd := Hwnd
		this.ControlID := Hwnd
		If not crit
			critical, off
		
	}
	
	ParentGui[] {
		get {
			global GuiObj_GuiList
			return GuiObj_GetFromHwnd(this.ParentHwnd, GuiObj_GuiList)
		}
		set {
			return value
		}
	}
	
	Contents[] {
		get {
			GuiControlGet, v,, % this.ControlID
			return v
		}
		set {
			GuiControl,, % this.ControlID, % value
		}
	}
	
	Text[] {
		get {
			GuiControlGet, v,, % this.ControlID, Text
			return v
		}
		set {
			GuiControl, Text, % this.ControlID, % value
		}
	}
	
	Pos[key := ""] {
		get {
			GuiControlGet, Pos, Pos, % this.ControlID
			If (key = "") {
				return {base : {__Set : GuiControl.ChangePos_Meta_Set.Bind(this),__Get : GuiControl.ChangePos_Meta_Get.Bind(this)}}
			}
			else
			{
				v := Pos%key% ; dynamic variable
				return v
			}
		}
		set {
			GuiControl, move, % this.ControlID, %key%%value%
		}
	}
	
	ChangePos_Meta_Set(void, position, value) {
		GuiControl, move, % this.ControlID, %position%%value%
		return value
	}
	ChangePos_Meta_Get(void, position) {
		GuiControlGet, Pos, Pos, % this.ControlID
		v := Pos%position%
		return v
	}
	
	Focus[] {
		get {
			GuiControlGet, ClassNN, Focus
			GuiControlGet, Hwnd, Hwnd, % ClassNN
			return (Hwnd = this.Hwnd)
		}
		set {
			If value
				GuiControl, Focus, % this.ControlID
		}
	}
	
	Enabled[] {
		get {
			GuiControlGet, v, Enabled, % this.ControlID
			return v
		}
		set {
			If value
				GuiControl, Enable, % this.ControlID
			else
				GuiControl, Disable, % this.ControlID
		}
	}
	Visible[] {
		get {
			GuiControlGet, v, Visible, % this.ControlID
			return v
		}
		set {
			If value
				GuiControl, Show, % this.ControlID
			else
				GuiControl, Hide, % this.ControlID
		}
	}
	Choose(N) {
		GuiControl, Choose, % this.ControlID, % N
	}
	ChooseString(String) {
		GuiControl, ChooseString, % this.ControlID, % String
	}
	Options(options) {
		GuiControl, %options%, % this.ControlID
	}
	


	EventHandler(CtrlHwnd, GuiEvent, EventInfo, ErrLevel := "") {
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

Class GuiControl_ListView extends GuiControl {
	
		
	__Call(function, params*) {
		If (InStr(function, "LV_") = 1) and not (function = "LV_GetText") {
			If not (crit := A_IsCritical) {
				Critical
			}
			gui, % this.ParentHwnd . ":default"
			gui, % this.ParentHwnd . ":ListView", % this.Hwnd
			v := %function%(params*)
			If not crit {
				Critical, off
			}
			return v
		}
	}

	LV_GetText(byref outputvar, params*) {
		If not (crit := A_IsCritical)
			Critical
		gui, % this.ParentHwnd . ":default"
		Gui, % this.ParentHwnd . ":ListView", % this.Hwnd
		v := LV_GetText(outputvar, params*)
		If not crit
			Critical, off
		return v
	}
}

Class GuiControl_TreeView extends GuiControl {

	TV_Add(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_Add(params*)
		If not crit
			Critical, off
		return v
	}
	TV_Modify(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_Modify(params*)
		If not crit
			Critical, off
		return v
	}
	TV_Delete(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_Delete(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetSelection(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetSelection()
		If not crit
			Critical, off
		return v
	}
	TV_Get(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_Get(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetCount(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetCount()
		If not crit
			Critical, off
		return v
	}
	TV_GetParent(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetParent(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetChild(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetChild(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetPrev(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetPrev(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetNext(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetNext(params*)
		If not crit
			Critical, off
		return v
	}
	TV_GetText(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_GetText(params*)
		If not crit
			Critical, off
		return v
	}
	TV_SetImageList(params*) {
		crit := A_IsCritical
		Critical
		Gui, % this.ParentHwnd . ":TreeView", % this.Hwnd
		v := TV_SetImageList(params*)
		If not crit
			Critical, off
		return v
	}
	
}

GuiObj_GetFromHwnd(Hwnd, list) {
	For index, obj in list
	{
		if (obj.Hwnd = Hwnd) {
			return obj
		}
	}
	return ""
}
GuiObj_EventHandler_OnEvent(this, Function, EventType := "All") {
		Function := IsObject(Function) ? Function : Func(Function)
		handler := {Function : Function,EventType : EventType}
		this.EventHandlers.Push(handler)
		return handler
}
GuiObj_EventHandler(EventType, GuiHwnd, EventInfo := "", CtrlHwnd := "", X := "", Y := "", ErrLevel := "", FileArray := "") {
	Event := {EventType : EventType, EventInfo : EventInfo, X : X, Y : Y, GuiEvent : A_GuiEvent, ErrorLevel : ErrLevel, FileArray : FileArray, NoClose : false}
	
	global GuiObj_GuiList
	Event.Gui := GuiObj_GetFromHwnd(GuiHwnd,GuiObj_GuiList)
	Event.Control := GuiObj_GetFromHwnd(CtrlHwnd, Event.Gui.ControlList)
	
	GuiObj_EventHandler_PostEvent(Event, Event.Control)
	GuiObj_EventHandler_PostEvent(Event, Event.Gui)
	return Event.NoClose
}
GuiObj_EventHandler_PostEvent(Event, InObject) {
	If not IsObject(InObject)
		return ""
	For index, EventHandler in InObject.EventHandlers
	{
		If (EventHandler.EventType = Event.EventType) Or (EventHandler.EventType = "All") {
			EventHandler.Function.Call(Event)
		}
	}
	
	crit := A_IsCritical
	critical
	ct := 0
	For index, EventTicket in InObject.EventTickets
	{
		For gg, typ in EventTicket.EventTypes
		{
			ct += (typ = Event.EventType)
		}
		ct += not EventTicket.EventTypes.Length()
		If ct and (EventTicket.Is_Handled = 0) {
			EventTicket.Event := Event
			EventTicket.Is_Handled := 1
		}
		
	}
	For index in InObject.EventTickets
	{
		While (InObject.EventTickets[index].Is_Handled = 2) {
			InObject.EventTickets.RemoveAt(index)
		}
	}
	If not crit
		Critical, off
}

{ ;Event handler functions
GuiObj_EventHandler_Close(GuiHwnd) {
	return GuiObj_EventHandler("Close",GuiHwnd)
}
GuiObj_EventHandler_Escape() {
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

GuiObj_EventHandler_Wait(this, EventTypes*) {
	EventTicket := {Is_Handled : 0, EventTypes : EventTypes}
	this.EventTickets.Push(EventTicket)
	Loop {
		sleep, 50
	} until not (EventTicket.Is_Handled = 0)
	EventTicket.Is_Handled := 2
	return EventTicket.Event
}

}

{ ;------ MENU ----------

Class Menu {
	
}
}

{
}