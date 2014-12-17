#SingleInstance force
#NoEnv
SetBatchLines, -1
Process, Priority, , High
CoordMode, Mouse, Window
CoordMode, Pixel, Window
CoordMode, ToolTip, Window
DetectHiddenWindows, On
SetTitleMatchMode, 2

#Include gdip.ahk
#Include Yaml.ahk

If !pToken := Gdip_Startup()
{
   MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
   ExitApp
}
OnExit, Exit

Gosub, Set_config
Width := A_ScreenWidth, Height := A_ScreenHeight
Menu, Tray, Icon, Shell32.dll, 101
Gui, 1: +LastFound +OwnDialogs
Gui, 1: Default
Gui, 1: Add, Picture, x10 y10 w%w_rect_area% h%h_rect_area% 0xE vCanvas

Menu, FileMenu, Add, &New`tCtrl+N, New  
Menu, FileMenu, Add, &Open`tCtrl+O, Load_It 
Menu, FileMenu, Add, &Save`tCtrl+S, Save_Img  
Menu, FileMenu, Add, E&xit`tEsc, Exit

Menu, EditMenu, Add, &Select all`tCtrl+A, Ctrla 
Menu, EditMenu, Add, Deselect all, undo_ctrla 
Menu, EditMenu, Add, Duplicate selection`tCtrl+D, dup_sub 
Menu, EditMenu, Add, &Delete selection`tDel, delete_sub  
Menu, EditMenu, Add, Invert selection vert`tCtrl+V, Inv_vert_sub  
Menu, EditMenu, Add, Invert selection horiz`tCtrl+H, Inv_horiz_sub  
;~ Menu, EditMenu, Add, Merge overlapping nodes, Merge_node  ;experimental

Menu, HelpMenu, Add, &About, Aboot
Menu, HelpMenu, Add, &Help, Help

Menu, MyMenuBar, Add, &File, :FileMenu
Menu, MyMenuBar, Add, &Edit, :EditMenu
Menu, MyMenuBar, Add, &Help, :HelpMenu

line_width := 2
pPen_Lines_black := Gdip_CreatePen(0xff000000, line_width)
pPen_Lines_blue := Gdip_CreatePen(0xff0000ff, line_width)
pPen_Lines_blue1 := Gdip_CreatePen(0xff0000ff, 1)
pBrush_black := Gdip_BrushCreateSolid(0xff000000)
pBrush_blue := Gdip_BrushCreateSolid(0xff0000ff)
pBrush_white := Gdip_BrushCreateSolid(0xffffffff)
pBrush_red := Gdip_BrushCreateSolid(0xffff0000)
pBrush_magenta := Gdip_BrushCreateSolid(0xffff00ff)

pPen_Lines_grey := Gdip_CreatePen(0xff888888, line_width)
pBrush_yel_a := Gdip_BrushCreateSolid(0xBBFFFEAA)

pPen_plotback := Gdip_CreatePen(0xff000000, 2)
pPen_area := Gdip_CreatePen(0xffcccccc, 2)
pBrush_area_fill := Gdip_BrushCreateSolid(0xffffffff)

;~ ---------------------------------------------------------------------------------------------------------------
GuiControlGet, Global_Mouse_Offset_, Pos, Canvas
GuiControlGet, hwnd, hwnd, Canvas
Global_Mouse_Offset_y += 44
Global_Mouse_Offset_x += 2

;~ Update_Opt := 1
Update_Opt := 2

If ( Update_Opt = 1 )
{
	pBitmap := Gdip_CreateBitmap(w_rect_area, h_rect_area)
	G := Gdip_GraphicsFromImage(pBitmap)
	Gdip_SetSmoothingMode(G, 4)
	Gdip_GraphicsClear(G, 0xffffffff)
	Gdip_DrawRectangle(G, pPen_Lines_grey, 0, 0, w_rect_area-2, h_rect_area-2 )
	Gosub, Redraw2
	Gui, 1: Menu, MyMenuBar
	Gui, 1: Show, , ShefDraw - Untitled
}
else if ( Update_Opt = 2 )
{
	hdc_WINDOW      := GetDC(hwnd)                                               ; MASTER DC on the Window
	hbm_main := CreateDIBSection(w_rect_area, h_rect_area)
	hdc_main := CreateCompatibleDC()
	obm     := SelectObject(hdc_main, hbm_main)
	G        := Gdip_GraphicsFromHDC(hdc_main)
	Gdip_SetSmoothingMode(G, 4)
	Gui, 1: Menu, MyMenuBar
	Gui, 1: Show, , ShefDraw - Untitled
	Gosub, Redraw
	Gosub, Redraw2
}
;~ ---------------------------------------------------------------------------------------------------------------
;~ ---------------------------------------------------------------------------------------------------------------
;~ ---------------------------CONFIG------------------------------------------------------------------------------
Hovering_Node := 0
_Default_Length := 60

Snap_angle := 12
Snap_Node := 14

_Symbol_Gap := 30
_Symbol_Size := 22
SpecSize_diff := 2

Node_Count := 0
Node_Count_nosub := 0
Node_List := []
Node_high := []

Mult_bond_sep := 6

debug := 0
Box_Active := 0
Snap_angle_list := "0,15,30,45,60,75,90"
Zoom_Level := 0

Right_on := 0
Main_sub_on := 0

w_plus := 20
h_plus := 20

Dragging_select := 0
Saving_Delim := "|"
Node_merge_distance := 10

Max_bond_type := 1.5 
Max_bond_no := 4

;~ ---------------------------------------------------------------------------------------------------------------
;~ ---------------------------------------------------------------------------------------------------------------
Last_Click := A_TickCount
Default_Length := _Default_Length
Symbol_Size := _Symbol_Size
Symbol_Gap := _Symbol_Gap
;~ ---------------------------------------------------------------------------------------------------------------

Hotkey, RButton, R_Sub, On

SetTimer, Node_Check, 75
SetTimer, Click_Check, 50
return

#IfWinActive ShefDraw
~LButton UP::
Gosub, Redraw
Gosub, Redraw2
return

GuiClose:
ExitApp

Up::
Down::
Left::
Right::
+Up::
+Down::
+Left::
+Right::
If ( Selected_Count > 0 )
{
	Movement := ( RegexMatch(A_ThisLabel, "A)\+") = 1 ) ? 5 : 1
	For k, v in node_list
	{
		If ( Node%v%.selected <> 1 )
			Continue
		If ( RegexMatch(A_ThisLabel, "i)up") <> 0 )
			Node%v%.y -= Movement
		else If ( RegexMatch(A_ThisLabel, "i)down") <> 0 )
			Node%v%.y += Movement
		else If ( RegexMatch(A_ThisLabel, "i)left") <> 0 )
			Node%v%.x -= Movement
		else ;If ( A_ThisLabel = "down" )
			Node%v%.x += Movement
	}
		If ( RegexMatch(A_ThisLabel, "i)up") <> 0 )
			Box_y -= Movement
		else If ( RegexMatch(A_ThisLabel, "i)down") <> 0 )
			Box_y += Movement
		else If ( RegexMatch(A_ThisLabel, "i)left") <> 0 )
			Box_x -= Movement
		else ;If ( A_ThisLabel = "down" )
			Box_x += Movement
}
Gosub, Redraw
Gosub, Redraw2

return

#IfWinactive

Click_Check:
SetTimer, Click_Check, off
WinGetPos, c__Win_x, c__Win_y
MouseGetPos, c__Win_mx, c__Win_mY, c__Win_Win
c__Win_mx -= Global_Mouse_Offset_x
c__Win_mY -= Global_Mouse_Offset_y

IfWinNotActive, ShefDraw
{
	Click_Legit := 0
	SetTimer, Click_Check, 150
	Prev_click_check := 1
	return
}
else if ( c__Win_mx < 0 ) or ( c__Win_mx > w_rect_area ) or ( c__Win_my < 0 ) or ( c__Win_my > h_rect_area )
{
	Click_Legit := 0
	IfWinActive, ShefDraw
		If ( Right_on = 1 )
		{
			Right_on := 0
			Gui, 2: Destroy
			Hotkey, RButton, R_Sub, On
			Hotkey, NumpadEnter, R_Sub_Submit, Off
			Hotkey, Enter, R_Sub_Submit, Off
		}
}
else
{
	Click_Legit := 1
	IfWinActive, ShefDraw
	If ( Right_on = 1 )
	{
		Right_on := 0
		Gui, 2: Destroy
		Hotkey, RButton, R_Sub, On
		Hotkey, NumpadEnter, R_Sub_Submit, Off
		Hotkey, Enter, R_Sub_Submit, Off
	}
}

If ( Prev_click_check = 1 ) 
{
	Prev_click_check := 0	
	Gosub, Redraw
	Gosub, Redraw2
}

SetTimer, Click_Check, on
return

New:
Hovering_Node := 0
Node_Count := 0
Match_Node := 0
Node_Count_nosub := 0
Node_List := []
Node_high := []
Right_on := 0
Box_Active := 0
Zoom_Level := 0
Gosub, Bond_length_check
Default_Name := ""
Gui, 1: Show, , ShefDraw - Untitled
Gosub, Redraw
Gosub, Redraw2
return

Aboot:
Help_String =
(
Written by Lewis Williams in 2014
Lewis.K.Williams@gmail.com

Using AutoHotKey and
	GDI+	by	Tic and Rseding91
	YAML	by	HotKeyIt
	
Other advice taken from
	IsNull	on	GDI flickering issues
)
Msgbox, 4096, ShefDraw info, % Help_String
return

Help:
Help_String =
(
Ctrl A		-	Select all
Ctrl H		-	Invert on a horizontal plane
Ctrl V		-	Invert on a vertical plane
Ctrl D		-	Duplicate selection

Shift Click		-	Select node
Shift DoubleClick	-	Select molecule

Alt Click		-	Change colour of text

Ctrl Click		-	Delete bond/node
Delete		-	Delete selection

Middle Click	-	Change bond type

F1		-	Molecular weight of selection

Arrow keys	-	Move selected nodes 1 pixel (+Shift to move 5)

Right Click	-	Enter text**

**Set text extra options
-Cl	Left align Chlorine
OCN-	Right align isocyanate
-NH_2	Left align amine with subscript 2
O^+	Central Oxygen with superscript +
6c	## Draw six membered (regular) ring

## Select two nodes and then do this to graft onto the selection
)
Msgbox, 4096, ShefDraw help , % Help_String
return

#IfWinActive, ahk_class AutoHotkeyGUI
^NumpadAdd::
^=::
^wheelup::
Adj := 1.11111111
Zoom_Level ++
Gosub, Bond_length_check
Gosub, Zoom
return
	
^NumpadSub::
^-::
^wheeldown::
Adj := 0.9
Zoom_Level -= 1
Gosub, Bond_length_check
Gosub, Zoom
return

^Numpad0::
^0::
If ( Zoom_Level > 0 )
{
	Adj := 0.9
	Adj := Adj**Zoom_Level
}
else
{
	Adj := 1.11111111
	StringTrimLeft, _Zoom_Level, Zoom_Level, 1
	Adj := Adj**_Zoom_Level
}
Default_Length := _Default_Length
Symbol_Size := _Symbol_Size
Symbol_gap := _Symbol_gap
Gosub, Zoom
Zoom_Level := 0
return

!Up::
if ( Selected_Count > 0 )
{
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
			node%v%.SpecSize := ( node%v%.SpecSize = "" ) ? ( 1 ) : ( node%v%.SpecSize + 1 )
	}
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node = 1 )
{
	Name := Node_high.name
	Symbol := Node_high.symbol
	If ( node%name%.SpecSize = "" )
		node%name%.SpecSize := 1
	else 
		node%name%.SpecSize += 1
	Prev_SpecSize := node%name%.SpecSize
	Gosub, redraw
	Gosub, redraw2
}
return
!Down::

if ( Selected_Count > 0 )
{
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
			node%v%.SpecSize := ( node%v%.SpecSize = "" ) ? ( -1 ) : ( node%v%.SpecSize - 1 )
	}
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node = 1 )If ( Match_Node = 1 )
{
	Name := Node_high.name
	Symbol := Node_high.symbol
	If ( node%name%.SpecSize = "" )
		node%name%.SpecSize := -1
	else 
		node%name%.SpecSize -= 1
	Prev_SpecSize := node%name%.SpecSize
	Gosub, redraw
	Gosub, redraw2
}
return
!left::
if ( Selected_Count > 0 )
{
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
			node%v%.SpecSize := Prev_SpecSize
	}
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node = 1 )If ( Match_Node = 1 )
{
	Name := Node_high.name
	Symbol := Node_high.symbol
	node%name%.SpecSize := Prev_SpecSize

	Gosub, redraw
	Gosub, redraw2
}
return
!right::
if ( Selected_Count > 0 )
{
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
			node%v%.SpecSize := 0
	}
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node = 1 )
{
	Name := Node_high.name
	Symbol := Node_high.symbol
	node%name%.SpecSize := 0
	Gosub, redraw
	Gosub, redraw2
}
return

;~ ROTATE
!q::
!p::
If ( A_ThisHotKey = "!q" )
	Rot_ang := -15
else
	Rot_ang := 15
box_x_mid := Box_x + (Box_w/2)
box_y_mid := Box_y + (Box_h/2)
For kr, vr in node_list
{
	If ( node%vr%.Selected = 1 )
	{
		Angle_meas := Angle_node_2(box_x_mid, box_y_mid, vr)
		Angle_rot_use := Conv_angle(Correct_angle(Angle_node_2(box_x_mid, box_y_mid, vr)+Rot_ang))
		r := Distance(box_x_mid, box_y_mid, node%vr%.x, node%vr%.y)
		Node%vr%.x := (box_x_mid+Sin(Angle_rot_use/57.2957795)*r)
		Node%vr%.y := (box_y_mid+Cos(Angle_rot_use/57.2957795)*r)
	}
}
X_Low := "", X_High := "", Y_Low := "", Y_High := ""
For kr, vr in Node_List
{
	If ( Node%vr%.Selected = 1 )
	{
		X_Low := ( X_Low = "" ) ? ( Node%vr%.x ) : ( Node%vr%.x < X_Low ) ? ( Node%vr%.x ) : ( X_Low )
		X_High := ( X_High = "" ) ? ( Node%vr%.x ) : ( Node%vr%.x > X_High ) ? ( Node%vr%.x ) : ( X_High )
		Y_Low := ( Y_Low = "" ) ? ( Node%vr%.Y ) : ( Node%vr%.Y < Y_Low ) ? ( Node%vr%.Y ) : ( Y_Low )
		Y_High := ( Y_High = "" ) ? ( Node%vr%.Y ) : ( Node%vr%.Y > Y_High ) ? ( Node%vr%.Y ) : ( Y_High )
	}
}
If ( Selected_Count > 0 )
{
	x := X_Low-10
	y := y_Low-10
	w := w_plus+(X_High-X_Low)
	h := h_plus+(Y_High-Y_Low)
	s_x := x
	s_y := y
	Box_Active := 1
	Box_x := x
	Box_y := y
	Box_w := w
	Box_h := h
}
Gosub, redraw
Gosub, redraw2
return

;~ Expand contract
/*
!e::
!c::
If ( A_ThisHotKey = "!e" )
	Scale_fac := 1.05263
else
	Scale_fac := 0.95
box_x_mid := Box_x + (Box_w/2)
box_y_mid := Box_y + (Box_h/2)
For kr, vr in node_list
{
	If ( node%vr%.Selected = 1 )
	{
		Angle_meas := Angle_node_2(box_x_mid, box_y_mid, vr)
		r := Distance(box_x_mid, box_y_mid, node%vr%.x, node%vr%.y)
		Node%vr%.x := (box_x_mid+Sin(Angle_meas/57.2957795)*r*Scale_fac)
		Node%vr%.y := (box_y_mid-Cos(Angle_meas/57.2957795)*r*Scale_fac)
	}
}
X_Low := "", X_High := "", Y_Low := "", Y_High := ""
For kr, vr in Node_List
{
	If ( Node%vr%.Selected = 1 )
	{
		X_Low := ( X_Low = "" ) ? ( Node%vr%.x ) : ( Node%vr%.x < X_Low ) ? ( Node%vr%.x ) : ( X_Low )
		X_High := ( X_High = "" ) ? ( Node%vr%.x ) : ( Node%vr%.x > X_High ) ? ( Node%vr%.x ) : ( X_High )
		Y_Low := ( Y_Low = "" ) ? ( Node%vr%.Y ) : ( Node%vr%.Y < Y_Low ) ? ( Node%vr%.Y ) : ( Y_Low )
		Y_High := ( Y_High = "" ) ? ( Node%vr%.Y ) : ( Node%vr%.Y > Y_High ) ? ( Node%vr%.Y ) : ( Y_High )
	}
}
If ( Selected_Count > 0 )
{
	x := X_Low-10
	y := y_Low-10
	w := w_plus+(X_High-X_Low)
	h := h_plus+(Y_High-Y_Low)
	s_x := x
	s_y := y
	Box_Active := 1
	Box_x := x
	Box_y := y
	Box_w := w
	Box_h := h
}
Gosub, redraw
Gosub, redraw2
return
*/
;~ vertical
^v::
Inv_vert_sub:
if ( Selected_Count > 1 )
{
	X_Low :=
	X_High :=
	Y_Low :=
	Y_High :=
	
	Mid_v := box_y+(box_h/2)
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
		{
			Node%v%.y += - 2*( Node%v%.y-Mid_v )
			
			X_Low := ( X_Low = "" ) ? ( Node%v%.x ) : ( Node%v%.x < X_Low ) ? ( Node%v%.x ) : ( X_Low )
			X_High := ( X_High = "" ) ? ( Node%v%.x ) : ( Node%v%.x > X_High ) ? ( Node%v%.x ) : ( X_High )
			Y_Low := ( Y_Low = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y < Y_Low ) ? ( Node%v%.Y ) : ( Y_Low )
			Y_High := ( Y_High = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y > Y_High ) ? ( Node%v%.Y ) : ( Y_High )
		}
	}
	x := X_Low-10
	y := y_Low-10
	w := w_plus+(X_High-X_Low)
	h := h_plus+(Y_High-Y_Low)
	s_x := x
	s_y := y
	Box_Active := 1
	Box_x := x
	Box_y := y
	Box_w := w
	Box_h := h
	MouseGetPos, MX, MY
	MX -= Global_mouse_offset_x
	MY -= Global_mouse_offset_y
	Gosub, redraw
	Gosub, redraw2
}
return

;~ horizontal
^h::
Inv_horiz_sub:
if ( Selected_Count > 1 )
{
	X_Low :=
	X_High :=
	Y_Low :=
	Y_High :=
	Mid_h := box_x+(box_w/2)
	for k, v in node_List
	{
		If ( node%v%.Selected = 1 )
		{
			Node%v%.x += - 2*( Node%v%.x-Mid_h )
			
			X_Low := ( X_Low = "" ) ? ( Node%v%.x ) : ( Node%v%.x < X_Low ) ? ( Node%v%.x ) : ( X_Low )
			X_High := ( X_High = "" ) ? ( Node%v%.x ) : ( Node%v%.x > X_High ) ? ( Node%v%.x ) : ( X_High )
			Y_Low := ( Y_Low = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y < Y_Low ) ? ( Node%v%.Y ) : ( Y_Low )
			Y_High := ( Y_High = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y > Y_High ) ? ( Node%v%.Y ) : ( Y_High )
		}
	}
	x := X_Low-10
	y := y_Low-10
	w := w_plus+(X_High-X_Low)
	h := h_plus+(Y_High-Y_Low)
	s_x := x
	s_y := y
	Box_Active := 1
	Gosub, redraw
	Gosub, redraw2
}
return

F4::
Merge_node:
Merge_List := []
Merge_List1 := []
Merge_List2 := []
Merge_List_sep := []
For k, v in node_list
{
	Outer_Index := A_Index
	Breaking := 0
	for kp, vp in Merge_List_sep
		if ( v = vp )
		{
			Breaking := 1
			Break
		}
	If ( Breaking = 1 )
		Continue
	For k2, v2 in node_list
	{
		If ( v2 = v )
			continue
		Breaking := 0
		for kp, vp in Merge_List_sep
			if ( v2 = vp )
			{
				Breaking := 1
				Break
			}
		If ( Breaking = 1 )
			Continue
		If ( Distance(node%v%.x, node%v%.y, node%v2%.x, node%v2%.y) <= Node_merge_distance )
		{
			Merge_List.Insert(v . "`," . v2)
			Merge_List1.Insert(v)
			Merge_List2.Insert(v2)
			Merge_List_sep.Insert(v2)
		}
	}
}
Merged := 0
Check_these_nodes_for_dead_nodes := []
For k, v in Merge_List
{
	StringSPlit, M_Node_, v, `,
	Node%M_Node_1%.x := ((Node%M_Node_1%.x+Node%M_Node_2%.x)/2)
	Node%M_Node_1%.y := ((Node%M_Node_1%.y+Node%M_Node_2%.y)/2)
	For kb, vb in node%M_Node_2%.PartnerList
	{
		Breaking := 0
		for kk, vv in Merge_List2
		{
			If ( vv = vb ) ;bonded to a node we are removing
			{
				Breaking := 1
				Break
			}
		}
		If ( Breaking = 1 )
			Continue
		;~ vb is the node name for parters of the node we are deleting
		node%M_Node_1%.PartnerList.Insert(vb)
		node%M_Node_1%.PartnerListType.Insert(node%M_Node_2%.PartnerListType[kb])
		node%vb%.PartnerList0.Insert(M_Node_1)
		node%vb%.PartnerList0Type.Insert(node%M_Node_2%.PartnerListType[kb])
		node%M_Node_1%.Partners ++
		Check_these_nodes_for_dead_nodes.Insert(vb)
	}
	
	For kb, vb in node%M_Node_2%.PartnerList0
	{
		Breaking := 0
		for kk, vv in Merge_List2
		{
			If ( vv = vb ) ;bonded to a node we are removing
			{
				Breaking := 1
				Break
			}
		}
		If ( Breaking = 1 )
			Continue
		;~ vb is the node name for parters of the node we are deleting
		node%M_Node_1%.PartnerList0.Insert(vb)
		node%M_Node_1%.PartnerList0Type.Insert(node%M_Node_2%.PartnerList0Type[kb])
		node%vb%.PartnerList.Insert(M_Node_1)
		node%vb%.PartnerListType.Insert(node%M_Node_2%.PartnerList0Type[kb])
		node%M_Node_1%.Partners ++
		Check_these_nodes_for_dead_nodes.Insert(vb)
	}
	Merged ++
	Kill_no :=
	Kill_name :=
	For k2, v2 in node_list
		If ( M_Node_2 = v2 )
		{
			Kill_no := k2
			Kill_name := v2
			Break
		}
	If ( Kill_no <> "" )
		node_list.remove(Kill_no),	node_count -= 1, Node%Kill_name% := []
}

For k, v in node_list
{
	Del_These :=
	for k2, v2 in node%v%.PartnerList
	{
		Matched := 0
		for k3, v3 in node_list
		{
			if ( v2 = v3 )
			{
				Matched := 1
				Break
			}
		}
		If ( Matched = 0 )
			Del_These := ( Del_These = "" ) ? ( k2  ) : ( Del_These . "`n" . k2 )
	}
	If ( Del_These <> "" )
	{
		Sort, Del_These, N R
		Loop, Parse, Del_These, `n, `r
		{
			Node%v%.PartnerList.Remove(A_LoopField)
			Node%v%.PartnerListType.Remove(A_LoopField)
		}
	}
	Del_These :=
	for k2, v2 in node%v%.PartnerList0
	{
		Matched := 0
		for k3, v3 in node_list
		{
			if ( v2 = v3 )
			{
				Matched := 1
				Break
			}
		}
		If ( Matched = 0 )
			Del_These := ( Del_These = "" ) ? ( k2 ) : ( Del_These . "`n" . k2 )
	}
	If ( Del_These <> "" )
	{
		Sort, Del_These, N R
		Loop, Parse, Del_These, `n, `r
		{
			Node%v%.PartnerList0.Remove(A_LoopField)
			Node%v%.PartnerList0Type.Remove(A_LoopField)
		}
	}
}

