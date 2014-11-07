PCIRS STRUC
	PCIR_SIGN	DB 'PCIR'
	PCIR_VENDOR_ID	DW ?
	PCIR_DEVICE_ID	DW ?
	PCIR_VPD	DW ?
	PCIR_LEN	DW SIZE PCIRS
	PCIR_REV	DB 00H
	PCIR_CLASS_PROG	DB ?
	PCIR_CLASS_SUB	DB ?
	PCIR_CLASS_BASE	DB ?
	PCIR_IMAGE_LEN	DW ?
	PCIR_REV_LVL	DW ?
	PCIR_CODE	DB ?
	PCIR_ID		DB ?
	PCIR_RSV	DB 2 DUP(?)
PCIRS ENDS

ROM_HEADER MACRO
ORG	0
;---------------------------------------
;BIOS ROM HEADER STRUCTURE
;---------------------------------------
ROM_SIGN	DW 0AA55H		;Magic Code
ROM_SIZE	DB 0			;Initial size (written by makerom.com)
ROM_JMP		LABEL FAR
		JMP NEAR PTR &initCodeLabel	;entry
ROM_DATA	DB strROMData
ROM_DATA_END	LABEL BYTE
		ORG 18h
ROM_POINT	DW PCIR
		.ERRNZ ROM_POINT LT ROM_DATA_END

	DB strROMName
	ALIGN 4
PCIR	LABEL PCIRS
	PCIRS<,pcirVendorID,pcirDeviceID,pcirVPD,,,pcirClassBase,pcirClassSub,pcirClassProg,,pcirRevLvl,pcirCode,pcirID>
ENDM

;***************************************
;define
;***************************************
strROMData CATSTR <'PCIBoard OptionROM'>
strROMName CATSTR <'Option ROM Sample Program Image ( for PC/AT ROM )',0>
pcirVendorID	= 3776h
pcirDeviceID	= 8000h
pcirVPD		= 0000h
pcirClassBase	= 00h
pcirClassSub	= 00h
pcirClassProg	= 00h
pcirRevLvl	= 0000h
pcirCode	= 00h
pcirID		= 00h
initCodeLabel CATSTR <postCode>

;***********************************************
;
; Magukara BIOS program
;
;***********************************************
CODE1 SEGMENT PAGE COMMON 'CODE1'
.386p

ASSUME  CS:CODE1,DS:NOTHING,ES:NOTHING

	ROM_HEADER

MODE	DB	1
ADR	DW	0012h
STRS	DB	'IPV4/UDP               '

;***************************
; Initial Code
;***************************
postCode PROC FAR

	PUSH	CS
	POP	DS
	ASSUME	DS:CODE1

	MOV	AH,2
	MOV	BH,0
	MOV	DX,0
	INT	10h		; cursor=0,0
	CALL	clearScreen
	MOV	SI,OFFSET TitleMsg
	CALL	dispTTY
	MOV	AH,00
	INT	1Ah		; get system timer count (CX=HIGH,DX=LOW)
	MOV	SI,DX		; DX=Timer Low
;
; wait 3 sec
;
waitkey:
	MOV	AH,1
	INT	16h		; check key buffer?
	JNZ	getKey

	MOV	AH,00
	INT	1Ah		; get system timer count (CX=HIGH,DX=LOW)
	SUB	DX,SI
	CMP	DX, (18*3)	; more than 3 sec?

	JB	waitkey
;	JMP	menu
	JMP	exit
getKey:
	MOV	AH,0
	INT	16H
	CMP	AX,2C00H
	JNE	exit

	CALL	menu

exit:

;
; remove initial code from rom size
;
	MOV	AX,4C00H
	INT	21H		; exit to DOS
RET ; if unremove then uncomment
	MOV	CX, OFFSET postCode+1
	ADD	CX, 511 ;1023
	SHR	CX, 9
	MOV	[ROM_SIZE], CL
	MOV	BYTE PTR [postCode], 0CBH ;RETF

	SHL	CX, 9
	DEC	CX
	XOR	AL, AL
	XOR	SI, SI
