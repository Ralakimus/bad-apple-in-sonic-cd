; -------------------------------------------------------------------------
; Sonic CD Disassembly
; By Ralakimus 2021
; -------------------------------------------------------------------------
; Main function
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; Level game mode
; -------------------------------------------------------------------------

LevelStart:
	clr.w	demoMode			; Clear demo mode flag

	cmpi.b	#$7F,timeStones			; Did we get all of the time stones?
	bne.s	.NotGoodFuture			; If not, branch
	tst.b	timeAttackMode			; Are we in time attack mode?
	bne.s	.NotGoodFuture			; If not, branch
	move.b	#1,goodFuture			; Force a good future

.NotGoodFuture:
	move.b	#0,levelStarted			; Mark the level as not started yet
	clr.b	vintRoutine.w			; Reset V-INT routine ID
	clr.b	usePlayer2			; Clear unused "use player 2" flag
	if DEMO<>0
		move.b	#0,lastCheckpoint	; Reset checkpoint if in a demo
	endif
	move.b	#0,paused.w			; Clear pause flag

	bset	#0,plcLoadFlags			; Mark PLCs as loaded
	bne.s	.NoReset			; If they were loaded before, branch

	clr.b	palFadeFlags			; Mark palette fading as inactive
	clr.b	lastCheckpoint			; Reset checkpoint
	move.l	#5000,nextLifeScore		; Reset next score for 1-UP

	bsr.w	ResetRespawnTable		; Clear respawn table

	clr.b	resetLevelFlags			; Clear level reset flags
	clr.b	goodFutureFlags			; Clear good future flags
	clr.l	levelScore			; Clear score

	move.b	#3,lifeCount			; Reset life count to 3
	tst.b	timeAttackMode			; Are we in time attack mode?
	beq.s	.NoReset			; If not, branch
	move.b	#1,lifeCount			; Reset life count to 1

.NoReset:
	bset	#7,gameMode.w			; Mark level as initializing
	bsr.w	ClearPLCs			; Clear PLCs

	tst.b	enteredBigRing			; Have we entered a big ring before?
	bne.s	.EnteredBigRing			; If so, branch
	btst	#7,timeZone			; Were we time travelling before?
	beq.s	.FadeToBlack			; If not, branch

	bset	#0,palFadeFlags			; Mark palette fading as active
	beq.s	.SkipFade			; If it was active before, branch

.EnteredBigRing:
	bsr.w	FadeToWhite			; Fade to white
	bclr	#0,palFadeFlags			; Mark palette fading as inactive

.SkipFade:
	clr.b	timeWarpDir.w			; Reset time travel direction
	tst.w	levelRestart			; Was the level restart flag set?
	beq.w	.CheckNormalLoad		; If not, branch
	move.w	#0,levelRestart			; Clear level restart flag
	cmpi.b	#2,levelAct			; Are we in act 3?
	bne.s	.End				; If not, branch
	bclr	#7,timeZone			; Clear time travel flag

.End:
	move.w	#1,GACOMCMD2			; Stop Bad Apple
	
.WaitSubCPUDone:
	tst.w	GACOMSTAT0			; Is the Sub CPU done?
	bne.s	.WaitSubCPUDone			; If not, wait
	rts

; -------------------------------------------------------------------------

.FadeToBlack:
	bset	#0,palFadeFlags			; Mark palette fading as active
	beq.s	.SkipFade2			; If it was active before, branch
	bsr.w	FadeToBlack			; Fade to black

.SkipFade2:
	cmpi.w	#2,levelRestart			; Were we going to the next level?
	bne.s	.CheckNoLives			; If not, branch
	move.w	#0,levelRestart			; Clear level restart flag
	move.b	#0,palFadeFlags			; Mark palette fading as inactive
	bra.s	.ClearPal			; Get out of here

.CheckNoLives:
	tst.b	lifeCount			; Do we have any lives?
	bne.s	.CheckNormalLoad		; If so, branch
	move.b	#0,plcLoadFlags			; Mark PLCs as not loaded
	move.b	#0,lastCheckpoint		; Clear checkpoint
	move.b	#0,resetLevelFlags		; Clear level level flags
	move.b	#0,palFadeFlags			; Mark palette fading as inactive

.ClearPal:
	lea	palette.w,a1			; Fill the palette with black
	move.w	#$80/4-1,d6

.ClearPalLoop:
	move.l	#0,(a1)+
	dbf	d6,.ClearPalLoop

	move.b	#$C,vintRoutine.w		; Process the palette clear in V-INT
	bsr.w	VSync
	bra.w	.End

; -------------------------------------------------------------------------