Gosub, Redraw
Gosub, Redraw2
Tooltip, % "Message" . "`r`n" . "Merged" . " = " . """" . Merged . """"
SetTimer, TipOff, 3000
return

TipOff:
Tooltip
return

undo_ctrla:
Selected_List := []
Selected_Count := 0
Box_Active := 0
For k,v in node_list
	Node%v%.Selected := 0
Gosub, redraw
Gosub, redraw2
return

^a::
ctrla:
Selected_Count := 0
for k, v in node_List
	node%v%.Selected := 1, Selected_Count += 1

;~ ---------------------------------------------------------------------------------------------------------------
X_low :=
X_High :=
Y_Low :=
Y_High :=
Selected_Count := 0
Selected_List := []
For k, v in Node_List
{
	If ( Node%v%.Selected = 1 )
	{
		X_Low := ( X_Low = "" ) ? ( Node%v%.x ) : ( Node%v%.x < X_Low ) ? ( Node%v%.x ) : ( X_Low )
		X_High := ( X_High = "" ) ? ( Node%v%.x ) : ( Node%v%.x > X_High ) ? ( Node%v%.x ) : ( X_High )
		Y_Low := ( Y_Low = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y < Y_Low ) ? ( Node%v%.Y ) : ( Y_Low )
		Y_High := ( Y_High = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y > Y_High ) ? ( Node%v%.Y ) : ( Y_High )
		Selected_Count ++
		Selected_List.Insert(v)
	}
}

If ( Selected_Count > 0 )
{
	x := X_Low-10
	y := y_Low-10
	w := w_plus+(X_High-X_Low)
	h := h_plus+(Y_High-Y_Low)
	s_x := x
	s_y := y
	Box_Active := 1
	Box_x := x
	Box_y := y
	Box_w := w
	Box_h := h
	MouseGetPos, MX, MY
	MX -= Global_mouse_offset_x
	MY -= Global_mouse_offset_y
}
else
{
	Box_Active := 0
}
;~ ---------------------------------------------------------------------------------------------------------------
Gosub, redraw
Gosub, redraw2

return
#IfWinActive

Bond_length_check:
If ( Zoom_Level = 0 )
{
	Default_Length := _Default_Length
	Symbol_Size := _Symbol_Size
	Symbol_gap := _Symbol_gap
}
else If ( Zoom_Level > 0 )
{
	Temp_l := _Default_Length
	Temp_s := _Symbol_Size
	Temp_g := _Symbol_Gap
	Loop, % Zoom_Level
		Temp_l := Temp_l * 1.11111111, Temp_s *= 1.11111111, Temp_g := Temp_g*1.11111111
	Default_Length := Temp_l
	Symbol_Size := Temp_s
	Symbol_gap := Temp_g
}
else
{
	StringTrimLeft, _Zoom_Level, Zoom_Level, 1
	Temp_l := _Default_Length
	Temp_s := _Symbol_Size
	Temp_g := _Symbol_Gap
	Loop, % _Zoom_Level
		Temp_l := Temp_l * 0.9, Temp_s *= 0.9, Temp_g := Temp_g*0.9
	Default_Length := Temp_l
	Symbol_Size := Temp_s
	Symbol_gap := Temp_g
}

return
Zoom:
Min_x :=
Min_y :=
_Min_x :=
_Min_y :=
For k, v in node_list
{
	Min_x := ( Min_x = "" ) ? ( Node%v%.x ) : ( Node%v%.x < Min_x ) ? ( Node%v%.x ) : ( Min_x )
	Min_y := ( Min_y = "" ) ? ( Node%v%.y ) : ( Node%v%.y < Min_y ) ? ( Node%v%.y ) : ( Min_y )
	Node%v%.x := Node%v%.x *Adj
	Node%v%.y := Node%v%.y *Adj
	_Min_x := ( _Min_x = "" ) ? ( Node%v%.x ) : ( Node%v%.x < _Min_x ) ? ( Node%v%.x ) : ( _Min_x )
	_Min_y := ( _Min_y = "" ) ? ( Node%v%.y ) : ( Node%v%.y < _Min_y ) ? ( Node%v%.y ) : ( _Min_y )
}

Diff_x := Min_x-_Min_x
Diff_y := Min_y-_Min_y
For k, v in node_list
{
	Node%v%.x := Node%v%.x +Diff_x
	Node%v%.y := Node%v%.y +Diff_y
}
Gosub, redraw
Gosub, redraw2
return

#IfWinActive ShefDraw
Esc::
Gosub, Exit
return
#IfWinActive Draw Opt
Esc::
Hotkey, NumpadEnter, R_Sub_Submit, Off
Right_on := 0
Gui, 2: Submit, nohide
Gui, 2: Destroy
SetTimer, Node_Check, on
return
#IfWinActive