calcChkSumLoop:
	SUB	AL, [SI]
	INC	SI
	LOOP	calcChkSumLoop

	MOV	[SI], AL

	MOV	AX,4C00H
	INT	21H		; exit to DOS
	RET

postCode ENDP

;***************************
; display menu
;***************************
menu PROC NEAR
	MOV	AH,03H
	XOR	BH,BH
	INT	10H
	MOV	[cursorShape],CX
;
; Copy initial item value
;
	MOV	AL, [MODE]
	MOV	[curMode], AL

	MOV	AX, [ADR]
	MOV	[curAdrs], AX

	MOV	CX, 16
	MOV	SI, OFFSET STRS
	MOV	DI, OFFSET curStr
copyInitialStr:
	MOV	AL, [SI]
	MOV	[DI], AL
	INC	SI
	INC	DI
	LOOP	copyInitialStr
;
; Hide cursor shape
;
redispScreen:
	CALL	clearCursor
;
; Display Menu
;
	CALL	clearScreen
	MOV	BL, 07H
	XOR	DX, DX
	MOV	SI, OFFSET MenuTitleMsg
	CALL	dispMsg
	MOV	DX, 24 SHL 8
	MOV	SI, OFFSET MenuKeyMsg
	CALL	dispMsg

;
; Display Items
;
allItemDisp:
	MOV	DH, 02h
	MOV	DI, OFFSET ItemTable
itemDispLoop:
	MOV	DL, 1
	MOV	SI, [DI].ItemMsg
	TEST	SI, SI
	JZ	endOfItem

	MOV	BL, 07h
	MOV	AL, DH
	SUB	AL, 02h
	CMP	[curItemNum], AL
	JNE	itemMsgDisp
	MOV	BL, 70h
itemMsgDisp:
	CALL	dispMsg
	INC	SI
	MOV	BL, 07h
	CALL	dispMsg
	MOV	AL, ' '
	MOV	CX, 21
	SUB	CL, DL
	CALL	dispChar


	MOV	SI, OFFSET strBuf
	CALL	CS:[DI].ItemDisp
	MOV	DL, 21
	MOV	SI, OFFSET strBuf
	CALL	dispMsg

	ADD	DI, SIZE ItemInfo
	INC	DH
	JMP	itemDispLoop

endOfItem:
;
; Check keyin
;
keyInLoop:
	MOV	AH,0
	INT	16H
	CMP	AH,48h
	JE	upItem
	CMP	AH,50h
	JE	downItem
	CMP	AH,1Ch
	JE	selectItem
	JMP	keyInLoop

upItem:
	DEC	[curItemNum]
	JNS	allItemDisp
	MOV	[curItemNum], MAX_ITEM_NUM - 1
	JMP	allItemDisp
downItem:
	INC	[curItemNum]
	CMP	[curItemNum], MAX_ITEM_NUM
	JB	allItemDisp
	MOV	[curItemNum], 0
	JMP	allItemDisp

;
; Change Item value
;
selectItem:
	MOV	AL,[curItemNum]
	MOV	AH,SIZE itemInfo
	MUL	AH
	MOV	DI, OFFSET itemTable
	ADD	DI, AX
	MOV	SI, CS:[DI].ItemMsg
	MOV	DX, 02h SHL 8 OR 1
	ADD	DH,[curItemNum]
	MOV	BL, 07H
	CALL	dispMsg

	MOV	SI, OFFSET strBuf
	CALL	CS:[DI].ItemDisp
	MOV	SI, OFFSET strBuf
	MOV	DL, 21
	PUSH	DI
	CALL	CS:[DI].ItemEdit
	CALL	clearCursor
	POP	DI
	CMP	AH,-1
	JE	quitMenu
	CMP	AH,1CH
	JNE	allItemDisp

	MOV	SI, OFFSET strBuf
	CALL	CS:[DI].ItemUpdate
	JMP	allItemDisp