.CheckNormalLoad:
	cmpi.w	#$800,demoDataIndex.w		; Was a demo running?
	bne.s	.NormalLoad			; If not, branch
	move.w	#0,demoDataIndex.w		; Reset demo timer
	clr.w	demoMode			; Clear demo mode flag
	move.b	#0,palFadeFlags			; Mark palette fading as inactive
	bra.w	.End

; -------------------------------------------------------------------------

.NormalLoad:
	moveq	#0,d0				; Fill palette with black
	btst	#0,palClearFlags		; Should we fill the palette with white?
	bne.s	.UseWhite			; If so, branch
	btst	#7,timeZone			; Were we time travelling before?
	beq.s	.ClearPal2			; If not, branch

.UseWhite:
	move.l	#$0EEE0EEE,d0			; Fill palette with white

.ClearPal2:
	lea	palette.w,a1			; Fill the palette with black or white
	move.w	#$80/4-1,d6

.ClearPalLoop2:
	move.l	d0,(a1)+
	dbf	d6,.ClearPalLoop2		; Loop until finished

.WaitPLC:
	move.b	#$C,vintRoutine.w		; VSync
	bsr.w	VSync
	bsr.w	ProcessPLCs			; Process PLCs
	bne.s	.WaitPLC			; If the queue isn't empty, wait
	tst.l	plcBuffer.w

	bsr.w	PlayLevelMusic			; Play level music

	moveq	#0,d0				; Get level PLCs
	lea	LevelDataIndex,a2
	moveq	#0,d0
	move.b	(a2),d0
	beq.s	.LoadStdPLCs
	bsr.w	LoadPLCImm			; Load it immediately

.LoadStdPLCs:
	moveq	#1,d0				; Load standard PLCs immediately
	bsr.w	LoadPLCImm

	clr.b	lvlLoadShieldArt		; Reset shield art load flag
	clr.l	flowerCount			; Clear flower count

	lea	objDrawQueue.w,a1		; Clear object sprite draw queue
	moveq	#0,d0
	move.w	#$400/4-1,d1

.ClearObjSprites:
	move.l	d0,(a1)+
	dbf	d1,.ClearObjSprites

	lea	flowerPosBuf,a1			; Clear flower position buffer and other misc. variables
	moveq	#0,d0
	move.w	#$A00/4-1,d1

.ClearFlowers:
	move.l	d0,(a1)+
	dbf	d1,.ClearFlowers

	lea	objects.w,a1			; Clear object RAM
	moveq	#0,d0
	move.w	#$2000/4-1,d1

.ClearObjects:
	move.l	d0,(a1)+
	dbf	d1,.ClearObjects

	lea	miscVariables.w,a1		; Clear misc. variables
	moveq	#0,d0
	move.w	#$58/4-1,d1

.ClearMiscVars:
	move.l	d0,(a1)+
	dbf	d1,.ClearMiscVars

	lea	cameraX.w,a1			; Clear camera RAM
	moveq	#0,d0
	move.w	#$100/4-1,d1

.ClearCamera:
	move.l	d0,(a1)+
	dbf	d1,.ClearCamera

	move	#$2700,sr			; Disable interrupts
	move.l	#DemoData,demoDataPtr.w		; Set demo data pointer
	if DEMO<>0
		move.w	#1,demoMode		; Set demo mode flag
	endif
	move.w	#0,demoDataIndex.w		; Reset demo data index

	bsr.w	ClearScreen			; Clear the screen
	lea	VDPCTRL,a6
	move.w	#$8B03,(a6)			; HScroll by line, VScroll by screen
	move.w	#$8230,(a6)			; Plane A at $C000
	move.w	#$8407,(a6)			; Plane B at $E000
	move.w	#$857C,(a6)			; Sprite table at $F800
	move.w	#$9001,(a6)			; Plane size 64x32
	move.w	#$8004,(a6)			; Disable H-INT
	move.w	#$8720,(a6)			; Background color at line 2, color 0
	move.w	#$8ADF,vdpReg0A.w		; Set H-INT counter to 233
	move.w	vdpReg0A.w,(a6)

	move.w	#30,playerAirLeft		; Set air timer

	move	#$2300,sr			; Enable interrupts
	moveq	#3,d0				; Load Sonic's palette into both palette buffers
	bsr.w	LoadPalette
	moveq	#3,d0
	bsr.w	LoadFadePal

	bsr.w	LevelSizeLoad			; Get level size and start position
	bsr.w	LevelScroll			; Initialize level scrolling
	bset	#2,scrollFlags.w		; Force draw a block column on the left side of the screen
	bsr.w	LoadLevelData			; Load level data
	bsr.w	InitLevelDraw			; Begin level drawing
	jsr	ConvColArray			; Convert collision data (dummied out)
	bsr.w	LoadLevelCollision		; Load collision block IDs