Exit:
{
	Gdip_DeletePen(pPen_Lines_black)
	Gdip_DeletePen(pPen_Lines_blue)
	Gdip_DeletePen(pPen_Lines_blue1)
	Gdip_DeleteBrush(pBrush_area_fill)
	Gdip_DeleteBrush(pBrush_white)
	Gdip_DeleteBrush(pBrush_black)
	Gdip_DeleteBrush(pBrush_blue)
	Gdip_DeleteBrush(pBrush_yel_a)
	Gdip_DeleteBrush(pBrush_red)
	Gdip_DeleteBrush(pBrush_magenta)
	Gdip_DeletePen(pPen_area)
	Gdip_DeletePen(pPen_Zero_Lines)
	Gdip_DeletePen(pPen_Lines_grey)

	Gdip_DeleteGraphics(G)
	Gdip_DisposeImage(pBitmap)
	DeleteObject(hBitmap)
	
	Gdip_Shutdown(pToken)
	ExitApp
}
Return

Distance(x1, y1, x2, y2)
{
   N := (x2-x1)**2 + (y2-y1)**2
   return ( sqrt(N) )
}

R_Sub:
Hotkey, RButton, R_Sub, Off
MouseGetPos, RX, RY
RX -= Global_mouse_offset_x
RY -= Global_mouse_offset_y

If ( RX > 0 ) and ( RX < w_rect_area ) and ( RY > 0 ) and ( RY < h_rect_area )
	Within_Bounds := 1
else
	Within_Bounds := 0

WinGetPos, Win_x, Win_y, Win_w, Win_h, ShefDraw
RX += Win_x + 15
RY += Win_y + 47
SetTimer, Node_Check, off

If ( Right_on = 1 )
{
	Rx := RX_Use
	Ry := Ry_Use
	RX_USe :=
	RY_Use :=
	Gosub, R_Sub_Submit
}
else If ( match_node = 1 ) and ( Within_Bounds = 1 )
{
	Rx -= 15
	ry -= 15
	Single_Node := 0
	mx := Node_high.x, my := Node_high.y, Node_Symbol := Node_high.symbol, Node_Number := Node_high.name
	Right_on := 1
	Gui, 2: +LastFound 
	Winset, Transparent, 215
	Gui, 2: Color, AAAAAA
	Gui, 2: Font, s12 Bold
	Gui, 2: Add, Edit, x3 y3 h30 w120 vR_Sub_Text, %Node_Symbol%
	Gui, 2: -SysMenu -Caption +ToolWindow +AlwaysOnTop
	Gui, 2: Show, x%rx% y%ry% w126 h36, Draw Opt
	Hotkey, NumpadEnter, R_Sub_Submit, On
	Hotkey, Enter, R_Sub_Submit, On
	RX -= Win_x + 15
	RY -= Win_y + 47
	rx_use := rx
	ry_Use := ry
}
else If ( Within_Bounds = 1 )
{
	Rx -= 15
	ry -= 15
	Single_Node := 1
	mx := Node_high.x, my := Node_high.y, Node_Symbol := Node_high.symbol, Node_Number := Node_high.name
	Right_on := 1
	Gui, 2: +LastFound  
	Winset, Transparent, 215
	Gui, 2: Color, AAAAAA
	Gui, 2: Font, s12 Bold
	Gui, 2: Add, Edit, x3 y3 h30 w120 vR_Sub_Text, %Node_Symbol%
	Gui, 2: -SysMenu -Caption +ToolWindow +AlwaysOnTop
	Gui, 2: Show, x%rx% y%ry% w126 h36, Draw Opt
	Hotkey, NumpadEnter, R_Sub_Submit, On
	Hotkey, Enter, R_Sub_Submit, On
	RX -= Win_x + 15
	RY -= Win_y + 47
	rx_use := rx
	ry_Use := ry
}
else
	Send, {RButton}

Hotkey, RButton, R_Sub, On
return

R_Sub_Submit:
Hotkey, NumpadEnter, R_Sub_Submit, Off
Hotkey, Enter, R_Sub_Submit, Off
Gui, 2: Submit, nohide
Gui, 2: Destroy
Right_on := 0
If ( R_Sub_Text <> Node_Symbol ) and ( R_Sub_Text <> "" )
{
	If ( RegExMatch(R_Sub_Text,"i)(\d+)c", Num) <> 0 )
	{
		Gosub, 5c_add
	}
	else if ( RegexMatch(R_Sub_Text, "i)debug\s?([off|on|\d])", Cap ) <> 0 )
	{
		If ( Cap1 = "on" )
			Cap1 := 1
		else if ( cap1 = "off" )
			Cap1 := 0
		Debug := Cap1
	}
	else If ( Single_Node = 0 )
		Node%Node_Number%.Symbol := R_Sub_Text,	Node%Node_Number%.Display := 1
	else
	{
		{
			Node_Count ++
			Node_Count_nosub ++
			Node%Node_Count_nosub% := []
			Node%Node_Count_nosub%.x := RX+15
			Node%Node_Count_nosub%.y := RY+15
			Node%Node_Count_nosub%.Symbol := R_Sub_Text
			Node%Node_Count_nosub%.Display := 1
			Node%Node_Count_nosub%.Selected := 0
			Node%Node_Count_nosub%.SpecSize := 0
			Node%Node_Count_nosub%.Colour := 1
			Node%Node_Count_nosub%.Partners := 0
			Node%Node_Count_nosub%.PartnerList := []
			Node%Node_Count_nosub%.PartnerListType := []
			Node%Node_Count_nosub%.PartnerList0 := []
			Node%Node_Count_nosub%.PartnerList0Type := []
			Node_List.Insert(Node_Count_nosub)
		}
	}
	Gosub, redraw
	Gosub, redraw2
}
else if ( R_Sub_Text = "" )
{
	If ( Single_Node = 0 )
		Node%Node_Number%.Symbol := "C", Node%Node_Number%.Display := 0

	Gosub, redraw
	Gosub, redraw2
}
SetTimer, Node_Check, on
Hotkey, ^LButton, Del_Sub, On
return

Angle_node(node_name_1, node_name_2)
{
	A := (ACos(Distance(Node%node_name_1%.x, Node%node_name_1%.y, Node%node_name_1%.x, Node%node_name_2%.y)/Distance(Node%node_name_1%.x, Node%node_name_1%.y, Node%node_name_2%.x, Node%node_name_2%.y))) *57.2957795
	m := -1*((Node%node_name_1%.y-Node%node_name_2%.y)/(Node%node_name_1%.x-Node%node_name_2%.x))
	If ( m < 0 )
		A := ( 90-A)+90
	If ( Node%node_name_1%.x > Node%node_name_2%.x)
		A := 180+A
	If ( Node%node_name_1%.y > Node%node_name_2%.y) and ( m = "" )
		A := 0
	Return A
}
Angle_node_2(pointx, pointy, node_name_2)
{
	A := (ACos(Distance(pointx, pointy, pointx, Node%node_name_2%.y)/Distance(pointx, pointy, Node%node_name_2%.x, Node%node_name_2%.y))) *57.2957795
	m := -1*((pointy-Node%node_name_2%.y)/(pointx-Node%node_name_2%.x))
	If ( m < 0 )
		A := ( 90-A)+90
	If ( pointx > Node%node_name_2%.x)
		A := 180+A
	If ( pointy > Node%node_name_2%.y) and ( m = "" )
		A := 0
	Return A
}

Conv_Angle(A)
{
	Return ( A > 180) ? ( -1*a+540 ) : ( -1*a+180 )
}
Correct_angle(a)
{
	return ( a>=360) ? ( Mod(a,360) ) : ( a < 0 ) ? ( 360 + a ) : ( a )
}

5c_add:
{
	A_Step := 360/Num1
	if ( Selected_Count = 2 ) ;have two selected nodes, make them 2 out of the x
	{
		A_m := Angle_Node(Selected_List[2],Selected_List[1])
		A_m := Conv_angle(A_m)
		Step1 := ((360/Num1)) 
		Node1_name := Selected_List[2]
		Node2_name := Selected_List[1]
		A_s :=
		If ( Node%node1_name%.Partners > 1 )
		{
			For k, v in Node%node1_name%.PartnerList
			{
				If ( v = node2_name )
					Continue
				A_s := Conv_angle(Angle_Node(node1_name, v))
			}
			If ( A_s = "" )
			{
				For k, v in Node%node1_name%.PartnerList0
				{
					If ( v = node2_name )
						Continue
					A_s := Conv_angle(Angle_Node(node1_name, v))
				}
			}
			A_Range := Correct_angle(A_s - A_m)
			If ( A_Range >= 180 )
				Step1 := -1*Step1
			A := A_m+Step1+180
			A := ( A>=360) ? ( Mod(A,360) ) : ( A < 0 ) ? ( 360 + A ) : ( A )
			A := A/57.2957795
		}
		else if ( Node%node2_name%.Partners > 1 )
		{
			For k, v in Node%node2_name%.PartnerList
			{
				If ( v = node1_name )
					Continue
				A_s := Conv_angle(Angle_Node(node2_name, v))
			}
			If ( A_s = "" )
			{
				For k, v in Node%node2_name%.PartnerList0
				{
					If ( v = node1_name )
						Continue
					A_s := Conv_angle(Angle_Node(node2_name, v))
				}
			}
			A_Range := Correct_angle(A_s - A_m)
			If ( A_Range >= 180 )
				Step1 := -1*Step1
			A := A_m+Step1+180
			A := ( A>=360) ? ( Mod(A,360) ) : ( A < 0 ) ? ( 360 + A ) : ( A )
			A := A/57.2957795
		}
		else
		{
			A := A_m+Step1+180
			A := ( A>=360) ? ( Mod(A,360) ) : ( A < 0 ) ? ( 360 + A ) : ( A )
			A := A/57.2957795
		}
		xp := Node%Node1_name%.x
		yp := Node%Node1_name%.y
		Node%Node1_name%.Partners ++
		Node%Node1_name%.PartnerList.Insert(Node_Count_nosub+1)
		Node%Node1_name%.PartnerListType.Insert(1)
		Loop, % Num1-2
		{
			;~ 2
			Node_Count ++
			Prev_Node_no := (A_Index = 1 ) ? ( Node1_name ) : ( Node_Count_nosub )
			To_node_no := (A_Index = Num1-2 ) ? ( Node2_Name ) : ( Node_Count_nosub+2 )
			If ( A_Index > 1 )
			{
				A := A*57.2957795
				A := A+Step1
				A := ( A>=360) ? ( Mod(A,360) ) : ( A < 0 ) ? ( 360 + A ) : ( A )
				A := A/57.2957795
			}
			Node_Count_nosub ++
			Node%Node_Count_nosub% := []
			Node%Node_Count_nosub%.x := xp := (xp+Sin(a)*Default_Length)
			Node%Node_Count_nosub%.y := yp := (yp+Cos(a)*Default_Length)
			Node%Node_Count_nosub%.Symbol := "C"
			Node%Node_Count_nosub%.Display := 0
			Node%Node_Count_nosub%.Selected := 0
			Node%Node_Count_nosub%.SpecSize := 0
			Node%Node_Count_nosub%.Colour := 1
			Node%Node_Count_nosub%.Partners := 2
			Node%Node_Count_nosub%.PartnerList := []
			Node%Node_Count_nosub%.PartnerListType := []
			Node%Node_Count_nosub%.PartnerList0 := []
			Node%Node_Count_nosub%.PartnerList0Type := []
			Node%Node_Count_nosub%.PartnerList.Insert(To_node_no)
			Node%Node_Count_nosub%.PartnerListType.Insert(1)
			Node%Node_Count_nosub%.PartnerList0.Insert(Prev_Node_no)
			Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
			Node_List.Insert(Node_Count_nosub)
		}
		;~ last
		Node%Node2_name%.Partners ++
		Node%Node2_name%.PartnerList0.Insert(Node_Count_nosub)
		Node%Node2_name%.PartnerList0Type.Insert(1)
		Box_Active := 0
		For k, v in Node_List
			Node%v%.Selected := 0
		Selected_Count := 0
		Hotkey, RButton, R_Sub, On
		return
	}
	else If ( Single_Node = 1 ) ;adding untethered
	{
		A := 54 /57.2957795
		If ( mod(num1,2) <> 0 )
			A := (0.75*(360/Num1)) /57.2957795
		else
			A := ((360/Num1)) /57.2957795
		Node_Count ++
		Node_Count_nosub ++
		Node_Start_Name := Node_Count_nosub
		xp := RX+15
		yp := RY+15
		;~ ---------------------------------------------------------------------------------------------------------------
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := xp
		Node%Node_Count_nosub%.y := yp
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 2
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList.Insert(Node_Count_nosub+1)
		Node%Node_Count_nosub%.PartnerListType.Insert(1)
		Node%Node_Count_nosub%.PartnerList0.Insert(Node_Count_nosub+Num1-1)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
	}
	else if ( Match_Node = 1 )
	{
		Node_Start_Name := Node_high.name
		If ( Node%Node_Start_Name%.Partners > 1 )
			return
		xp := Node_high.x ;:= Node%v%.x
		yp := Node_high.y ;:= Node%v%.y
		
		Partner_Name :=
		For k, v in Node%Node_Start_Name%.PartnerList
			Partner_Name := v
		If ( Partner_Name = "" )
			For k, v in Node%Node_Start_Name%.PartnerList0
				Partner_Name := v

		A := Conv_Angle(Angle_node(Node_Start_Name, Partner_Name))
		A_offset := (360-(180-A_Step))/2
		A -= A_Offset
		A := Correct_Angle(A)
		A := A /57.2957795
		Node%Node_Start_Name%.Partners += 2
		Node%Node_Start_Name%.PartnerList.Insert(Node_Count_nosub+1)
		Node%Node_Start_Name%.PartnerListType.Insert(1)
		Node%Node_Start_Name%.PartnerList0.Insert(Node_Count_nosub+Num1-1)
		Node%Node_Start_Name%.PartnerList0Type.Insert(1)
	}
	else
		return
	
	Loop, % Num1-1
	{
		;~ 2
		Node_Count ++
		Prev_Node_no := (A_Index = 1 ) ? ( Node_Count_nosub ) : ( Node_Count_nosub )
		To_node_no := (A_Index = Num1-1 ) ? ( Node_Start_Name ) : ( Node_Count_nosub+2 )
		If ( A_Index > 1 )
		{
			A := A*57.2957795
			A := A-A_Step
			A := ( A>=360) ? ( Mod(A,360) ) : ( A < 0 ) ? ( 360 + A ) : ( A )
			A := A/57.2957795
		}
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := xp := (xp+Sin(a)*Default_Length)
		Node%Node_Count_nosub%.y := yp := (yp+Cos(a)*Default_Length)
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 2
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList.Insert(To_node_no)
		Node%Node_Count_nosub%.PartnerListType.Insert(1)
		Node%Node_Count_nosub%.PartnerList0.Insert(Prev_Node_no)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
	}
	Gosub, redraw
	Gosub, redraw2
}
return