;
; Select Quit Mode
;
quitMenu:
	MOV	BL, 70H
	MOV	DX, 20 SHL 8 OR 5
	MOV	SI, OFFSET QuitMsg
	CALL	dispMsg
	MOV	BL, 07H
	MOV	DX, 24 SHL 8
	MOV	SI, OFFSET QuitKeyMsg
	CALL	dispMsg
quitMenuKeyin:
	MOV	AH, 0
	INT	16H
	CMP	AH, 01H
	JE	redispScreen

	AND	AL, NOT 20h
	CMP	AL, 'Y'
	JE	saveExit
	CMP	AL, 'N'
	JNE	quitMenuKeyin
;
; Reset Screen & Exit Option ROM
;
exitROM:
	MOV	AH, 0FH
	INT	10H
	AND	AX, 007FH
	INT	10H
	MOV	AX,4C00H
	INT	21H
	RET
;
; Save changed parameters and exit
;
saveExit:

;
; Save item values
;
	MOV	AL, [curMode]
	MOV	[MODE], AL

	MOV	AX, [curAdrs]
	MOV	[ADR], AX

	MOV	CX, 16
	MOV	SI, OFFSET curStr
	MOV	DI, OFFSET STRS
saveCurStr:
	MOV	AL, [SI]
	MOV	[DI], AL
	INC	SI
	INC	DI
	LOOP	saveCurStr

	JMP	exitROM

	DB	0EAh
	DW	0FFF0h
	DW	0F000h

menu ENDP

;**************************
; one line input
;**************************
enter1Line PROC NEAR

	CALL	resetCursor
	MOV	DI,SI
	PUSH	SI
	PUSH	DX
	CALL	dispMsg
	POP	DX
	POP	SI
enter1LineLoop:
	XOR	BH,BH
	MOV	AH,02H
	INT	10H

	MOV	AH,0
	INT	16H

	CMP	AL,8
	JE	@@BkSp
	CMP	AH,01H
	JE	@@RET
;	CMP	AH,0FH
;	JE	@@RET
	CMP	AH,1CH
	JE	@@RET
	CMP	AX,5000H
	JE	@@RET
	CMP	AX,4700H
	JE	@@Home
	CMP	AX,4800H
	JE	@@RET
	CMP	AX,4B00H
	JE	@@Left
	CMP	AX,4D00H
	JE	@@Right
	CMP	AX,4F00H
	JE	@@End
	CMP	AX,5200H
	JE	enter1LineLoop ;Insert
	CMP	AX,5300H
	JE	@@Del

	CMP	AL,' '
	JB	enter1LineLoop

	CMP	[enterMode],@ENTER_STR
	JE	@@PutChar

	CMP	AL,'0'
	JB	enter1LineLoop
	CMP	AL,'9'
	JBE	@@PutChar

	CMP	[enterMode],@ENTER_NUM
	JE	enter1LineLoop

	AND	AL,0DFH
	CMP	AL,'A'
	JB	enter1LineLoop
	CMP	AL,'F'
	JA	enter1LineLoop

;character input
;-----------------------
@@PutChar:
;is insert mode?
;-----------------------
	PUSH	DS
	PUSH	AX
	XOR	AX, AX
	MOV	DS, AX
	TEST	BYTE PTR DS:[417H],1 SHL 7
	POP	AX
	POP	DS
	JZ	@@OVER
	;insert mode
	;-----------------------
	;get last string address
	;-----------------------
	CALL	@@GetLastAdrs
	PUSH	SI
@@InsLoop:
	CMP	SI,CX
	JAE	@@CantIns	; can not insert
	MOV	AH,[SI]
	INC	SI
	TEST	AH,AH
	JNZ	@@InsLoop
	CMP	SI,CX
	JAE	@@CantIns	; can not insert

	;move string for insert one character
	;--------------------------
	POP	CX
