; -------------------------------------------------------------------------
; Sonic CD Disassembly
; By Ralakimus 2021
; -------------------------------------------------------------------------
; Level initialization
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; MMD header
; -------------------------------------------------------------------------

	MMD	0, &
		WORDRAM2M, 0, &
		JmpTo_Start, JmpTo_HInt, JmpTo_VInt

; -------------------------------------------------------------------------
; Bad Apple map buffer
; -------------------------------------------------------------------------

BadAppleMapBuf:
	dcb.b	$1000, 0

; -------------------------------------------------------------------------
; Program start
; -------------------------------------------------------------------------

JmpTo_Start:
	jmp	Start

; -------------------------------------------------------------------------
; Error trap
; -------------------------------------------------------------------------

JmpTo_Error:
	jmp	ErrorTrap

; -------------------------------------------------------------------------
; H-INT routine
; -------------------------------------------------------------------------

JmpTo_HInt:
	jmp	HInterrupt

; -------------------------------------------------------------------------
; V-INT routine
; -------------------------------------------------------------------------

JmpTo_VInt:
	jmp	VInterrupt

; -------------------------------------------------------------------------
; Error trap loop
; -------------------------------------------------------------------------

ErrorTrap:
	nop
	nop
	bra.s	ErrorTrap

; -------------------------------------------------------------------------
; Entry point
; -------------------------------------------------------------------------

Start:
	btst	#6,IOCTRL3			; Have the controller ports been initialized?
	beq.s	.DoInit				; If so, do start RAM clear
	cmpi.l	#'init',lvlInitFlag		; Have we already initialized?
	beq.w	.GameInit			; If so, branch

.DoInit:
	lea	unkLvlBuffer,a6			; Clear RAM section starting at $FF1000
	moveq	#0,d7
	move.w	#$FF,d6				; Clear $400 bytes...
	move.w	#$7F,d6				; ...or actually $200 bytes!

.ClearRAM:
	move.l	d7,(a6)+
	dbf	d6,.ClearRAM			; Clear until finished

	move.b	VERSION,d0			; Get hardware region
	andi.b	#$C0,d0
	move.b	d0,versionCache

	move.l	#'init',lvlInitFlag		; Mark as done

.GameInit:
	bsr.w	InitVDP				; Initialize VDP
	bsr.w	InitControllers			; Initialize joypads

	move.b	#0,gameMode.w			; Set game mode to "level"

	move.b	gameMode.w,d0			; Go to the current game mode routine
	andi.w	#$1C,d0
	jmp	GameModes(pc,d0.w)

; -------------------------------------------------------------------------
; Game modes
; -------------------------------------------------------------------------

GameModes:
	bra.w	LevelStart			; Level

; -------------------------------------------------------------------------