.WaitPLC2:
	move.b	#$C,vintRoutine.w		; VSync
	bsr.w	VSync
	bsr.w	ProcessPLCs			; Process PLCs
	bne.s	.WaitPLC2			; If the queue isn't empty, wait
	tst.l	plcBuffer.w			; Is the queue empty?
	bne.s	.WaitPLC2			; If not, wait

	bsr.w	LoadPlayer			; Load the player
	move.b	#$1C,objHUDScoreSlot.w		; Load HUD score object
	move.b	#$1C,objHUDLivesSlot.w		; Load HUD lives object
	move.b	#1,objHUDLivesSlot+oSubtype.w
	move.b	#$1C,objHUDRingsSlot.w		; Load HUD rings object
	move.b	#1,objHUDRingsSlot+oSubtype2.w
	bsr.w	LoadLifeIcon
	move.b	#$19,objHUDIconSlot.w		; Load HUD time icon object
	move.b	#$A,objHUDIconSlot+oSubtype.w

	bset	#1,plcLoadFlags			; Mark title card as loaded
	bne.s	.SkipTitleCard			; If it was already loaded, branch
	move.b	#$3C,objTtlCardSlot.w		; Load the title card
	move.b	#1,ctrlLocked.w			; Lock controls
	clr.b	lastCamPLC			; Reset last camera PLC

.SkipTitleCard:
	move.w	#0,playerCtrl.w			; Clear controller data
	move.w	#0,p1CtrlData.w
	move.w	#0,p2CtrlData.w
	move.w	#0,boredTimer.w			; Reset boredom timers
	move.w	#0,boredTimerP2.w
	move.b	#0,unkLevelFlag			; Clear unknown flag

	moveq	#0,d0
	tst.b	resetLevelFlags			; Was the level reset?
	bne.s	.SkipClear			; If so, branch
	move.w	d0,levelRings			; Reset ring count
	move.l	d0,levelTime			; Reset time
	move.b	d0,lifeFlags			; Reset 1UP flags

.SkipClear:
	move.b	d0,lvlTimeOver			; Clear time over flag
	move.b	d0,shieldFlag			; Clear shield flag
	move.b	d0,invincibleFlag		; Clear invincible  flag
	move.b	d0,speedShoesFlag		; Clear speed shoes flag
	move.b	d0,timeWarpFlag			; Clear time warp flag
	move.w	d0,lvlDebugMode			; Clear debug mode flag
	move.w	d0,levelRestart			; Clear level restart flag
	move.w	d0,lvlFrameTimer		; Reset frame timer
	move.b	d0,resetLevelFlags		; Clear level reset flags
	move.b	#1,updateScore			; Update the score in the HUD
	move.b	#1,updateRings			; Update the ring count in the HUD
	move.b	#1,updateTime			; Update the time in the HUD
	move.b	#1,updateLives			; Update the life counter in the HUD
	move.b	#$80,updateRings		; Initialize the score in the HUD
	move.b	#$80,updateScore		; Initialize the score in the HUD

	move.w	#0,demoS1Index.w		; Clear demo data index (Sonic 1 leftover)
	move.w	#$202F,palFadeInfo.w		; Set to fade palette lines 1-3

	jsr	JmpTo_LoadShieldArt		; Load shield art

	move.b	#1,lvlEnableDisplay		; Set to enable display on palette fade
	bclr	#7,timeZone			; Stop time travelling
	beq.s	.ChkPalFade			; If we weren't to begin with, branch

.FromWhite:
	bsr.w	FadeFromWhite			; Fade from white
	bra.s	.BeginLevel

.ChkPalFade:
	bclr	#0,palClearFlags		; Did we fill the palette with white?
	bne.s	.FromWhite			; If so, branch
	bsr.w	FadeFromBlack			; Fade from black

.BeginLevel:
	bclr	#7,gameMode.w			; Mark level as initialized
	bsr.w	InitBadApple			; Initialize bad apple
	move.b	#1,levelStarted			; Mark level as started

; -------------------------------------------------------------------------

Level_MainLoop:
	move.b	#8,vintRoutine.w		; VSync
	bsr.w	VSync

	if REGION=USA				; Did the player die?
		cmpi.b	#6,objPlayerSlot+oRoutine.w	
		bcc.s	.CheckPaused		; If so, branch
	endif
	tst.b	ctrlLocked.w			; Are controls locked?
	bne.s	.CheckPaused			; If so, branch
	btst	#7,p1CtrlTap.w			; Was the start button pressed?
	beq.s	.CheckPaused			; If not, branch
	eori.b	#1,paused.w			; Do pause/unpause