#If ( Click_Legit = 1 )
~LButton::
IfWinNotActive, ShefDraw
	return

Sleep, 120
MouseGetPos, mX, mY
MX -= Global_mouse_offset_x
MY -= Global_mouse_offset_y
mX2_p :=
mY2_p :=
From := 0, To := 0
Main_sub_on := 1

If ( Right_on = 1 ) and ( WinActive("Draw opt") = 0 )
{
	Right_on = 0
	Gui, 2: Destroy
	SetTimer, Node_Check, on
	Main_sub_on := 0
	return
}

If ( mx > 0 ) and ( mx < w_rect_area ) and ( my > 0 ) and ( my<h_rect_area )
	Within_Bounds := 1
else
{
	Within_Bounds := 0
	Main_sub_on := 0
	Return
}

If ( Box_Active = 1 ) and ( GetKeyState("LButton") <> 1 ) ;clicked outside our drawn box
{
	If ( mx < box_x ) or ( mx > Box_x+Box_w ) or ( my < Box_y ) or ( my > Box_y+Box_h )
	{
		Box_Active := 0
		Selected_Count := 0
		For k, v in Node_List
			Node%v%.Selected := 0
		Gosub, redraw
		Gosub, redraw2
		Main_sub_on := 0
		return
	}
}
else If ( Box_Active = 1 ) ;and 
{
	If ( mx < box_x ) or ( mx > Box_x+Box_w ) or ( my < Box_y ) or ( my > Box_y+Box_h )
	{
		Box_Active := 0
		Selected_Count := 0
		For k, v in Node_List
			Node%v%.Selected := 0
		Gosub, redraw
		Gosub, redraw2
		Main_sub_on := 0
		return
	}
	Move_MX := MX
	Move_MY := MY
	Gosub, drag_box
	Main_sub_on := 0
	Return
}
If ( GetKeyState("LButton") <> 1 ) and ( match_node = 1 ) and ( right_on = 0 )
{
	From := 1
	Gosub, Spawn
	Main_sub_on := 0
	return
}

If ( Match_Node = 1 )
{
	mx := Node_high.x, my := Node_high.y, Connect_from_name := Node_high.name, From := 1
}
else if ( Match_Node = 2 )
{
	Gosub, Hover_bond_0
	Main_sub_on := 0
	return
}
else
	From := 0

Gosub, Hover_node_0
Main_sub_on := 0
return
#If