@@InsLoop2:
	MOV	AH,[SI-1]
	MOV	[SI],AH
	DEC	SI
	CMP	SI,CX
	JA	@@InsLoop2

	MOV	[SI],AL
	PUSH	DX
	PUSH	SI
	CALL	dispMsg
	POP	SI
	POP	DX
	INC	SI
	INC	DL
	JMP	enter1LineLoop

@@CantIns:
	POP	SI
	JMP	enter1LineLoop

	;overwrite mode
	;--------------------------
@@OVER:
	CALL	@@GetLastAdrs
	CMP	SI,CX
	JAE	enter1LineLoop

	MOV	AH,[SI]
	MOV	[SI],AL
	INC	SI
	TEST	AH,AH
	JNZ	@@DISP_INPUT_CHAR
	MOV	[SI],AH
@@DISP_INPUT_CHAR:
	MOV	CX,1
	CALL	dispChar
	INC	DL
	JMP	enter1LineLoop
@@RET:
	RET

@@Right:
	CMP	BYTE PTR [SI],0
	JE	enter1LineLoop
	INC	DL
	INC	SI
	JMP	enter1LineLoop

@@Left:
	CMP	SI,DI
	JE	enter1LineLoop
	DEC	DL
	DEC	SI
	JMP	enter1LineLoop


@@Del:
	CMP	BYTE PTR [SI],0
	JE	enter1LineLoop
	PUSH	SI
@@DelLoop:
	MOV	AL,[SI+1]
	MOV	[SI],AL
	INC	SI
	TEST	AL,AL
	JNZ	@@DelLoop
	POP	SI
	JMP	@@DispLastSpace


@@BkSp:
	CMP	SI,DI
	JE	enter1LineLoop

	PUSH	SI
@@BkSpLoop:
	MOV	AL,[SI]
	MOV	[SI-1],AL
	INC	SI
	TEST	AL,AL
	JNZ	@@BkSpLoop
	POP	SI

	DEC	SI
	DEC	DL
@@DispLastSpace:
	PUSH	SI
	PUSH	DX
	CALL	dispMsg
	MOV	AL,' '
	MOV	CX,1
	CALL	dispChar
	POP	DX
	POP	SI
	JMP	enter1LineLoop

@@Home:
	MOV	AX,SI
	SUB	AX,DI
	SUB	DL,AL
	MOV	SI,DI
	JMP	enter1LineLoop

@@End:
	CMP	BYTE PTR [SI], 0
	JE	enter1LineLoop
	INC	DL
	INC	SI
	JMP	@@End

@@GetLastAdrs:

	MOV	CX,[enterLen]
	ADD	CX,DI
;	INC	CX
	RET

enter1Line ENDP

;***************************
; display mode value
;***************************
modeDisp PROC NEAR

	MOV	AL, [curMode]
	ADD	AL, '0'
	XOR	AH,AH
	MOV	[SI], AX
	RET

modeDisp ENDP
;***************************
; edit mode value
;***************************
modeEdit PROC NEAR

	MOV	[enterMode], @ENTER_NUM
	MOV	[enterLen],1
	CALL	enter1Line
	RET

modeEdit ENDP

;***************************
; update mode value
;***************************
modeUpdate PROC NEAR

	MOV	AL, [SI]
	TEST	AL, AL
	JZ	modeUpdateSkip
	SUB	AL, '0'
	MOV	[curMode], AL
modeUpdateSkip:
	RET

modeUpdate ENDP


;***************************
; display address value
;***************************
adrsDisp PROC NEAR

	PUSH	DX
	MOV	DX, [curAdrs]
	CALL	adrsDispConvHex
	CALL	adrsDispConvHex
	CALL	adrsDispConvHex
	CALL	adrsDispConvHex
;	MOV	WORD PTR [SI], 'H'
;	INC	SI
	MOV	BYTE PTR [SI], 0
	POP	DX
	RET