.CheckPaused:
	btst	#0,paused.w			; Is the game paused?
	beq.w	.NotPaused			; If not, branch

	bsr.w	PauseMusic			; Pause music
	
	if DEMO<>0
		tst.w	demoMode		; Are we in a demo?
		bne.s	.IsDemo			; If so, branch
	endif
	move.b	p1CtrlTap.w,d0			; Get pressed buttons
	tst.b	timeAttackMode			; Are we in time attack mode?
	bne.s	.CheckReset			; If so, branch

	andi.b	#$70,d0				; Get A, B, or C
	if REGION=USA
		beq.s	Level_MainLoop		; If none of them were pressed, branch
	else
		cmpi.b	#$70,d0			; Were A, B, and C pressed?
		bne.s	Level_MainLoop		; If not, branch
	endif
	subq.b	#1,lifeCount			; Take away a life
	bpl.s	.GotLives			; If we haven't run out, branch
	clr.b	lifeCount			; Cap lives at 0

.GotLives:
	move.w	#$E,d0				; Fade out music
	jsr	SubCPUCmd

	bsr.w	ResetRespawnTable		; Clear respawn table
	clr.b	resetLevelFlags			; Clear level reset flags
	move.w	#1,levelRestart			; Restart the level
	bra.s	.DoReset

.CheckReset:
	andi.b	#$70,d0				; Was A, B, or C pressed?
	beq.w	Level_MainLoop			; If not, branch
	
.IsDemo:
	clr.b	lifeCount			; Set lives to 0

.DoReset:
	clr.b	paused.w			; Clear pause flag
	clr.w	demoMode			; Clear demo mode flag
	clr.b	lastCheckpoint			; Clear checkpoint flag
	if DEMO<>0
		move.w	#$800,demoDataIndex.w	; Stop the demo
	endif
	bra.w	LevelStart			; Restart the level

.NotPaused:
	bsr.w	UnpauseMusic			; Unpause music

	addq.w	#1,lvlFrameTimer		; Increment frame timer
	
	jsr	ObjectManager			; Load level objects
	jsr	RunObjects			; Run objects

	cmpi.w	#$800,demoDataIndex.w		; Is the demo over?
	beq.w	LevelStart			; If so, restart the level
	tst.w	levelRestart			; Is the level restarting?
	beq.s	.NoRestart			; If not, branch
	
	move.w	#1,GACOMCMD2			; Stop Bad Apple
	
.WaitSubCPUDone2:
	tst.w	GACOMSTAT0			; Is the Sub CPU done?
	bne.s	.WaitSubCPUDone2		; If not, wait
	bra.w	LevelStart
	
.NoRestart:
	tst.w	lvlDebugMode			; Are we in debug mode?
	bne.s	.DoScroll			; If so, branch
	cmpi.b	#6,objPlayerSlot+oRoutine.w	; Is the player dead?
	bcs.s	.DoScroll			; If not, branch
	move.w	cameraY.w,bottomBound.w		; Set the bottom boundary of the level to wherever the camera is
	move.w	cameraY.w,destBottomBound.w
	bra.s	.DrawObjects			; Don't handle level scrolling

.DoScroll:
	bsr.w	LevelScroll			; Handle level scrolling

.DrawObjects:
	jsr	DrawObjects			; Draw objects

	tst.w	timeStopTimer			; Is the time stop timer active?
	bne.s	.SkipPalCycle			; If so, branch
	bsr.w	PaletteCycle			; Handle palette cycling

.SkipPalCycle:
	jsr	LoadCamPLCIncr			; Load camera based PLCs
	bsr.w	ProcessPLCs			; Process PLCs
	bsr.w	UpdateGlobalAnims		; Update global animations

	bra.w	Level_MainLoop			; Loop

; -------------------------------------------------------------------------
; Load the player object
; -------------------------------------------------------------------------

LoadPlayer:
	lea	objPlayerSlot.w,a1		; Player object
	moveq	#1,d0				; Set player object ID
	move.b	d0,oID(a1)
	tst.b	resetLevelFlags			; Was the level reset midway?
	beq.s	.End				; If not, branch
	move.w	#$78,oPlayerHurt(a1)		; If so, make the player invulnerable for a bit

.End:
	rts

; -------------------------------------------------------------------------
; Restore zone flowers
; -------------------------------------------------------------------------