Hover_node_0:
In_Process := 1
Accepting_Nodes := 0
mx1 := mx
my1 := my
Loop
{
	If ( GetKeyState("LButton") <> 1 )
	{
		break
	}
	To := 0
	MouseGetPos, mX2, mY2
	MX2 -= Global_mouse_offset_x
	MY2 -= Global_mouse_offset_y
	mx2_r := mx2
	my2_r := my2
	
	If ( Match_Node = 1 ) and ( Node_high.name <> Connect_from_name )
		To := 1
	
	If ( mX2 = mX2_p ) and ( mY2 = mY2_p ) ;not changed since last time
	{
		Sleep 200
		Continue
	}
	else If ( distance(mx1, my1, mx2, my2) < 10 ) 
	{
		Accepting_Nodes := 0
		Gosub, Redraw
		Gdip_FillEllipse(G, pBrush_black, mx-3, my-3, 6, 6)
		Gosub, redraw2
	}
	else if ( To = 1 ) 
	{
		Accepting_Nodes := 1
		Gosub, Redraw
		mx2 := Node_high.x, my2 := Node_high.y, Connect_to_name := Node_high.name
		mX2_ := (mx2), mY2_ := (My2)
		Gosub, redraw2
	}
	else ;line required
	{
		Accepting_Nodes := 1
		Gosub, Redraw
		Sep := Distance(MX1, MY1, MX2, MY2)
		If ( Distance <> Default_Length )
		{
			If ( mx1 = mx2 )
			{
				If ( my1 > my2 )
					my2 := my1-Default_Length
				else
					my2 := my1+Default_Length
			}
			else if ( my1 = my2 )
			{
				If ( mx1 > mx2 )
					mx2 := mx1-Default_Length
				else
					mx2 := mx1+Default_Length
			}
			else
			{
				A := (ACos(Distance(mx1, my1, mx1, my2)/Distance(mx1, my1, mx2, my2))) ;*57.2957795
				Loop, Parse, Snap_angle_list, `,
				{
					If ( Abs(A*57.2957795-A_LoopField) < Snap_angle )
					{
						A :=A_LoopField/57.2957795
						Break
					}
				}

				If ( mx2 > mx1 ) and ( my2 > my1 )
				{
					MX2 := MX1+Sin(a)*Default_Length ;b
					MY2 := MY1+Cos(a)*Default_Length  ;a
				}
				else if ( mx2 < mx1 ) and ( my2 > my1 )
				{
					MX2 := MX1-Sin(a)*Default_Length ;b
					MY2 := MY1+Cos(a)*Default_Length  ;a
				}
				else if ( mx2 > mx1 ) and ( my2 < my1 )
				{
					MX2 := MX1+Sin(a)*Default_Length ;b
					MY2 := MY1-Cos(a)*Default_Length  ;a
				}
				else
				{
					MX2 := MX1-Sin(a)*Default_Length ;b
					MY2 := MY1-Cos(a)*Default_Length  ;a
				}
			}
			Gdip_DrawLine(G, pPen_Lines_black, mX1 := (mx1), mY1 := (my1), mX2_ := (mx2), mY2_ := (My2))
		}
		Gosub, redraw2
	}
	
	mX2_p := mX2_r
	mY2_p := mY2_r
	Sleep 20
}

If ( Accepting_Nodes = 1 )
{
	If ( From = 0 ) and ( to = 0 ) ;new to new
	{
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := Mx1
		Node%Node_Count_nosub%.y := my1
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList.Insert(Node_Count_nosub+1)
		Node%Node_Count_nosub%.PartnerListType.Insert(1)

		Node_List.Insert(Node_Count_nosub)
		
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := Mx2_
		Node%Node_Count_nosub%.y := my2_
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList0.Insert(Node_Count_nosub-1)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
	}
	else if ( from = 1 ) and ( to = 0 ) ;from an existing node to a blank
	{
		Node%Connect_from_name%.Partners += 1
		Node%Connect_from_name%.PartnerList.Insert(Node_Count_nosub+1)
		Node%Connect_from_name%.PartnerListType.Insert(1)
		
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := Mx2_
		Node%Node_Count_nosub%.y := my2_
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList0.Insert(Connect_from_name)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
	}
	else if ( from = 0 ) and ( to = 1 )
	{
		Node%Connect_to_name%.Partners += 1
		Node%Connect_to_name%.PartnerList0.Insert(Node_Count_nosub+1)
		Node%Connect_to_name%.PartnerList0Type.Insert(1)
		
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := Mx1
		Node%Node_Count_nosub%.y := my1
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList.Insert(Connect_to_name)
		Node%Node_Count_nosub%.PartnerListType.Insert(1)
		Node_List.Insert(Node_Count_nosub)
	}
	else if ( from = 1 ) and ( to = 1 )
	{
		Node%Connect_to_name%.Partners += 1
		Node%Connect_to_name%.PartnerList0.Insert(Connect_from_name)
		Node%Connect_to_name%.PartnerList0Type.Insert(1)
		
		Node%Connect_from_name%.Partners += 1
		Node%Connect_from_name%.PartnerList.Insert(Connect_to_name)
		Node%Connect_from_name%.PartnerListType.Insert(1)
	}
}
From := 0, To := 0
Gosub, redraw
Gosub, redraw2

If ( Node_Count > 1 )
{
	Hotkey, ^LButton, Del_Sub, On
}
else
{
	Hotkey, ^LButton, Del_Sub, Off
}

In_Process := 0
return

Spawn:
name := Node_high.name
If ( Node%name%.Partners > 0 )
{
	Partner_Count := 0
	For k, v in Node%name%.PartnerList
	{
		Partner_Count ++
		A := (ACos(Distance(Node%name%.x, Node%name%.y, Node%name%.x, Node%v%.y)/Distance(Node%name%.x, Node%name%.y, Node%v%.x, Node%v%.y))) *57.2957795
		m := -1*((Node%name%.y-Node%v%.y)/(Node%name%.x-Node%v%.x))
		If ( m < 0 )
			A := ( 90-A)+90
		If ( Node%name%.x > Node%v%.x)
			A := 180+A
		If ( Node%name%.y > Node%v%.y) and ( m = "" )
			A := 0
		A%Partner_Count% := A
	}
	For k, v in Node%name%.PartnerList0
	{
		Partner_Count ++
		A := (ACos(Distance(Node%name%.x, Node%name%.y, Node%name%.x, Node%v%.y)/Distance(Node%name%.x, Node%name%.y, Node%v%.x, Node%v%.y))) *57.2957795
		m := -1*((Node%name%.y-Node%v%.y)/(Node%name%.x-Node%v%.x))
		If ( m < 0 )
			A := ( 90-A)+90
		If ( Node%name%.x > Node%v%.x)
			A := 180+A
		If ( Node%name%.y > Node%v%.y) and ( m = "" )
			A := 0
		A%Partner_Count% := A
	}
	
	If ( Node%name%.Partners = 1 )
	{
		A := ( A > 180) ? ( -1*a+540 ) : ( -1*a+180 )
		A := ( m <= 0 ) ? ( A-120 ) : ( A+120)
		A := ( A < 0 ) ? ( A + 360 ) : ( A )
		A := A/57.2957795
		
		If ( A = "" )
			Return
		Node%name%.Partners += 1
		Node%name%.PartnerList.Insert(Node_Count_nosub+1)
		Node%name%.PartnerListType.Insert(1)
		
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []

		Node%Node_Count_nosub%.x := (Node%name%.x+Sin(a)*Default_Length)
		Node%Node_Count_nosub%.y := (Node%name%.y+Cos(a)*Default_Length)
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList0.Insert(name)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
		Gosub, redraw
		Gosub, redraw2

	}
	else if ( Node%name%.Partners = 2 )
	{
		A1 := ( A1 > 180) ? ( -1*a1+540 ) : ( -1*a1+180 )
		A2 := ( A2 > 180) ? ( -1*a2+540 ) : ( -1*a2+180 )
		If ( A1 > A2 ) 
			Swap(A1, A2)
		
		A := ( a2-a1 > (a1+360)-a2 ) ? ( (a2+a1)/2 ) : ( Mod(((a2+a1)/2)+180,360))
		A := A/57.2957795
		If ( A = "" )
			Return
		Node%name%.Partners += 1
		Node%name%.PartnerList.Insert(Node_Count_nosub+1)
		Node%name%.PartnerListType.Insert(1)
		
		Node_Count ++
		Node_Count_nosub ++
		Node%Node_Count_nosub% := []
		Node%Node_Count_nosub%.x := (Node%name%.x+Sin(a)*Default_Length)
		Node%Node_Count_nosub%.y := (Node%name%.y+Cos(a)*Default_Length)
		Node%Node_Count_nosub%.Symbol := "C"
		Node%Node_Count_nosub%.Display := 0
		Node%Node_Count_nosub%.Selected := 0
		Node%Node_Count_nosub%.SpecSize := 0
		Node%Node_Count_nosub%.Colour := 1
		Node%Node_Count_nosub%.Partners := 1
		Node%Node_Count_nosub%.PartnerList := []
		Node%Node_Count_nosub%.PartnerListType := []
		Node%Node_Count_nosub%.PartnerList0 := []
		Node%Node_Count_nosub%.PartnerList0Type := []
		Node%Node_Count_nosub%.PartnerList0.Insert(name)
		Node%Node_Count_nosub%.PartnerList0Type.Insert(1)
		Node_List.Insert(Node_Count_nosub)
		Gosub, redraw
		Gosub, redraw2
	}
}
return

Hover_bond_0:
Node%Bond_from_name%.PartnerListType[Bond_from_position] := ( Floor(Node%Bond_from_name%.PartnerListType[Bond_from_position]+1) < Max_bond_no+1 ) ? ( Floor(Node%Bond_from_name%.PartnerListType[Bond_from_position]+1) ) : ( 1 )
Node%Bond_to_name%.PartnerList0Type[Bond_to_position] := ( Floor(Node%Bond_to_name%.PartnerList0Type[Bond_to_position]+1) < Max_bond_no+1 ) ? ( Floor(Node%Bond_to_name%.PartnerList0Type[Bond_to_position]+1) ) : ( 1 )
Gosub, redraw
Gosub, redraw2
return

#IfWinActive, ShefDraw
MButton::
If ( Match_Node <> 2 )
	return
In_Process := 3
SetTimer, Node_Check, Off

MouseGetPos, RX, RY
RX -= Global_mouse_offset_x
RY -= Global_mouse_offset_y

If ( RX > 0 ) and ( RX < w_rect_area ) and ( RY > 0 ) and ( RY<h_rect_area )
	Within_Bounds := 1
else
	Within_Bounds := 0

If ( within_bounds = 0 )
{
	In_Process := 0
	Send, {MButton}
	SetTimer, Node_Check, On
	return
}
else If ( Match_Node = 2 ) ;Break bond
{
	For k, v in Node%Bond_from_name%.PartnerList
	{
		If ( v = Bond_to_name )
		{
			Node%Bond_from_name%.PartnerListType[Bond_from_position] := ( Node%Bond_from_name%.PartnerListType[Bond_from_position] >= Max_bond_type ) ? ( 1 ) : ( Node%Bond_from_name%.PartnerListType[Bond_from_position] + 0.1 )
			Node%Bond_from_name%.PartnerListType[Bond_from_position] := RegExReplace(Node%Bond_from_name%.PartnerListType[Bond_from_position], "D)0+$")
			break
		}
	}
	For k, v in Node%Bond_to_name%.PartnerList0
	{
		If ( v = Bond_from_name )
		{
			Node%Bond_from_name%.PartnerList0Type[Bond_from_position] := ( Node%Bond_from_name%.PartnerList0Type[Bond_from_position] >= Max_bond_type ) ? ( 1 ) : ( Node%Bond_from_name%.PartnerList0Type[Bond_from_position] + 0.1 )
			break
		}
	}
	Gosub, redraw
	Gosub, redraw2
}
In_Process := 0
SetTimer, Node_Check, On
return

#If
#If ( Match_Node = 1 )
+LButton::
Selected_List := []
If ( A_TickCount - Last_Click  < 350 ) and ( Match_Node = 1 ) ;350ms double click
{
	Name := Node_high.name
	For k, v in Node_List
	{
		Node%v%.MultiSelect := 0
	}
	Node%Name%.Selected := 1
	Node%Name%.MultiSelect := 0
	Mult_Select_List := []
	
	For k, v in Node%name%.PartnerList
		Mult_Select_List.Insert(v)
	For k, v in Node%name%.PartnerList0
		Mult_Select_List.Insert(v)

	While  ( Mult_Select_List.MaxIndex() > 0 )
	{
		New_Mult_Select_List := []
		For k, v in Mult_Select_List
		{
			Node%v%.MultiSelect := 1
			Node%v%.Selected := 1
			
			For k2, v2 in Node%v%.PartnerList
				If ( Node%v2%.MultiSelect = 0 )
					New_Mult_Select_List.Insert(v2)
			For k2, v2 in Node%v%.PartnerList0
				If ( Node%v2%.MultiSelect = 0 )
					New_Mult_Select_List.Insert(v2)
		}
		Mult_Select_List := []
		Mult_Select_List := New_Mult_Select_List.Clone()
	}
	
	For k, v in Node_List
		Node%v%.MultiSelect := 0
;~ ---------------------------------------------------------------------------------------------------------------
	X_low :=
	X_High :=
	Y_Low :=
	Y_High :=
	Selected_Count := 0
	Selected_List := []
	For k, v in Node_List
	{
		If ( Node%v%.Selected = 1 )
		{
			X_Low := ( X_Low = "" ) ? ( Node%v%.x ) : ( Node%v%.x < X_Low ) ? ( Node%v%.x ) : ( X_Low )
			X_High := ( X_High = "" ) ? ( Node%v%.x ) : ( Node%v%.x > X_High ) ? ( Node%v%.x ) : ( X_High )
			Y_Low := ( Y_Low = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y < Y_Low ) ? ( Node%v%.Y ) : ( Y_Low )
			Y_High := ( Y_High = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y > Y_High ) ? ( Node%v%.Y ) : ( Y_High )
			Selected_Count ++
			Selected_List.Insert(v)
		}
	}
	If ( Selected_Count > 0 )
	{
		x := X_Low-10
		y := y_Low-10
		w := w_plus+(X_High-X_Low)
		h := h_plus+(Y_High-Y_Low)
		s_x := x
		s_y := y
		Box_Active := 1
		Box_x := x
		Box_y := y
		Box_w := w
		Box_h := h
		MouseGetPos, MX, MY
		MX -= Global_mouse_offset_x
		MY -= Global_mouse_offset_y
	}
	else
		Box_Active := 0
	
	Gosub, redraw
	Gosub, redraw2
;~ ---------------------------------------------------------------------------------------------------------------
}
else If ( Match_Node = 1 )
{
	Name := Node_high.name
	X_low :=
	X_High :=
	Y_Low :=
	Y_High :=
	Selected_Count := 0
	For k, v in Node_List
	{
		If ( v = name )
			Node%v%.Selected := ( Node%v%.Selected = 1 ) ? ( 0 ) : ( 1 )
		
		If ( Node%v%.Selected = 1 )
		{
			X_Low := ( X_Low = "" ) ? ( Node%v%.x ) : ( Node%v%.x < X_Low ) ? ( Node%v%.x ) : ( X_Low )
			X_High := ( X_High = "" ) ? ( Node%v%.x ) : ( Node%v%.x > X_High ) ? ( Node%v%.x ) : ( X_High )
			Y_Low := ( Y_Low = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y < Y_Low ) ? ( Node%v%.Y ) : ( Y_Low )
			Y_High := ( Y_High = "" ) ? ( Node%v%.Y ) : ( Node%v%.Y > Y_High ) ? ( Node%v%.Y ) : ( Y_High )
			Selected_Count ++
			Selected_List.Insert(v)
		}
	}
	
	If ( Selected_Count > 0 )
	{
		x := X_Low-10
		y := y_Low-10
		w := w_plus+(X_High-X_Low)
		h := h_plus+(Y_High-Y_Low)
		s_x := x
		s_y := y
		Box_Active := 1
		Box_x := x
		Box_y := y
		Box_w := w
		Box_h := h
	}
	else
		Box_Active := 0
	
	Gosub, redraw
	Gosub, redraw2
}
else
	Send +{LButton}
Last_Click := A_TickCount
return

#If

Del_Sub:
Hotkey, ^LButton, Del_Sub, Off
In_Process := 2
SetTimer, Node_Check, Off
MouseGetPos, RX, RY
RX -= Global_mouse_offset_x
RY -= Global_mouse_offset_y

If ( RX > 0 ) and ( RX < w_rect_area ) and ( RY > 0 ) and ( RY<h_rect_area )
	Within_Bounds := 1
else
	Within_Bounds := 0

If ( Match_Node = 1 )
{
	Name := Node_high.name
	Node_high := []
	Node_Count -= 1
	For k, v in Node_List
	{
		If ( Name = v)
		{
			Num := K
			Break
		}
	}
	Node_list_remove_List :=
	Node_list_remove_List := ( Node_list_remove_List = "" ) ? ( Name ) : ( Node_list_remove_List . "," . Name )
	Node%Name% := []
	Node%Name%.Partners := 1
	Node%Name%.PartnerList := []
	Node%Name%.PartnerListType := []
	Node%Name%.PartnerList0 := []
	Node%Name%.PartnerList0Type := []

	For k, v in Node_List ;check all nodes
	{
		If ( v = name )
			Continue
		For k2, v2 in Node%v%.PartnerList ; do they bond to our previously deleted node
		{
			If ( v2 = name )
			{
				Node%v%.PartnerList.Remove(k2)
				Node%v%.PartnerListType.Remove(k2)
				Node%v%.Partners -= 1
				If ( Node%v%.Partners = 0 ) and ( Node%v%.Display = 0 ) ;node has no partners left, remove
				{
					t_name := v
					Node%t_name% := []
					Node_list_remove_List := ( Node_list_remove_List = "" ) ? ( v ) : ( Node_list_remove_List . "," . v )
					Node_Count -= 1
				}
			}
		}
		For k2, v2 in Node%v%.PartnerList0 ; do they bond to our previously deleted node
		{
			If ( v2 = name )
			{
				Node%v%.PartnerList0.Remove(k2)
				Node%v%.PartnerList0Type.Remove(k2)
				Node%v%.Partners -= 1
				If ( Node%v%.Partners = 0 ) and ( Node%v%.Display = 0 ) ;node has no partners left, remove
				{
					t_name := v
					Node%t_name% := []
					Node_list_remove_List := ( Node_list_remove_List = "" ) ? ( v ) : ( Node_list_remove_List . "," . v )
					Node_Count -= 1
				}
			}
		}
	}
	Loop, Parse, Node_list_remove_List, `,
	{
		For k, v in Node_List
		{
			If ( v = A_Loopfield )
			{
				Num := K
				Break
			}
		}
		Node_List.Remove(Num)
	}
	Gosub, Node_Check_reset
	Gosub, redraw
	Gosub, redraw2
}
else if ( Match_Node = 2 ) ;Break bond
{
	Node_list_remove_List :=
	For k, v in Node%Bond_from_name%.PartnerList
	{
		If ( v = Bond_to_name )
		{
			Node%Bond_from_name%.PartnerList.Remove(k)
			Node%Bond_from_name%.PartnerListType.Remove(k)
			Node%Bond_from_name%.Partners -= 1
			;---------------------------------------------------------------------------------------------------------------
			If ( Node%Bond_from_name%.Partners = 0 ) and ( Node%Bond_from_name%.Display = 0 ) ;node has no partners left, remove
			{
				t_name := Bond_from_name
				Node%t_name% := []
				Node_list_remove_List := ( Node_list_remove_List = "" ) ? ( Bond_from_name ) : ( Node_list_remove_List . "," . Bond_from_name )
				Node_Count -= 1
			}
				;---------------------------------------------------------------------------------------------------------------
			break
		}
	}
	For k, v in Node%Bond_to_name%.PartnerList0
	{
		If ( v = Bond_from_name )
		{
			Node%Bond_to_name%.PartnerList0.Remove(k)
			Node%Bond_to_name%.PartnerList0Type.Remove(k)
			Node%Bond_to_name%.Partners -= 1
			;---------------------------------------------------------------------------------------------------------------
			If ( Node%Bond_to_name%.Partners = 0 ) and ( Node%Bond_to_name%.Display = 0 ) ;node has no partners left, remove
			{
				t_name := Bond_to_name
				Node%t_name% := []
				Node_list_remove_List := ( Node_list_remove_List = "" ) ? ( Bond_to_name ) : ( Node_list_remove_List . "," . Bond_to_name )
				Node_Count -= 1
			}
			;---------------------------------------------------------------------------------------------------------------
			break
		}
	}
	Loop, Parse, Node_list_remove_List, `,
	{
		For k, v in Node_List
		{
			If ( v = A_Loopfield )
			{
				Num := K
				Break
			}
		}
		Node_List.Remove(Num)
	}
	Gosub, Node_Check_reset
	Gosub, redraw
	Gosub, redraw2
}
else if ( Within_Bounds = 0 )
	Send ^{LButton}
In_Process := 0
SetTimer, Node_Check, On
Hotkey, ^LButton, Del_Sub, On
return

#if ( Match_Node = 1 ) and ( Right_on = 0 )
c::
n::
o::
f::
h::
b::
s::
p::
r::
x::
i::
Name := Node_high.name
StringUpper, Symbol, A_ThisHotkey
Node%Name%.Display := 1
Node%Name%.Symbol := Symbol
Gosub, redraw
Gosub, redraw2
return

!r::
Name := Node_high.name
Symbol := "R'"
Node%Name%.Display := 1
Node%Name%.Symbol := Symbol
Gosub, redraw
Gosub, redraw2
return

!c::
Name := Node_high.name
Symbol := "Cl"
Node%Name%.Display := 1
Node%Name%.Symbol := Symbol
Gosub, redraw
Gosub, redraw2
return

!b::
Name := Node_high.name
Symbol := "Br"
Node%Name%.Display := 1
Node%Name%.Symbol := Symbol
Gosub, redraw
Gosub, redraw2
return

#if

Node_Check_reset:
Node_high := []
Match_Node := 0
Bond_from_name :=
Bond_from_position :=
Bond_to_name :=
return

Node_Check:
SetTimer, Node_Check, off
If ( node_Count = 0 ) or ( Dragging_select=1 )
{
	SetTimer, Node_Check, On
	return
}	
MouseGetPos, Hover_x, Hover_y
Hover_X -= Global_mouse_offset_x
Hover_Y -= Global_mouse_offset_y
Prev_match_Node := ( Prev_match_Node = "" ) ? ( 0 ) : ( Match_Node )
Matched := 0
For k, v in Node_List
{	
	If ( Distance(Hover_x, Hover_y, Node%v%.x, Node%v%.y) <= Snap_Node )
	{
		Match_Node := 1
		Node_high.x := Node%v%.x
		Node_high.y := Node%v%.y
		Node_high.name := v
		Node_high.symbol := Node%v%.Symbol
		Matched := 1
		break
	}
}
;~ ---------------------------------------------------------------------------------------------------------------

If ( Matched = 0 ) and ( main_sub_on <> 1 ) 
{
	For k, v in Node_List
	{
		For k2, v2 in Node%v%.PartnerList
		{
			If ( Distance(Bond_Highx := (Node%v%.x+Node%v2%.x)/2, Bond_Highy := (Node%v%.y+Node%v2%.y)/2, Hover_x, Hover_y) <= Snap_Node )
			{
				Bond_from_name := v
				Bond_from_position := k2
				Bond_to_name := v2
				
				For k3, v3 in Node%v2%.PartnerList0
				{
					If ( v3 = v )
					{
						Bond_to_position := K3
						Break
					}
				}
				Matched := 1
				Match_Node := 2
				Node_high.x := Bond_Highx, Node_high.y := Bond_Highy
			}
			
			If ( Matched = 1 )
				break
		}
		If ( Matched = 1 )
			break
	}
}
If ( Matched = 0 )
{
	Match_Node := 0
}
;~ ---------------------------------------------------------------------------------------------------------------
If ( Match_Node = 0 ) and ( Prev_match_Node <> Match_Node ) ;now selecting no nodes/bonds
{
	Node_high := [], Node_high.x := "", Node_high.y := ""
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node = 0 ) ;selecting no nodes as before
	Node_high := [], Node_high.x := "", Node_high.y := ""
else If ( Match_Node <> 0 ) and ( Prev_match_Node <> Match_Node ) ; selecting a node and we weren't last time
{
	Gosub, redraw
	Gosub, redraw2
}
else If ( Match_Node <> 0 ) and ( Distance(pHover_x, pHover_y, Hover_x, Hover_y) > 15 ) ; selecting a node and we were last time, but the mouse has moved quite a bit
{
	Gosub, redraw
	Gosub, redraw2
}
pHover_x := Hover_x
pHover_y := Hover_y
SetTimer, Node_Check, on
return

#IfWinActive, ahk_class AutoHotkeyGUI
F1::
Hotkey, RButton, R_Sub, Off
_C := 0
_N := 0
_O := 0
_Cl := 0
_F := 0
_Br := 0
_H := 0
_S := 0
_B := 0

If ( Have_asessed <> 1 )
{
	List_Elem := "C,N,O,Cl,F,Br,H,S,B,Si"
	List_Mass := "12.011000,14.007000,15.999000,35.453000,18.998000,79.904000,1.007900,32.065000,10.811000,28.086000"
	StringSplit, Elem_Mass, List_Mass, `,
}
Error := 0
Have_asessed := 1
For k, v in Node_List
{
	If ( node%v%.Selected = 1 )
	{
		Match := 0
		
		Symb := RegExReplace(node%v%.SymbolUse, "[\^|_]")
		If ( SubStr(Symb, 1, 1) = "-" ) ;Left justify
			StringTrimLeft, Symb, Symb, 1
		else if ( RegexMatch(Symb, "D)[^\^]-$") <> 0 ) ;Right justify
			StringTrimRight, Symb, Symb, 1
		If ( Symb = "C" )
		{
			Match := 1
			_C ++
			Bonds := 0
			For k2, v2 in Node%v%.PartnerListType
				Bonds += Floor(v2)
			For k2, v2 in Node%v%.PartnerList0Type
				Bonds += Floor(v2)
			Loop, % 4-Bonds
				_H ++
		}
		else
		{
			Loop, Parse, List_Elem, `,
			{
				If ( Symb = A_LoopField )
				{
					Match := 1
					_%A_LoopField% ++
					Break
				}
			}
		}
		If ( Match = 0 )
		{
			Pos := 1
			Cap1 := "", Cap2 := ""
			While ( Pos <= StrLen(Symb))
			{
				Test := RegExMatch(Symb, "([A-Z][a-z]?)(\d*)", Cap, Pos)
				If ( Test <> 0 )
					_%Cap1% += ( Cap2 = "" ) ? ( 1 ) : ( Cap2 )
				else
				{
					Error := 1
					Break
				}
				Pos += StrLen(Cap1)+StrLen(Cap2)
				Cap1 := "", Cap2 := ""
			}
		}
	}
}
If ( Error = 1 )
{
	Msgbox, 4096, , % "Could not find mass" . "`r`n" . "Error" . " = " . """" . Error . """"
	Hotkey, RButton, R_Sub, On
	return
}

Output :=
Mass := 0
Loop, Parse, List_Elem, `,
	If ( _%A_LoopField% > 0 )
		Mass += _%A_LoopField%*Elem_Mass%A_Index%, Output := ( Output = "" ) ? ( A_LoopField . "." . _%A_LoopField% ) : ( Output . " " . A_LoopField . "." . _%A_LoopField% )

Out_frac_elem :=
Loop, Parse, List_Elem, `,
	If ( _%A_LoopField% > 0 )
		Out_frac_elem := ( Out_frac_elem = "" ) ? ( A_LoopField . "=" . Round(100*_%A_LoopField%*Elem_Mass%A_Index%/Mass, 3) . "%"  ) : ( Out_frac_elem . A_Space . A_LoopField . "=" . Round(100*_%A_LoopField%*Elem_Mass%A_Index%/Mass, 3) . "%" )

Msgbox, 4096, , % "Message" . "`r`n" . "Formula" . " = " . """" . Output . """" . "`r`n" . "Mwt" . " = " . """" . Mass . """" . "`r`n" . "wt%" . " = " . """" . Out_frac_elem . """", 10

Hotkey, RButton, R_Sub, On
return
#IfWinActive

Redraw2:
If ( Update_Opt = 1 )
{
	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
	SetImage(hwnd, hBitmap)
}
else If ( Update_Opt = 2 )
{
	Canvas_x := 0
	Canvas_y := 0
	BitBlt(hdc_WINDOW,Canvas_x, Canvas_y, w_rect_area,h_rect_area, hdc_main,0,0)
}
return

Redraw:
SetTimer, Node_Check, off

Gdip_GraphicsClear(G, 0xffffffff)
If ( Node_Count > 0 )
{
	For k, v in Node_List
	{
		For k2, v2 in Node%v%.PartnerList
		{
			If ( Node%v%.Selected = 1 ) or ( Node%v2%.Selected = 1 )
				Select_this := 1
			else
				Select_this := 0
			If ( Node%v%.PartnerListType[k2] = 1 )
			{
				Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y, Node%v2%.x, Node%v2%.y)
			}
			else if ( Node%v%.PartnerListType[k2] = 1.1 ) ;wedge 1.1
			{
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis, horizontal
					Points := Node%v%.x . "," . Node%v%.y . "|" . Node%v2%.x . "," . Node%v2%.y -Mult_bond_sep/2  . "|" . Node%v2%.x . "," . Node%v2%.y+Mult_bond_sep/2
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis, vertical
					Points := Node%v%.x . "," . Node%v%.y . "|" . Node%v2%.x-Mult_bond_sep/2 . "," . Node%v2%.y . "|" . Node%v2%.x+Mult_bond_sep/2 . "," . Node%v2%.y
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep*0.5)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep*0.5)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
						Points := Node%v%.x . "," . Node%v%.y . "|" . Node%v2%.x + x_sep . "," . Node%v2%.y + y_sep . "|" . Node%v2%.x - x_sep . "," . Node%v2%.y - y_sep
					else
						Points := Node%v%.x . "," . Node%v%.y . "|" . Node%v2%.x + x_sep . "," . Node%v2%.y - y_sep . "|" . Node%v2%.x - x_sep . "," . Node%v2%.y + y_sep
				}
				Gdip_FillPolygon(G, Select_this = 0 ? pBrush_black : pBrush_blue, Points)
			}
			else if ( Node%v%.PartnerListType[k2] = 1.4 ) ;hash 1.4
			{
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis, horizontal
				{
					x1_ := Node%v%.x
					y1_ := Node%v%.y-(Mult_bond_sep/2)
					x2_ := Node%v2%.x
					y2_ := Node%v2%.y-(Mult_bond_sep/2)
					_x1 := Node%v%.x
					_y1 := Node%v%.y+(Mult_bond_sep/2)
					_x2 := Node%v2%.x
					_y2 := Node%v2%.y+(Mult_bond_sep/2)
				}
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis, vertical
				{
					x1_ := Node%v%.x-(Mult_bond_sep/2)
					y1_ := Node%v%.y
					x2_ := Node%v2%.x-(Mult_bond_sep/2)
					y2_ := Node%v2%.y
					_x1 := Node%v%.x+(Mult_bond_sep/2)
					_y1 := Node%v%.y
					_x2 := Node%v2%.x+(Mult_bond_sep/2)
					_y2 := Node%v2%.y
				}
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep*0.5)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep*0.5)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
					{
						x1_ := Node%v%.x + x_sep
						y1_ := Node%v%.y + y_sep
						x2_ := Node%v2%.x + x_sep
						y2_ := Node%v2%.y + y_sep
						_x1 := Node%v%.x - x_sep
						_y1 := Node%v%.y - y_sep
						_x2 := Node%v2%.x - x_sep
						_y2 := Node%v2%.y - y_sep
					}
					else
					{
						x1_ := Node%v%.x + x_sep
						y1_ := Node%v%.y - y_sep
						x2_ := Node%v2%.x + x_sep
						y2_ := Node%v2%.y - y_sep
						_x1 := Node%v%.x - x_sep
						_y1 := Node%v%.y + y_sep
						_x2 := Node%v2%.x - x_sep
						_y2 := Node%v2%.y + y_sep
					}
				}

				Loops := (0.316667*Distance(Node%v%.x,Node%v%.y,Node%v2%.x,Node%v2%.y))
				Frac := 1/Loops
				This_Frac := 0
				Loop, % Loops
				{
					If ( A_Index > 1 )
						This_Frac += Frac
					x1 := ( _x1*(1-This_Frac) + _x2*This_Frac) / 1
					y1 := ( _y1*(1-This_Frac) + _y2*This_Frac) / 1
					x2 := ( x1_*(1-This_Frac) + x2_*This_Frac) / 1
					y2 := ( y1_*(1-This_Frac) + y2_*This_Frac) / 1
					If ( Mod(A_Index, 2) <> 0 ) ;draw on odds
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x1, y1, x2, y2)
				}
			}
			else if ( Node%v%.PartnerListType[k2] = 1.3 ) ;dash 1.3
			{
				Loops := (0.316667*Distance(Node%v%.x,Node%v%.y,Node%v2%.x,Node%v2%.y))
				Frac := 0.5/Loops
				This_Frac := 0
				Loop, % Loops
				{
					If ( A_Index > 1 )
						This_Frac += Frac
					x1 := ( Node%v%.x*(1-This_Frac) + Node%v2%.x*This_Frac) / 1
					y1 := ( Node%v%.y*(1-This_Frac) + Node%v2%.y*This_Frac) / 1
						This_Frac += Frac
					x2 := ( Node%v%.x*(1-This_Frac) + Node%v2%.x*This_Frac) / 1
					y2 := ( Node%v%.y*(1-This_Frac) + Node%v2%.y*This_Frac) / 1
					If ( Mod(A_Index, 2) <> 0 ) ;draw on odds
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x1, y1, x2, y2)
				}
			}
			else if ( Node%v%.PartnerListType[k2] = 1.2 ) ;wedge hash, 1.2
			{
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis, horizontal
				{
					x1_ := Node%v%.x
					y1_ := Node%v%.y ;-(Mult_bond_sep/2)
					x2_ := Node%v2%.x
					y2_ :=  Node%v2%.y-(Mult_bond_sep/2)
					_x1 := Node%v%.x
					_y1 := Node%v%.y ;+(Mult_bond_sep/2)
					_x2 := Node%v2%.x
					_y2 := Node%v2%.y+(Mult_bond_sep/2)
				}
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis, vertical
				{
					x1_ := Node%v%.x ;-(Mult_bond_sep/2)
					y1_ := Node%v%.y
					x2_ := Node%v2%.x-(Mult_bond_sep/2)
					y2_ := Node%v2%.y
					_x1 := Node%v%.x ;+(Mult_bond_sep/2)
					_y1 := Node%v%.y
					_x2 := Node%v2%.x+(Mult_bond_sep/2)
					_y2 := Node%v2%.y
				}
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep*0.5)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep*0.5)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
					{
						x1_ := Node%v%.x ;+ x_sep
						y1_ := Node%v%.y ;+ y_sep
						x2_ := Node%v2%.x + x_sep
						y2_ := Node%v2%.y + y_sep
						_x1 := Node%v%.x ;- x_sep
						_y1 := Node%v%.y ;- y_sep
						_x2 := Node%v2%.x - x_sep
						_y2 := Node%v2%.y - y_sep
					}
					else
					{
						x1_ := Node%v%.x ;+ x_sep
						y1_ := Node%v%.y ;- y_sep
						x2_ := Node%v2%.x + x_sep
						y2_ := Node%v2%.y - y_sep
						_x1 := Node%v%.x ;- x_sep
						_y1 := Node%v%.y ;+ y_sep
						_x2 := Node%v2%.x - x_sep
						_y2 := Node%v2%.y + y_sep
					}
				}
				Loops := (0.316667*Distance(Node%v%.x,Node%v%.y,Node%v2%.x,Node%v2%.y))
				Frac := 1/Loops
				This_Frac := 0
				Loop, % Loops
				{
					If ( A_Index > 1 )
						This_Frac += Frac
					x1 := ( _x1*(1-This_Frac) + _x2*This_Frac) / 1
					y1 := ( _y1*(1-This_Frac) + _y2*This_Frac) / 1
					x2 := ( x1_*(1-This_Frac) + x2_*This_Frac) / 1
					y2 := ( y1_*(1-This_Frac) + y2_*This_Frac) / 1
					If ( Mod(A_Index, 2) <> 0 ) ;draw on odds
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x1, y1, x2, y2)
				}
			}
			else if ( Node%v%.PartnerListType[k2] = 2 ) ;double bond
			{
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis, horizontal
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y-(Mult_bond_sep/2), Node%v2%.x, Node%v2%.y-(Mult_bond_sep/2))
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y+(Mult_bond_sep/2), Node%v2%.x, Node%v2%.y+(Mult_bond_sep/2))
				}
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis, vertical
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x-(Mult_bond_sep/2), Node%v%.y, Node%v2%.x-(Mult_bond_sep/2), Node%v2%.y)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x+(Mult_bond_sep/2), Node%v%.y, Node%v2%.x+(Mult_bond_sep/2), Node%v2%.y)
				}
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep*0.5)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep*0.5)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x + x_sep, Node%v%.y + y_sep, Node%v2%.x + x_sep, Node%v2%.y + y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x - x_sep, Node%v%.y - y_sep, Node%v2%.x - x_sep, Node%v2%.y - y_sep) 
					}
					else
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x + x_sep, Node%v%.y - y_sep, Node%v2%.x + x_sep, Node%v2%.y - y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x - x_sep, Node%v%.y + y_sep, Node%v2%.x - x_sep, Node%v2%.y + y_sep) 
					}
				}
			}
			else if ( Node%v%.PartnerListType[k2] = 3 ) ;triple bond
			{
				Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y, Node%v2%.x, Node%v2%.y) ;regular single
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y-(Mult_bond_sep), Node%v2%.x, Node%v2%.y-(Mult_bond_sep))
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y+(Mult_bond_sep), Node%v2%.x, Node%v2%.y+(Mult_bond_sep))
				}
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x-(Mult_bond_sep), Node%v%.y, Node%v2%.x-(Mult_bond_sep), Node%v2%.y)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x+(Mult_bond_sep), Node%v%.y, Node%v2%.x+(Mult_bond_sep), Node%v2%.y)
				}
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x + x_sep, Node%v%.y + y_sep, Node%v2%.x + x_sep, Node%v2%.y + y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x - x_sep, Node%v%.y - y_sep, Node%v2%.x - x_sep, Node%v2%.y - y_sep) 
					}
					else
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x + x_sep, Node%v%.y - y_sep, Node%v2%.x + x_sep, Node%v2%.y - y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x - x_sep, Node%v%.y + y_sep, Node%v2%.x - x_sep, Node%v2%.y + y_sep) 
					}
				}
			}
			else if ( Node%v%.PartnerListType[k2] = 1.5 ) ;invis bond
				Ignore_this_bond := 1
			else if ( Node%v%.PartnerListType[k2] = 4 ) ;quad bond
			{
			;~ ---------------------------------------------------------------------------------------------------------------
				If ( Node%v%.y = Node%v2%.y ) ; on same y axis, horizontal
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, y41 := Node%v%.y-(Mult_bond_sep/2), Node%v2%.x, Node%v2%.y-(Mult_bond_sep/2))
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, y42 := Node%v%.y+(Mult_bond_sep/2), Node%v2%.x, Node%v2%.y+(Mult_bond_sep/2))
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, y41-Mult_bond_sep, Node%v2%.x, y41-Mult_bond_sep)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, y42+Mult_bond_sep, Node%v2%.x, y42+Mult_bond_sep)
				}
				else If ( Node%v%.x = Node%v2%.x ) ; on same x axis, vertical
				{
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41 := Node%v%.x-(Mult_bond_sep/2), Node%v%.y, Node%v2%.x-(Mult_bond_sep/2), Node%v2%.y)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x42 := Node%v%.x+(Mult_bond_sep/2), Node%v%.y, Node%v2%.x+(Mult_bond_sep/2), Node%v2%.y)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41-Mult_bond_sep, Node%v%.y, x41-Mult_bond_sep, Node%v2%.y)
					Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x42+Mult_bond_sep, Node%v%.y, x42+Mult_bond_sep, Node%v2%.y)
				}
				else ;diagonal
				{
					A2 := conv_angle(angle_node(v, v2))
					x_sep := Abs(Cos(A2/57.2957795)*Mult_bond_sep*0.5)
					y_sep := Abs(Sin(A2/57.2957795)*Mult_bond_sep*0.5)
					m := -1*(Node%v2%.y-Node%v%.y)/(Node%v2%.x-Node%v%.x)
					If ( m > 0 )
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41 := Node%v%.x + x_sep, y41 := Node%v%.y + y_sep, x41_:= Node%v2%.x + x_sep, y41_ := Node%v2%.y + y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x42 := Node%v%.x - x_sep, y42 := Node%v%.y - y_sep, x42_ := Node%v2%.x - x_sep, y42_ := Node%v2%.y - y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41+ 2*x_sep, y41 + 2*y_sep, x41_+ 2*x_sep, y41_ + 2*y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, X42 - 2*x_sep, y42 - 2*y_sep, x42_ - 2*x_sep, y42_ - 2*y_sep) 
					}
					else
					{
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41 := Node%v%.x + x_sep, y41 := Node%v%.y - y_sep, x41_ := Node%v2%.x + x_sep, y41_ := Node%v2%.y - y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x42 := Node%v%.x - x_sep, y42 := Node%v%.y + y_sep, x42_ := Node%v2%.x - x_sep, y42_ := Node%v2%.y + y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x41  + 2*x_sep, y41 -2* y_sep, x41_ + 2*x_sep, y41_ - 2*y_sep) 
						Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, x42  - 2*x_sep, y42 + 2*y_sep, x42_ - 2*x_sep, y42_ + 2*y_sep) 
					}
				}
			}
			else ;not coded yet
				Gdip_DrawLine(G, Select_this = 0 ? pPen_Lines_black : pPen_Lines_blue, Node%v%.x, Node%v%.y, Node%v2%.x, Node%v2%.y) ;draw as a single for now
		}
	}

	For k, v in Node_List
	{
		If ( Node%v%.Symbol <> "_o" )
		{
			If ( Node%v%.Display = 1 ) or ( debug = 1 )
				Gdip_FillEllipse(G, pBrush_white, Node%v%.x-(Symbol_Gap/2), Node%v%.y-(Symbol_Gap/2), Symbol_Gap, Symbol_Gap) ;white circle where we will place our text
		}
	}
	For k, v in Node_List
	{
		If ( Node%v%.Display = 1 ) and ( Node%v%.Symbol <> "_o" ) or ( debug = 1 ) and ( Node%v%.Symbol <> "_o" )
		{
			if ( debug = 1 )
				Node%v%.SymbolUse := v
			else
			{
				Node%v%.SymbolUse := Node%v%.Symbol
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%a", Chr(945))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%b", Chr(946))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%c", Chr(947))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%d", Chr(948))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%e", Chr(949))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%D", Chr(916))
				Node%v%.SymbolUse := RegexReplace(Node%v%.SymbolUse, "%O", Chr(937))
			}
			;~ ---------------------------------------------------------------------------------------------------------------
			;~ Drawing the symbol
			;~ ---------------------------------------------------------------------------------------------------------------
			If ( StrLen(Node%v%.SymbolUse) = 1 )
			{
				If ( node%v%.SpecSize = 0 ) or ( node%v%.SpecSize = "" )
					this_Symbol_Size := Symbol_Size
				else
					this_Symbol_Size := Symbol_Size + ( SpecSize_diff*node%v%.SpecSize)
				Options := "x" . Node%v%.x . " y" . Node%v%.y . " c0xffffffff s" . this_Symbol_Size . " r4"
				Measure := Gdip_TextToGraphics(G, Node%v%.Symbol, Options, , , , 1)
				RegExMatch(Measure, "([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)", Capture)
				Col := ( Node%v%.Selected = 1 ) ? ( "ff0000ff" ) 
					: ( Node%v%.Colour = 1 ) ? ( "ff000000" ) 
					: ( Node%v%.Colour = 2 ) ? ( "ffff0000" ) 
					: ( Node%v%.Colour = 3 ) ? ( "ff0000ff" ) 
					: ( Node%v%.Colour = 4 ) ? ( "ff00ff00" ) 
					: ( Node%v%.Colour = 5 ) ? ( "ffffaa00" ) 
					: ( Node%v%.Colour = 6 ) ? ( "ffff00ff" ) 
					: ( Node%v%.Colour = 7 ) ? ( "ff00ffff" ) 
					: ( Node%v%.Colour = 8 ) ? ( "ff169d9a" ) 
					: ( Node%v%.Colour = 9 ) ? ( "ff891217" ) 
					: ( Node%v%.Colour = 10 ) ? ( "ffffaaa9" ) 
					: ( Node%v%.Colour = 11 ) ? ( "fff44cc77" ) 
					: ( Node%v%.Colour = 12 ) ? ( "fff44cc77" ) 
					: ( "ff000000" )

				Options := "x" . Node%v%.x - Capture3/2 . " y" . Node%v%.y - Capture4/2 . " c" . Col . " s" . this_Symbol_Size . " r4"
				Gdip_TextToGraphics(G, Node%v%.SymbolUse, Options)
			}
			else
			{
				Symb := Node%v%.SymbolUse
				Len := StrLen(Symb)
				If ( SubStr(Symb, 1, 1) = "-" ) ;Left justify
				{
					Just_L := 1, Just_R := 0
					StringTrimLeft, Symb, Symb, 1
				}
				else if ( RegexMatch(Symb, "D)[^\^]-$") <> 0 ) ;Right justify
				{
					Just_L := 0, Just_R := 1
					StringTrimRight, Symb, Symb, 1
				}
				else
					Just_L := 0, Just_R := 0
				
				Subscript_Test := RegExMatch(Symb, "[_|\^]")
				If ( Subscript_Test <> 0 )
				{
					On_Sub := 0
					Temp_append := 
					Parts := 0
					Loop, parse, Symb
					{
						If ( A_LoopField = "_" )
						{
							If ( Temp_append <> "" )
							{
								Parts ++
								Symb%Parts% := Temp_append
								Temp_append :=
								Parts%Parts%_sub := On_Sub
							}
							If ( On_Sub = 1 )
								On_Sub := 0
							else
								On_Sub := 1
						}
						else if ( A_LoopField = "^")
						{
							If ( Temp_append <> "" )
							{
								Parts ++
								Symb%Parts% := Temp_append
								Temp_append :=
								Parts%Parts%_sub := On_Sub
							}
							If ( On_Sub = 2 )
								On_Sub := 0
							else
								On_Sub := 2
						}
						else
							Temp_append .= A_LoopField
					}
					Parts ++
					Symb%Parts% := Temp_append
					Parts%Parts%_sub := On_Sub
				}
				else
					Parts := 1, Symb1 := Symb, Parts1_sub := 0
				
				Width_t := 0
				Loop, % Parts
				{
					If ( node%v%.SpecSize = 0 ) or ( node%v%.SpecSize = "" )
						this_Symbol_Size := Symbol_Size
					else
						this_Symbol_Size := Symbol_Size + ( SpecSize_diff*node%v%.SpecSize)
					
					If ( Parts%A_Index%_sub = 0 )
						Size := this_Symbol_Size
					else
						Size := this_Symbol_Size-5
					
					Options := "x" . Node%v%.x . " y" . Node%v%.y . " cffffffff s" . Size . " r4"
					Measure := Gdip_TextToGraphics(G, Symb%A_Index%, Options, , , , 1)
					RegExMatch(Measure, "([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)\|([\-\d\.]+)", Capture%A_Index%)
					Width_t += (Capture%A_Index%3)
				}
				If ( Parts > 1 )
					Width_t -= (parts-1)*5
				else
					Width_t -= 2

				Loop, % Parts
				{
					Last_Num := A_Index-1
					If ( A_Index = 1 )
					{
						PTX := ( Just_R = 1 ) ? ( PTX := Node%v%.x - Width_t + 10 ) : ( Just_L = 1 ) ? ( PTX := Node%v%.x - 10 ) : ( PTX := Node%v%.x - Width_t/2 )
						PTY := ( Parts%A_Index%_sub = 0 ) ? ( Node%v%.y-(Capture14/2) ) : ( Parts%A_Index%_sub = 1 ) ? ( Node%v%.y-(Capture14/2) + 10 ) : ( Node%v%.y-(Capture14/2) - 10 )
						Size := ( Parts%A_Index%_sub = 0 ) ? ( this_Symbol_Size ) : ( this_Symbol_Size-6 )
					}
					else
					{
						Size := ( Parts%A_Index%_sub = 0 ) ? ( this_Symbol_Size ) : ( this_Symbol_Size-6 )
						PTX += (Capture%Last_Num%3)-5 ;+2
						PTY := ( Parts%A_Index%_sub = 0 ) ? ( Node%v%.y-(Capture14/2) ) : ( Parts%A_Index%_sub = 1 ) ? ( Node%v%.y-(Capture14/2) + 10 ) : ( Node%v%.y-(Capture14/2) - 10 )
					}

					Col := ( Node%v%.Selected = 1 ) ? ( "ff0000ff" ) 
						: ( Node%v%.Colour = 1 ) ? ( "ff000000" ) 
						: ( Node%v%.Colour = 2 ) ? ( "ffff0000" ) 
						: ( Node%v%.Colour = 3 ) ? ( "ff0000ff" ) 
						: ( Node%v%.Colour = 4 ) ? ( "ff00ff00" ) 
						: ( Node%v%.Colour = 5 ) ? ( "ffffaa00" ) 
						: ( Node%v%.Colour = 6 ) ? ( "ffff00ff" ) 
						: ( Node%v%.Colour = 7 ) ? ( "ff00ffff" ) 
						: ( Node%v%.Colour = 8 ) ? ( "ff169d9a" ) 
						: ( Node%v%.Colour = 9 ) ? ( "ff891217" ) 
						: ( Node%v%.Colour = 10 ) ? ( "ffffaaa9" ) 
						: ( Node%v%.Colour = 11 ) ? ( "fff44cc77" ) 
						: ( Node%v%.Colour = 12 ) ? ( "fff44cc77" ) 
						: ( "ff000000" )
					
					Options := "x" . PTX . " y" . PTY . " c" . Col . " s" . Size . " r4"
					Gdip_TextToGraphics(G, Symb%A_Index%, Options)
				}
			}
		}
		else if ( Node%v%.Symbol = "_o" )
		{
			Dot_size := (Symbol_Size + ( SpecSize_diff*node%v%.SpecSize))/3
			Gdip_FillEllipse(G, Node%v%.Selected = 1 ? pBrush_Blue : pBrush_Black, Node%v%.x-(Dot_size/2), Node%v%.y-(Dot_size/2), Dot_size, Dot_size) ;white circle where we will place our text
			Node%v%.SymbolUse := Node%v%.Symbol
		}
		else 
			Node%v%.SymbolUse := Node%v%.Symbol
	}
	For k, v in Node_List
	{
		If ( Node%v%.Selected = 1 )
			Gdip_DrawEllipse(G, pPen_Lines_blue1, Node%v%.x-6, Node%v%.y-6, 12, 12)
	}
}

If ( Match_Node = 1 ) ; highlight node or bond
	Gdip_FillEllipse(G, pBrush_red, Node_high.x-3, Node_high.y-3, 6, 6)
else if ( Match_Node =2 )
	Gdip_FillEllipse(G, pBrush_magenta, Node_high.x-3, Node_high.y-3, 6, 6)

If ( In_Process = 1 ) and ( To = 1 )
	Gdip_DrawLine(G, pPen_Lines_black, mX1, mY1, mX2_, mY2_)	

if ( Box_Active = 1 )
{
	Gdip_FillRectangle(G, pBrush_yel_a, Box_x, Box_y, Box_w, Box_h)
	Gdip_DrawRectangle(G, pPen_Lines_grey, Box_x, Box_y, Box_w, Box_h)
}
Gdip_DrawRectangle(G, pPen_Lines_grey, 0, 0, w_rect_area-2, h_rect_area-2 )
SetTimer, Node_Check, on
return

Swap(ByRef XIn, ByRef YIn)
{
    temp := XIn
    XIn := YIn
    YIn := temp
}

#IfWinActive, ahk_class AutoHotkeyGUI
F2::
Hotkey, RButton, R_Sub, Off
Out :=
For k, v in Node_List
{
	Extras :=
	For k2, v2 in Node%v%.PartnerList
		Extras .= ( A_Index = 1 ) ? ( v2 ) : ( "`," . v2 )
	Extras .= "|"
	For k2, v2 in Node%v%.PartnerListType
		Extras .= ( A_Index = 1 ) ? ( v2 ) : ( "`," . v2 )
	Extras .= " | "
	For k2, v2 in Node%v%.PartnerList0
		Extras .= ( A_Index = 1 ) ? ( v2 ) : ( "`," . v2 )
	Extras .= "|"
	For k2, v2 in Node%v%.PartnerList0Type
		Extras .= ( A_Index = 1 ) ? ( v2 ) : ( "`," . v2 )
	
	Out := ( A_Index = 1 ) ? ( "`r`nposition	name	partners	symb	selec	Extras	x	y`r`n" . k . "	" . v . "	" . Node%v%.Partners . "	" . Node%v%.Symbol . "	" . Node%v%.Selected . "	" . Extras . "	" . Node%v%.x . "	" . Node%v%.y ) : ( Out . "`r`n" . k . "	" . v . "	" . Node%v%.Partners . "	" . Node%v%.Symbol . "	" . Node%v%.Selected . "	" . Extras . "	" . Node%v%.x . "	" . Node%v%.y )
}
Msgbox, 4096, , % "Message" . "`r`n" . "Out" . " = " . """" . Out . """" . "`r`n" . "node_count" . " = " . """" . node_count . """" . "`r`n" . "node_count_nosub" . " = " . """" . node_count_nosub . """", 10
Hotkey, RButton, R_Sub, On
return
#IfWinActive

Make_in_top:
SetTimer, Make_in_top, off
WinWait, Save this sketch, 
IfWinNotActive, Save this sketch, , WinActivate, Save this sketch, 
WinWaitActive, Save this sketch,
sleep 100
Winset, AlwaysOnTop, On, 
return

Save_Img:
SetTimer, Make_in_top, 50

In_Name := ( Default_Name <> "" ) ? ( Default_Name ) : ( "chem sketch " . A_Now )
Inputbox, chem_name, Save this sketch, Save to`r`n%Default_Save%`r`n, , , , , , , , %In_Name%
If ( chem_name <> "" )
   Default_Name := chem_name
else
	return

if ErrorLevel
   sleep 1
else
{
   file := A_ScriptDir . "\" . chem_name . ".cd1"
   IfExist, %file%
	{
		Msgbox, 4100, Warning, File already exists.`r`nOverwrite?
		
		IfMsgbox Yes
		{
			TextToSave:=Yaml_Dump(node_list) . Saving_Delim . Node_Count . Saving_Delim . Node_Count_nosub . Saving_Delim . Zoom_Level
			For k, v in node_list
				TextToSave .= Saving_Delim . v . "-name" . Yaml_Dump(Node%v%)
			FileDelete, %File%
			Loop
				IfNotExist, %File%
					break

			FileAppend, %TextToSave%, %file%
			Gui, 1: Show, , ShefDraw - %Default_Name%
			TrayTip, Splash capture, Saved!, 1
		}
	}
	else
	{
		TextToSave:=Yaml_Dump(node_list) . Saving_Delim . Node_Count . Saving_Delim . Node_Count_nosub . Saving_Delim . Zoom_Level
		For k, v in node_list
			TextToSave .= Saving_Delim . v . "-name" . Yaml_Dump(Node%v%)
		FileAppend, %TextToSave%, %file%
		Gui, 1: Show, , ShefDraw - %Default_Name%
		TrayTip, Splash capture, Saved!, 1
	}

}
TextToSave :=
return

Load_it:
List :=
Count_names := 0
Loop, %A_ScriptDir%\*.cd1
{
	List := ( List = "" ) ? ( A_LoopFileName ) : ( List . "|" . A_LoopFileName )
	Short_Name%A_Index% := A_LoopFileName
	Name%A_Index% := A_LoopFileFullPath
	Count_names ++
}
list_height := Count_names*15+30
Gui, 2: -SysMenu +AlwaysOnTop
Gui, 2: Add, Listbox, x10 y10 w200 h%list_height% vListbox_var AltSubmit, %List%
Gui, 2: Add, Button, gChoose_new, Choose
Gui, 2: Add, Button, gCancel_new, Cancel
Gui, 2: Show
return

Choose_new:
SetTimer, Node_Check, off
SetTimer, Click_Check, off
Gui, 2: Submit, nohide
Gui, 2: Destroy
File := Name%ListBox_var%
Default_Name := RegExReplace(Short_Name%ListBox_var%, "([\w ]+).*", "$1")
Gui, 1: Show, , ShefDraw - %Default_Name%
Loop, %Count_names%
{
	Short_Name%A_Index% :=
	Name%A_Index% :=
}
List :=
FileRead, String, %File%
Loop, Parse, String, %Saving_Delim%
{
	If ( A_Index = 1 )
		Node_List := Yaml(A_LoopField,0)
	else If ( A_Index = 2 )
		Node_Count := A_LoopField
	else If ( A_Index = 3 )
		Node_Count_nosub := A_LoopField
	else If ( A_Index = 4 )
		Zoom_Level := A_LoopField
	else
	{
		name := RegExReplace(A_LoopField, "As)(\d+)\-name.*", "$1")
		Node%name% := Yaml(SubStr(A_LoopField, StrLen(name)+6),0)
	}
}
Gosub, Bond_length_check
Gosub, redraw
Gosub, redraw2
SetTimer, Node_Check, on
SetTimer, Click_Check, on
Hotkey, ^LButton, Del_Sub, On
Hotkey, RButton, R_Sub, On
return

Gui2Close:
Cancel_new:
Gui, 2: Destroy
return

Set_config:
;~ ---------------------------------------------------------------------------------------------------------------
;~ CONFIG
;~ ---------------------------------------------------------------------------------------------------------------

SysGet, vquery, MonitorWorkArea

Space_above := 50
Space_Below := 120
Space_Left := 150
Space_Right := 50
Unused_top := 125
Unused_Left := 75
Unused_right := 230
Unused_bottom := 70
x_rect_area := vqueryleft + Unused_Left
y_rect_area := vquerytop + Unused_top
w_rect_area := (vqueryright - Unused_right) - x_rect_area
h_rect_area := (vquerybottom-Unused_bottom)-y_rect_area
x_rect_plot := x_rect_area+Space_Left
y_rect_plot := y_rect_area+Space_above
w_rect_plot := w_rect_area - Space_Left - Space_Right
h_rect_plot := h_rect_area - Space_above - Space_below
x_1_coord := x_rect_plot
x_2_coord := w_rect_plot+x_1_coord
width_x := w_rect_plot
height_y := h_rect_plot
y_2_coord := y_rect_plot
y_1_coord := y_rect_plot+h_rect_plot
Info_Gui_X := x_rect_area+w_rect_area+10
Info_Gui_Y := y_rect_area
return

#If ( Box_Active = 1 )

delete::
delete_sub:
del_list :=
del_list_node :=
For k, v in Node_list
{
	If ( Node%v%.Selected = 1 )
	{
		Node_Count -= 1
		del_list := ( del_list = "" ) ? ( k ) : ( del_list . "`," . k )
		;~ ---------------------------------------------------------------------------------------------------------------
		For k2, v2 in Node%v%.PartnerList
		{
			If ( Node%v2%.Selected = 0 ) ; not selected but bonded to something we are deleting
			{
				For k3, v3 in Node%v2%.PartnerList0
				{
					If ( v3 = v )
					{
						Pos := k3
						Break
					}
				}
				Node%v2%.PartnerList0.Remove(Pos)
				Node%v2%.PartnerList0Type.Remove(Pos)
				Node%v2%.Partners -= 1
				If ( Node%v2%.Partners = 0 ) and ( Node%v2%.Display = 0 )
				{
					Node_Count -= 1
					Node%v2% := []
					del_list_node := ( del_list_node = "" ) ? ( v2 ) : ( del_list_node . "`," . v2 )
				}
			}
		}
		;~ ---------------------------------------------------------------------------------------------------------------
		For k2, v2 in Node%v%.PartnerList0
		{
			If ( Node%v2%.Selected = 0 ) ; not selected but bonded to something we are deleting
			{
				For k3, v3 in Node%v2%.PartnerList
				{
					If ( v3 = v )
					{
						Pos := k3
						Break
					}
				}
				Node%v2%.PartnerList.Remove(Pos)
				Node%v2%.PartnerListType.Remove(Pos)
				Node%v2%.Partners -= 1
				If ( Node%v2%.Partners = 0 ) and ( Node%v2%.Display = 0 )
				{
					Node_Count -= 1
					Node%v2% := []
					del_list_node := ( del_list_node = "" ) ? ( v2 ) : ( del_list_node . "`," . v2 )
				}
			}
		}
		;~ ---------------------------------------------------------------------------------------------------------------
	}
}
If ( del_list_node <> "" )
{
	Sort, del_list_node, N R D`,
	del_list_node2 :=
	Loop, Parse, del_list_node
	{
		Outer_Field := A_LoopField
		For k, v in node_list
		{
			If ( Outer_Field = v )
			{
				del_list_node2 := ( del_list_node2 = "" ) ? ( k ) : ( del_list_node2 . "`," . k )
				break
			}
		}
	}
	Loop, Parse, del_list_node2, `,
		Node_List.Remove(A_LoopField)
	
	del_list_node :=
	del_list_node2 :=
}

Sort, Del_list, N R D`,
Loop, Parse, Del_list, `,
	Node_List.Remove(A_LoopField)

Box_Active := 0
Selected_Count := 0
Gosub, redraw
Gosub, redraw2
return

^d::
dup_sub:
Count := 0
Dup_List := []
Orig_select := []
For k, v in Node_list
{
	If ( Node%v%.Selected = 1 )
	{
		Count ++
		Dup%Count% := []
		;~ ---------------------------------------------------------------------------------------------------------------
		Node_Count ++
		Node_Count_nosub ++
		Orig_select.Insert(v)
		Dup_%v%_to := Node_Count_nosub
		Dup_List.Insert(Node_Count_nosub)
		%v%_new_name := Node_Count_nosub
		Name := %v%_new_name
		Node%Name% := []
		Node%Name%.x := Node%v%.x +15
		Node%Name%.y := Node%v%.y +15
		Node%Name%.Symbol := Node%v%.Symbol
		Node%Name%.Display := Node%v%.Display
		Node%Name%.Selected := 0
		Node%Name%.Colour := Node%v%.Colour
		Node%Name%.Partners := Node%v%.Partners
		node%name%.SpecSize := node%v%.SpecSize
		Node%Name%.PartnerList := []
		Node%Name%.PartnerListType := []
		Node%Name%.PartnerList0 := []
		Node%Name%.PartnerList0Type := []

		For k2, v2 in Node%v%.PartnerList
			Node%Name%.PartnerList.Insert(v2)
		Node%Name%.PartnerListType := Node%v%.PartnerListType.Clone()
		For k2, v2 in Node%v%.PartnerList0
			Node%Name%.PartnerList0.Insert(v2)
		Node%Name%.PartnerList0Type := Node%v%.PartnerList0Type.Clone()
		Node_List.Insert(Node_Count_nosub)
		;~ ---------------------------------------------------------------------------------------------------------------
	}
}

For k, v in Dup_List
{
	Outer_Index := A_Index
	Remove_These :=
	For k2, v2 in Node%v%.PartnerList
	{
		If ( Node%v2%.Selected = 1 )
		{
			Node%v%.PartnerList[k2] := Dup_%v2%_to
		}
		else
			Remove_These := ( Remove_These = "" ) ? ( k2 ) : ( Remove_These . "`," . Remove_These )
	}
	If ( Remove_These <> "" )
	{
		Sort, Remove_These, N R D`,
		Loop, Parse, Remove_These, `,
		{
			Node%v%.PartnerList.Remove(A_LoopField)
			Node%v%.PartnerListType.Remove(A_LoopField)
			Count := A_Index
		}
		Node%v%.Partners -= Count
	}
	Remove_These :=
	For k2, v2 in Node%v%.PartnerList0
	{
		If ( Node%v2%.Selected = 1 )
			Node%v%.PartnerList0[k2] :=  Dup_%v2%_to
		else
			Remove_These := ( Remove_These = "" ) ? ( k2 ) : ( Remove_These . "`," . Remove_These )
	}
	If ( Remove_These <> "" )
	{
		Sort, Remove_These, N R D`,
		Loop, Parse, Remove_These, `,
		{
			Node%v%.PartnerList0.Remove(A_LoopField)
			Node%v%.PartnerList0Type.Remove(A_LoopField)
			Count := A_Index
		}
		Node%v%.Partners -= Count
	}
}
For k, v in Dup_List
	If ( Node%v%.Partners = 0 )
		Node%v%.Display := 1
For k, v in Node_List
	Dup_%v%_to := 
For k2, v2 in Orig_select
	Node%v2%.Selected := 0
For k2, v2 in Dup_List
	Node%v2%.Selected := 1

Box_x += 15
Box_y += 15
Dup_List := []
Gosub, redraw
Gosub, redraw2
return

#if

WinMove_offset(Title, x=15, y=15)
{
	WinGetPos, _x, _y, w, h, %Title%
	x := _x +x
	y := _y +y
	WinMove, %Title%, , %x%, %y%
}

#if ( Match_Node = 1 )
!LButton::
Name := Node_High.name

Node%Name%.Colour := ( Node%Name%.Colour = "" ) ? ( 1 ) : ( Node%Name%.Colour )
Node%Name%.Colour := ( Node%Name%.Colour >= 11 ) ? ( 1 ) : ( Node%Name%.Colour + 1 )

Gosub, redraw
Gosub, redraw2
return

#if

^!Lbutton::
If ( Box_Active = 0 )
	Gosub, Draw_Rect_get_coord
else ;already have a box drawn
{
	Box_Active := 0
	For k, v in Node_List
		Node%v%.Selected := 0
	Gosub, redraw
	Gosub, redraw2
	return
}

s_x := x
s_x2 := x+w
s_y := y
s_y2 := s_y+h
Selected_Count := 0
Selected_List := []
For k, v in Node_List
{
	If ( Node%v%.x >= s_x ) and ( Node%v%.x <= s_x2 ) and ( Node%v%.y >= s_y ) and ( Node%v%.y <= s_y2 )
		Node%v%.Selected := 1, Selected_Count ++, Selected_List.Insert(v)
}
Gosub, redraw
Gosub, redraw2
return

drag_box:
Match_Node := "", Node_high := []
While ( GetKeystate("LButton"))
{
	Dragging_select := 1
	MouseGetPos, Drag_x, Drag_y
	Drag_X -= Global_mouse_offset_x
	Drag_Y -= Global_mouse_offset_y
	Box_x += Drag_x-move_MX
	Box_y += Drag_y-move_MY
	move_MX := Drag_X
	move_MY := Drag_Y
	Selected_no := 0
	If ( A_Index = 1 )
		For k, v in Node_List
			Node%v%.x_b := Node%v%.x, Node%v%.y_b := Node%v%.y
	
	For k, v in Node_List
	{
		If ( Node%v%.Selected = 1 )
		{
			Node%v%.x := (Node%v%.x_b+(Drag_x-mx))
			Node%v%.y := (Node%v%.y_b+(Drag_y-my))
			Selected_no ++
		}
	}
	Gosub, redraw
	Gosub, redraw2
	Sleep 30
}
Dragging_select := 0
s_x := New_x
s_y := New_y
Gosub, redraw
Gosub, redraw2
return

Draw_Rect_get_coord:
Box_Active := 1
MouseGetPos, MX, MY
MX -= Global_mouse_offset_x 
MY -= Global_mouse_offset_y 
While, (GetKeyState("LButton", "p"))
{
	MouseGetPos, MXend, MYend
	MXend -= Global_mouse_offset_x
	MYend -= Global_mouse_offset_y
	Send {control up}
	w := abs(MX - MXend)
	h := abs(MY - MYend)
	If (MX < MXend)
		X := MX
	Else
		X := MXend
	If (MY < MYend)
		Y := MY
	Else
		Y := MYend
	x_gui := x+Win_x, y_gui := y+Win_y, w_gui := w, h_gui := h
	Box_x := x
	Box_y := y
	Box_w := w
	Box_h := h
	Gosub, redraw
	Gosub, redraw2
   Sleep, 15
}
MouseGetPos, MXend, MYend
MXend -= Global_mouse_offset_x
MYend -= Global_mouse_offset_y
If (MX > MXend)
	Swap(MX, MXend)
If (MY < MYend)
	Swap(MY, MYend)

w_Snap := MXend-MX
h_Snap := MYend-MY
return
