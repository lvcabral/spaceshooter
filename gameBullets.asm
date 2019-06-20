; Sprite top left corner to char coordinates:
; int((spr_x-24)/8), int((spr_y-50)/8) 
;===============================================================================
; Constants

BulletsMax = 10
Bullet1stCharacter = 64

;===============================================================================
; Variables

bulletsXHigh    byte 0
bulletsXLow     byte 0     
bulletsY        byte 0
bulletsXCharCurrent byte 0
bulletsXOffsetCurrent byte 0
bulletsYCharCurrent byte 0
bulletsColorCurrent byte 0
bulletsDirCurrent byte 0

bulletsActive   dcb BulletsMax, 0
bulletsXChar    dcb BulletsMax, 0
bulletsYChar    dcb BulletsMax, 0
bulletsXOffset  dcb BulletsMax, 0
bulletsColor    dcb BulletsMax, 0
bulletsDir      dcb BulletsMax, 0
bulletsTemp     byte 0
bulletsXFlag    byte 0

bulletsXCharCol byte 0
bulletsYCharCol byte 0
bulletsDirCol   byte 0

;===============================================================================
; Macros/Subroutines

defm    GAMEBULLETS_FIRE_AAAVV  ; /1 = XChar            (Address)
                                ; /2 = XOffset          (Address)
                                ; /3 = YChar            (Address)
                                ; /4 = Color            (Value)
                                ; /5 = Direction (True-Up, False-Down) (Value)
        ldx #0
@loop
        lda bulletsActive,X
        bne @skip

        ; save the current bullet in the list
        lda #1
        sta bulletsActive,X
        lda /1
        sta bulletsXChar,X
        
        clc
        lda /2 ; get the character offset
        adc #Bullet1stCharacter ; add on the bullet first character
        sta bulletsXOffset,X

        lda /3
        sta bulletsYChar,X
        lda #/4
        sta bulletsColor,X
        lda #/5
        sta bulletsDir,X

        ; found a slot, quit the loop
        jmp @found
@skip
        ; loop for each bullet
        inx
        cpx #BulletsMax
        bne @loop
@found
        endm

;===============================================================================

gameBulletsGet
        lda bulletsXChar,X
        sta bulletsXCharCurrent
        lda bulletsXOffset,X
        sta bulletsXOffsetCurrent
        lda bulletsYChar,X
        sta bulletsYCharCurrent
        lda bulletsColor,X
        sta bulletsColorCurrent
        lda bulletsDir,X
        sta bulletsDirCurrent
        rts

;==============================================================================

gameBulletsReset

        ldx #0
        
gBRLoop
        lda bulletsActive,x
        beq gBRSkip

        ; remove the bullet from the screen
        jsr gameBulletsGet
        LIBSCREEN_SETCHARPOSITION_AA bulletsXCharCurrent, bulletsYCharCurrent
        LIBSCREEN_SETCHAR_V SpaceCharacter

        lda #0
        sta bulletsActive,x

gBRSkip
        inx
        cpx #BulletsMax
        bne gBRLoop       ; loop for each bullet

        rts

;===============================================================================

gameBulletsUpdate

        ldx #0
buloop
        lda bulletsActive,X
        bne buok
        jmp skipBulletUpdate
buok
        ; get the current bullet from the list
        jsr gameBulletsGet

        LIBSCREEN_SETCHARPOSITION_AA bulletsXCharCurrent, bulletsYCharCurrent
        LIBSCREEN_SETCHAR_V SpaceCharacter
        lda bulletsDirCurrent
        beq @down
@up
        ;dec bulletsYCharCurrent
        ;bpl @skip
        ;jmp @dirdone
        ldy bulletsYCharCurrent
        dey
        sty bulletsYCharCurrent
        cpy #0; this leave a row empty at the top for the scores
        bne @skip
        jmp @dirdone

@down
        ldy bulletsYCharCurrent
        iny
        sty bulletsYCharCurrent
        cpy #25
        bne @skip
@dirdone

        lda #0
        sta bulletsActive,X
        jmp skipBulletUpdate        
@skip
        ;test if bullet has hit a bunker
        GAMEBUNKERS_COLLIDED_AA bulletsXCharCurrent, bulletsYCharCurrent
        bne bulletHitBunker
        jmp drawBullet

bulletHitBunker
        ; remove/disable the bullet
        lda #0
        sta bulletsActive,X
        jmp skipBulletUpdate

drawBullet
        ; set the bullet color
        LIBSCREEN_SETCOLORPOSITION_AA bulletsXCharCurrent, bulletsYCharCurrent
        LIBSCREEN_SETCHAR_A bulletsColorCurrent
        
        ; set the bullet character
        LIBSCREEN_SETCHARPOSITION_AA bulletsXCharCurrent, bulletsYCharCurrent
        LIBSCREEN_SETCHAR_A bulletsXOffsetCurrent

        lda bulletsYCharCurrent
        sta bulletsYChar,X

skipBulletUpdate

        inx
        cpx #BulletsMax
        ;bne @loop       ; loop for each bullet
        beq @finished
        jmp buloop
@finished
        
        rts

;===============================================================================

defm    GAMEBULLETS_COLLIDED    ; /1 = XChar            (Address)
                                ; /2 = YChar            (Address)
                                ; /3 = Direction (True-Up, False-Down) (Value)

        lda /1
        sta bulletsXCharCol
        lda /2
        sta bulletsYCharCol
        lda #/3
        sta bulletsDirCol
        jsr gameBullets_Collided
        endm

gameBullets_Collided

        ldx #0
@loop
        ; skip this bullet if not active
        lda bulletsActive,X
        beq @skip

        ; skip if up/down not equal
        lda bulletsDir,X
        cmp bulletsDirCol
        bne @skip

        ; skip if currentbullet YChar != YChar
        lda bulletsYChar,X
        cmp bulletsYCharCol
        bne @skip

        lda #0
        sta bulletsXFlag

        ; skip if currentbullet XChar != XChar
        ldy bulletsXChar,X
        cpy bulletsXCharCol
        bne @xminus1
        lda #1
        sta bulletsXFlag
        jmp @doneXCheck

@xminus1
        ; skip if currentbullet XChar-1 != XChar
        dey
        cpy bulletsXCharCol
        bne @xplus1
        lda #1
        sta bulletsXFlag
        jmp @doneXCheck
@xplus1
        ; skip if currentbullet XChar+1 != XChar
        iny
        iny
        cpy bulletsXCharCol
        bne @doneXCheck
        lda #1
        sta bulletsXFlag

@doneXCheck
        lda bulletsXFlag
        beq @skip
   
        ; collided
        lda #0
        sta bulletsActive,X ; disable bullet

        ; delete bullet from screen
        lda bulletsXChar,X
        sta bulletsXCharCurrent
        lda bulletsYChar,X
        sta bulletsYCharCurrent
        LIBSCREEN_SETCHARPOSITION_AA bulletsXCharCurrent, bulletsYCharCurrent
        LIBSCREEN_SETCHAR_V SpaceCharacter

        lda #1 ; set as collided
        jmp @collided
@skip
        ; loop for each bullet
        inx
        cpx #BulletsMax
        bne @loop

        ; set as not collided
        lda #0

@collided

        rts