RestoreZoneFlowers:
	lea	flowerCount,a1			; Get flower count bsaed on time zone
	moveq	#0,d0
	move.b	timeZone,d0
	bclr	#7,d0
	move.b	(a1,d0.w),d0
	beq.s	.End				; There are no flowers, exit

	subq.b	#1,d0				; Fix flower count for DBF
	lea	dynObjects.w,a2			; Dynamic object RAM
	moveq	#0,d1				; Flower ID

.Loop:
	move.b	#$1F,oID(a2)			; Load a flower
	move.w	d1,d2				; Get flower position buffer index based on time zone
	add.w	d2,d2
	add.w	d2,d2
	moveq	#0,d3
	move.b	timeZone,d3
	bclr	#7,d3
	lsl.w	#8,d3
	add.w	d3,d2
	lea	flowerPosBuf,a3			; Get flower position
	move.w	(a3,d2.w),oX(a2)
	move.w	2(a3,d2.w),oY(a2)

	adda.w	#oSize,a2			; Next object
	addq.b	#1,d1				; Next flower
	dbf	d0,.Loop			; Loop until finished

.End:
	rts

; -------------------------------------------------------------------------
; Load level collision
; -------------------------------------------------------------------------

LoadLevelCollision:
	moveq	#0,d0				; Get level collision pointer
	move.b	levelZone,d0
	lsl.w	#2,d0
	move.l	LevelColIndex(pc,d0.w),collisionPtr.w
	rts

; -------------------------------------------------------------------------

LevelColIndex:
	dc.l	LevelCollision			; They are all the same. For some reason,
	dc.l	LevelCollision			; the Sonic CD team decided to keep this table
	dc.l	LevelCollision			; instead of just directly setting the pointer
	dc.l	LevelCollision
	dc.l	LevelCollision
	dc.l	LevelCollision
	dc.l	LevelCollision
	dc.l	LevelCollision

; -------------------------------------------------------------------------
; Handle global animations
; -------------------------------------------------------------------------

UpdateGlobalAnims:
	subq.b	#1,ringAnimTimer		; Decrement ring animation timer
	bpl.s	.Unknown			; If it hasn't run out, branch
	move.b	#7,ringAnimTimer		; Reset animation timer
	addq.b	#1,ringAnimFrame		; Increment frame
	andi.b	#3,ringAnimFrame		; Keep the frame in range

.Unknown:
	tst.b	ringLossAnimTimer		; Has the ring spill timer run out?
	beq.s	.End				; If so, branch
	moveq	#0,d0				; Increment frame accumulator
	move.b	ringLossAnimTimer,d0
	add.w	ringLossAnimAccum,d0
	move.w	d0,ringLossAnimAccum
	rol.w	#7,d0				; Set ring spill frame
	andi.w	#3,d0
	move.b	d0,ringLossAnimFrame
	subq.b	#1,ringLossAnimTimer		; Decrement ring spill timer

.End:
	rts

; -------------------------------------------------------------------------
; Play level music
; -------------------------------------------------------------------------

PlayLevelMusic:
	moveq	#0,d0				; Get time zone
	moveq	#0,d1
	move.b	timeZone,d0
	bclr	#7,d0
	tst.b	timeAttackMode			; Are we in time attack mode?
	bne.s	.Notfuture			; If so, branch
	cmpi.b	#2,d0				; Are we in the future?
	bne.s	.NotFuture			; If not, branch
	add.b	goodFuture,d0			; Apply good future flag

.NotFuture:
	move.b	levelZone,d1			; Send music play Sub CPU command
	add.w	d1,d1
	add.w	d1,d1
	add.w	d0,d1
	moveq	#0,d0
	move.b	MusicPlayCmds(pc,d1.w),d0
	jmp	SubCPUCmd

; -------------------------------------------------------------------------

MusicPlayCmds:
	dc.b	$80, $F, $11, $10		; PPZ
	dc.b	$80, $12, $14, $13		; CCZ
	dc.b	$80, $15, $17, $16		; TTZ
	dc.b	$80, $18, $1A, $19		; QQZ
	dc.b	$80, $1B, $1D, $1C		; WWZ
	dc.b	$80, $1E, $20, $1F		; SSZ
	dc.b	$80, $21, $66, $22		; MMZ

; -------------------------------------------------------------------------
; Play Palmtree Panic present music
; -------------------------------------------------------------------------

PlayLevelMusic2:
	move.w	#$F,d0				; Play PPZ present music
	jsr	SubCPUCmd
	; Continue to load the life icon

; -------------------------------------------------------------------------
; Load life icon
; -------------------------------------------------------------------------