adrsDispConvHex:
	MOV	AL, DH
	SHR	AL, 4
	SHL	DX, 4
	ADD	AL, '0'
	CMP	AL, '0'+10
	JB	adrsDispStore
	ADD	AL, 'A'-'0'-10
adrsDispStore:
	MOV	[SI], AL
	INC	SI
	RET

adrsDisp ENDP
;***************************
; edit address value
;***************************
adrsEdit PROC NEAR

	MOV	[enterMode], @ENTER_HEX
	MOV	[enterLen],4
	CALL	enter1Line
	RET

adrsEdit ENDP

;***************************;
; update address value
;***************************
adrsUpdate PROC NEAR

	CMP	BYTE PTR [SI], 0
	JZ	adrsUpdateSkip

	XOR	DX, DX
adrsUpdateLoop:
	MOV	AL, [SI]
	INC	SI
	TEST	AL, AL
	JZ	adrsUpdateEnd
adrsUpdateHex:
	SUB	AL, '0'
	CMP	AL, 10
	JB	adrsUpdateHexStore
	SUB	AL, 'A'-'0'-10
	CMP	AL, 16
	JB	adrsUpdateHexStore
	SUB	AL, 'a'-'A'
adrsUpdateHexStore:
	SHL	DX, 4
	OR	DL, AL
	JMP	adrsUpdateLoop
adrsUpdateEnd:

	MOV	[curAdrs], DX

adrsUpdateSkip:
	RET

adrsUpdate ENDP

;***************************
; display string value
;***************************
strDisp PROC NEAR

	PUSH	DI
	MOV	DI, OFFSET curStr
	MOV	CX, 16
strEditLoop:
	MOV	AL, [DI]
	MOV	[SI], AL
	INC	DI
	INC	SI
	LOOP	strEditLoop

	POP	DI
	RET
strDisp ENDP
;***************************
; edit string value
;***************************
strEdit PROC NEAR

	MOV	[enterMode], @ENTER_STR
	MOV	[enterLen],16
	CALL	enter1Line

	RET

strEdit ENDP
;***************************
; update string value
;***************************
strUpdate PROC NEAR

	PUSH	DI
	MOV	DI, OFFSET curStr
	MOV	CX, 16
strUpdateLoop:
	MOV	AL, [SI]
	MOV	[DI], AL
	INC	DI
	INC	SI
	LOOP	strUpdateLoop

	POP	DI
	RET

strUpdate ENDP

;***************************
; print string value
;***************************
exitDisp PROC NEAR

	MOV	BYTE PTR [SI], 0
	INC	SI
	RET

exitDisp ENDP
;***************************
; edit string value
;***************************
exitEdit PROC NEAR

	MOV	AH, -1
	RET

exitEdit ENDP
;***************************
; update exit value(dummy)
;***************************
exitUpdate PROC NEAR

	RET

exitUpdate ENDP

clearScreen PROC NEAR

	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	DL,DS:[44AH]
	MOV	DH,DS:[484H]
	DEC	DX

	MOV	AX,0600H
	MOV	BH,07H
	MOV	CX,0
	INT	10H

	POP	DS
	POP	DX
	POP	CX
	POP	BX
	POP	AX

	RET

clearScreen ENDP

;**************************
; display string
;	input	CS:SI	string address
;		BL	attribute
;		DX	start position
;	output	DX	end position
;		SI	string end address
;**************************
dispMsg	PROC NEAR

	PUSH	AX
	PUSH	CX
	MOV	CX,1
msgLoop:
	MOV	AL,CS:[SI]
	TEST	AL,AL
	JZ	dispMsgEnd

	CALL	dispChar
	INC	SI
	INC	DL
	JMP	msgLoop
dispMsgEnd:
	POP	CX
	POP	AX
	RET