LoadLifeIcon:
	move.l	#$74200002,d0			; Set VDP write command

	moveq	#0,d2				; Get pointer to life icon
	move.b	timeZone,d2
	bclr	#7,d2
	lsl.w	#7,d2
	move.l	d0,4(a6)
	lea	Art_LifeIcon,a1
	lea	(a1,d2.w),a3

	rept	32
		move.l	(a3)+,(a6)		; Load life icon
	endr

	rts

; -------------------------------------------------------------------------
; Pause the music
; -------------------------------------------------------------------------

PauseMusic:
	move.w	#$AB,d0				; Stop FM sound
	jsr	PlayFMSound

	bset	#7,paused.w			; Set the music as paused
	bne.s	.End				; If it was already paused, branch

	move.b	timeZone,d0			; Get time zone
	bclr	#7,d0
	tst.b	d0				; Are we in the past?
	beq.s	.Past				; If so, branch

.PauseMusic:
	move.w	#$D5,d0				; Pause CD music
	jmp	SubCPUCmd

.Past:
	tst.b	invincibleFlag			; Are we invincible?
	bne.s	.PauseMusic			; If so, pause the invincibility music
	tst.b	speedShoesFlag			; Do we have speed shoes?
	bne.s	.PauseMusic			; If so, pause the speed shoes music

	move.w	#$90,d0				; Pause PCM music
	jmp	SubCPUCmd

.End:
	rts

; -------------------------------------------------------------------------
; Unpause music
; -------------------------------------------------------------------------

UnpauseMusic:
	bclr	#7,paused.w			; Set the music as unpaused
	beq.s	.End				; If it was already unpaused, branch

	move.b	timeZone,d0			; Get time zone
	bclr	#7,d0
	tst.b	d0				; Are we in the past?
	beq.s	.Past				; If so, branch

.UnpauseMusic:
	move.w	#$D6,d0				; Unpause CD music
	jmp	SubCPUCmd

.Past:
	tst.b	invincibleFlag			; Are we invincible?
	bne.s	.UnpauseMusic			; If so, unpause the invincibility music
	tst.b	speedShoesFlag			; Do we have speed shoes?
	bne.s	.UnpauseMusic			; If so, unpause the speed shoes music

	move.w	#$91,d0				; Unpause PCM music
	jmp	SubCPUCmd

.End:
	rts

; -------------------------------------------------------------------------
; Vertical interrupt routine
; -------------------------------------------------------------------------

VInterrupt:
	move	#$2700,sr			; Disable interrupts

	bset	#0,GAIRQ2			; Send Sub CPU IRQ2 request
	movem.l	d0-a6,-(sp)			; Save registers
	
	move.w	VDPCTRL,d0			; Reset V-BLANK flag

	tst.b	vintRoutine.w			; Are we lagging?
	beq.s	VInt_Lag			; If so, branch
	
	bsr.w	UpdateBadApple			; Update Bad Apple

	move.l	#$40020010,VDPCTRL		; Update VScroll
	move.w	vscrollScreen+2.w,VDPDATA

	move.b	vintRoutine.w,d0		; Get V-INT routine ID
	move.b	#0,vintRoutine.w		; Mark V-INT as run
	andi.w	#$3E,d0
	move.w	VInt_Index(pc,d0.w),d0		; Run the current V-INT routine
	jsr	VInt_Index(pc,d0.w)

VInt_Finish:
	jsr	UpdateFMQueues			; Update FM driver queues
	addq.l	#1,lvlFrameCount		; Increment frame counter

	movem.l	(sp)+,d0-a6			; Restore registers
	
HInterrupt:
	rte

; -------------------------------------------------------------------------

VInt_Index:
	dc.w	VInt_Lag-VInt_Index		; Lag
	dc.w	VInt_General-VInt_Index		; General
	dc.w	VInt_S1Title-VInt_Index		; Sonic 1 title screen (leftover)
	dc.w	VInt_Unk6-VInt_Index		; Unknown (leftover)
	dc.w	VInt_Level-VInt_Index		; Level
	dc.w	VInt_S1SpecStg-VInt_Index	; Sonic 1 special stage (leftover)
	dc.w	VInt_LevelLoad-VInt_Index	; Level load
	dc.w	VInt_UnkE-VInt_Index		; Unknown (leftover)
	dc.w	VInt_Pause-VInt_Index		; Sonic 1 pause (leftover)
	dc.w	VInt_PalFade-VInt_Index		; Palette fade
	dc.w	VInt_S1SegaScr-VInt_Index	; Sonic 1 SEGA screen (leftover)
	dc.w	VInt_S1ContScr-VInt_Index	; Sonic 1 continue screen (leftover)
	dc.w	VInt_LevelLoad-VInt_Index	; Level load

; -------------------------------------------------------------------------
; V-INT lag routine
; -------------------------------------------------------------------------

VInt_Lag:
	tst.b	levelStarted			; Has the level started?
	beq.w	VInt_Finish			; If not, branch
	
	bsr.w	UpdateBadApple			; Update Bad Apple
	
	jsr	StopZ80				; Stop the Z80
	lea	VDPCTRL,a5			; VDP control port
	move.l	#$94009340,(a5)			; DMA palette buffer
	move.l	#$96009500|((palette>>1)&$FF)|((palette<<7)&$FF0000),(a5)
	move.w	#$9700|((palette>>17)&$7F),(a5)
	move.w	#$C000,(a5)
	move.w	#$80,-(sp)
	move.w	(sp)+,(a5)
	jsr	StartZ80			; Start the Z80

	bra.w	VInt_Finish			; Finish V-INT

; -------------------------------------------------------------------------
; V-INT general routine
; -------------------------------------------------------------------------

VInt_General:
	bsr.w	DoVIntUpdates			; Do V-INT updates

	tst.w	vintTimer.w			; Is the V-INT timer running?
	beq.w	.End				; If not, branch
	subq.w	#1,vintTimer.w			; Decrement V-INT timer

.End:

VInt_S1SegaScr:
VInt_S1Title:
VInt_Unk6:
VInt_Pause:
VInt_S1SpecStg:
VInt_UnkE:
VInt_S1ContScr:
	rts

; -------------------------------------------------------------------------
; V-INT level routine
; -------------------------------------------------------------------------

VInt_Level:
	jsr	StopZ80				; Stop the Z80
	bsr.w	ReadControllers			; Read controllers
	
	tst.b	paused.w			; Is the game paused?
	bne.s	.NoTimers			; If so, branch
	bsr.w	RunBoredTimer			; Run boredom timer
	bsr.w	RunTimeWarp			; Run time warp timer

.NoTimers:
	lea	VDPCTRL,a5			; VDP control port

	move.l	#$94009340,(a5)			; DMA palette
	move.l	#$96009500|((palette>>1)&$FF)|((palette<<7)&$FF0000),(a5)
	move.w	#$9700|((palette>>17)&$7F),(a5)
	move.w	#$C000,(a5)
	move.w	#$80,-(sp)
	move.w	(sp)+,(a5)

	move.l	#$940193C0,(a5)			; DMA HScroll
	move.l	#$96009500|((hscroll>>1)&$FF)|((hscroll<<7)&$FF0000),(a5)
	move.w	#$9700|((hscroll>>17)&$7F),(a5)
	move.w	#$7C00,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	move.l	#$94019340,(a5)			; DMA sprites
	move.l	#$96009500|((sprites>>1)&$FF)|((sprites<<7)&$FF0000),(a5)
	move.w	#$9700|((sprites>>17)&$7F),(a5)
	move.w	#$7800,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	tst.b	updateSonicArt.w		; Load player sprite art
	beq.s	.NoArtLoad
	lea	VDPCTRL,a5
	move.l	#$94019370,(a5)
	move.l	#$96009500|((sonicArtBuf>>1)&$FF)|((sonicArtBuf<<7)&$FF0000),(a5)
	move.w	#$9700|((sonicArtBuf>>17)&$7F),(a5)
	move.w	#$7000,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)
	move.b	#0,updateSonicArt.w

.NoArtLoad:
	jsr	JmpTo_LoadShieldArt		; Load shield art
	jsr	StartZ80			; Start the Z80

	movem.l	cameraX.w,d0-d7			; Draw level
	movem.l	d0-d7,lvlCamXCopy
	move.w	scrollFlags.w,lvlScrollFlagsCopy
	move.w	scrollFlagsBg.w,lvlScrollFlagsCopy+2
	bsr.w	DrawLevel

	bsr.w	DecompPLCSlow			; Process PLC art decompression
	jmp	UpdateHUD			; Update the HUD

; -------------------------------------------------------------------------
; V-INT level load routine
; -------------------------------------------------------------------------