dispMsg	ENDP
;**************************
;display character
;	input	AL	character code
;		BL	attribute
;		CX	count
;		DX	position
;	broken	none
;**************************
dispChar	PROC NEAR

	PUSH	DX

	PUSH	AX
	PUSH	DS
	XOR	AX, AX
	MOV	DS, AX
	MOV	DS:[450H],DX
	POP	DS
	POP	AX

	PUSH	AX
	PUSH	BX
	PUSH	CX
	XOR	BH,BH
	MOV	Ah,09H
	INT	10H
	POP	CX
	POP	BX
	POP	AX
	POP	DX
	RET

dispChar	ENDP

;**************************
; Display string
; Input	 CS:SI  String Ptr
;	 BL	Char Attribute
; Output None
; broken AL SI
;**************************
dispTTY PROC NEAR

dispTTYLoop:
	MOV	AL,CS:[SI]
	TEST	AL,AL
	JZ	dispTTYEnd
	PUSH	AX
	PUSH	BX
	MOV	AH,0EH
	XOR	BH,BH
	INT	10H
	POP	BX
	POP	AX
	INC	SI
	JMP	dispTTYLoop
dispTTYEnd:
	RET

dispTTY ENDP

;**************************
;  resetCursor
;**************************
resetCursor PROC NEAR

	PUSH	AX
	PUSH	BX
	PUSH	CX
	XOR	BH,BH
	MOV	AH,02H
	INT	10H
	MOV	AH,01H
	MOV	CX,[cursorShape]
	INT	10H
	POP	CX
	POP	BX
	POP	AX
	RET

resetCursor ENDP

;**************************
;  clear Cursor
;**************************
clearCursor PROC NEAR

	PUSH	AX
	PUSH	CX
	MOV	AH, 01H
	MOV	CX, 2000H
	INT	10H
	POP	CX
	POP	AX
	RET

clearCursor ENDP

TitleMsg DB 'Magukara Utility Version 0.00',13,10
	DB 'Copyright 2012-2014, {macchan,sora}@sfc.wide.ad.jp',13,10,13,10
	DB 'Press any key to continue.',13,10,13,10
	DB '(ALT-Z is start up the menu)',13,10,0

MenuTitleMsg DB 'Magukara Utility',0
MenuKeyMsg	DB 18h,19h,':Select Items  Enter:Change Item',0

QuitMsg	DB 'Save Parameters ?(Y/N)',0
QuitKeyMsg DB 'Y:Exit and save changes N:Exit and discard changes  Esc:Cancel',0

ItemInfo STRUC
ItemMsg  DW ?
ItemDisp DW ?
ItemEdit DW ?
ItemUpdate DW ?
ItemInfo ENDS

ItemTable LABEL ItemInfo
	 ItemInfo<ModeMsg,ModeDisp,ModeEdit,ModeUpdate>
	 ItemInfo<AdrsMsg,AdrsDisp,AdrsEdit,AdrsUpdate>
	 ItemInfo<StrMsg,StrDisp,StrEdit,StrUpdate>
	 ItemInfo<ExitMsg,ExitDisp,ExitEdit,ExitUpdate>
MAX_ITEM_NUM EQU ($-ItemTable) / (SIZE ItemInfo)
	 DW 0

ModeMsg	DB 'Packet Size',0,'                   [1:64 2:128 3:256 4:512 5:1024 6:1280 7:1518]',0
AdrsMsg	DB 'Inter Frame Gap',0,'               [0001..9999  Default:0012]',0
StrMsg	DB "Protocol",0,'                                                ',0
ExitMsg	DB 'Exit',0,0

cursorShape DW ?
enterMode  DB 0
enterLen	DW 0
@ENTER_STR	EQU 0
@ENTER_HEX	EQU 1
@ENTER_NUM	EQU 2
curItemNum	DB 0
curMode	DB ?
curAdrs	DW ?
curStr	DB 16 DUP(?)
strBuf	DB 16 DUP(?)
	DB 0
CODE1	ENDS
	END ROM_JMP