VInt_LevelLoad:
	jsr	StopZ80				; Stop the Z80
	bsr.w	ReadControllers			; Read controllers

	lea	VDPCTRL,a5			; DMA palette
	move.l	#$94009340,(a5)
	move.l	#$96009500|((palette>>1)&$FF)|((palette<<7)&$FF0000),(a5)
	move.w	#$9700|((palette>>17)&$7F),(a5)
	move.w	#$C000,(a5)
	move.w	#$80,-(sp)
	move.w	(sp)+,(a5)

	lea	VDPCTRL,a5			; DMA HScroll
	move.l	#$940193C0,(a5)
	move.l	#$96009500|((hscroll>>1)&$FF)|((hscroll<<7)&$FF0000),(a5)
	move.w	#$9700|((hscroll>>17)&$7F),(a5)
	move.w	#$7C00,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	lea	VDPCTRL,a5			; DMA sprites
	move.l	#$94019340,(a5)
	move.l	#$96009500|((sprites>>1)&$FF)|((sprites<<7)&$FF0000),(a5)
	move.w	#$9700|((sprites>>17)&$7F),(a5)
	move.w	#$7800,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	jsr	StartZ80			; Start the Z80

	movem.l	cameraX.w,d0-d7			; Draw level
	movem.l	d0-d7,lvlCamXCopy
	movem.l	scrollFlags.w,d0-d1
	movem.l	d0-d1,lvlScrollFlagsCopy
	bsr.w	DrawLevel

	bra.w	DecompPLCFast			; Process PLC art decompression

; -------------------------------------------------------------------------
; V-INT palette fade routine
; -------------------------------------------------------------------------

VInt_PalFade:
	bsr.w	DoVIntUpdates			; Do V-INT updates

	cmpi.b	#1,lvlEnableDisplay		; Should we enable display?
	bne.s	.SetHIntCounter			; If not, branch
	addq.b	#1,lvlEnableDisplay		; Set display as enabled

	move.w	vdpReg01.w,d0			; Enable display
	ori.b	#$40,d0
	move.w	d0,VDPCTRL

.SetHIntCounter:
	bra.w	DecompPLCFast			; Process PLC art decompression

; -------------------------------------------------------------------------
; Do common V-INT updates
; -------------------------------------------------------------------------

DoVIntUpdates:
	jsr	StopZ80				; Stop the Z80
	bsr.w	ReadControllers			; Read controllers

	tst.b	waterFullscreen.w		; Is water filling the screen?
	bne.s	.WaterPal			; If so, branch
	lea	VDPCTRL,a5			; DMA palette
	move.l	#$94009340,(a5)
	move.l	#$96009500|((palette>>1)&$FF)|((palette<<7)&$FF0000),(a5)
	move.w	#$9700|((palette>>17)&$7F),(a5)
	move.w	#$C000,(a5)
	move.w	#$80,-(sp)
	move.w	(sp)+,(a5)
	bra.s	.LoadedPal

.WaterPal:
	lea	VDPCTRL,a5			; DMA water palette
	move.l	#$94009340,(a5)
	move.l	#$96009500|((waterPalette>>1)&$FF)|((waterPalette<<7)&$FF0000),(a5)
	move.w	#$9700|((waterPalette>>17)&$7F),(a5)
	move.w	#$C000,(a5)
	move.w	#$80,-(sp)
	move.w	(sp)+,(a5)

.LoadedPal:
	lea	VDPCTRL,a5			; DMA sprites
	move.l	#$94019340,(a5)
	move.l	#$96009500|((sprites>>1)&$FF)|((sprites<<7)&$FF0000),(a5)
	move.w	#$9700|((sprites>>17)&$7F),(a5)
	move.w	#$7800,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	lea	VDPCTRL,a5			; DMA HScroll
	move.l	#$940193C0,(a5)
	move.l	#$96009500|((hscroll>>1)&$FF)|((hscroll<<7)&$FF0000),(a5)
	move.w	#$9700|((hscroll>>17)&$7F),(a5)
	move.w	#$7C00,(a5)
	move.w	#$83,-(sp)
	move.w	(sp)+,(a5)

	jmp	StartZ80			; Start the Z80

; -------------------------------------------------------------------------
; Run time warp timer
; -------------------------------------------------------------------------

RunTimeWarp:
	tst.b	objPlayerSlot+oPlayerCharge.w	; Is the player charging?
	bne.s	.End				; If so, branch
	tst.w	timeWarpTimer.w			; Is the time warp timer active?
	beq.s	.End				; If not, branch	
	addq.w	#1,timeWarpTimer.w		; Increment time warp timer

.End:
	rts

; -------------------------------------------------------------------------
; Run boredom timer
; -------------------------------------------------------------------------

RunBoredTimer:
	tst.w	boredTimer.w			; Is the bored timer active?
	beq.s	.CheckP2Timer			; If not, branch
	addq.w	#1,boredTimer.w			; Increment bored timer

.CheckP2Timer:
	tst.w	boredTimerP2.w			; Is the player 2 bored timer active?
	beq.s	.End				; If not, branch
	addq.w	#1,boredTimerP2.w		; Increment player 2 bored timer

.End:
	rts

; -------------------------------------------------------------------------
