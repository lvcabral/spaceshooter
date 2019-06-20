;===============================================================================
; Constants

Bunker1Color = Green
Bunker2Color = Yellow
Bunker3Color = Orange

BunkerCharGroup = 80

BunkerTopLeftChar = 80
BunkerTopRightChar = 81
BunkerSolidChar = 82
BunkerBottomChar = 83

;===============================================================================
; Variables

bunker1StartX   byte 5
bunker2StartX   byte 17
bunker3StartX   byte 29
bunkersStartY   byte 18
bunkersDrawY    byte 0 ;used when drawing the bunkers

; /XXXX\   <- top line
; XXXXXX   <- middle line
; XX^^XX   <- bottom line
bunkerTopLine   byte BunkerTopLeftChar
                dcb 4, BunkerSolidChar
                byte BunkerTopRightChar
                byte 0
bunkerMiddleLine        
                dcb 6, BunkerSolidChar
                byte 0
bunkerBottomLine 
                dcb 2, BunkerSolidChar
                dcb 2, BunkerBottomChar
                dcb 2, BunkerSolidChar
                byte 0

bunkersXCharCol byte 0
bunkersYCharCol byte 0

;===============================================================================
; Macros/Subroutines

drawBunkers
        lda bunkersStartY
        sta bunkersDrawY
        LIBSCREEN_DRAWTEXT_AAAV bunker1StartX, bunkersDrawY, bunkerTopLine, Bunker1Color
        LIBSCREEN_DRAWTEXT_AAAV bunker2StartX, bunkersDrawY, bunkerTopLine, Bunker2Color
        LIBSCREEN_DRAWTEXT_AAAV bunker3StartX, bunkersDrawY, bunkerTopLine, Bunker3Color

        inc bunkersDrawY
        LIBSCREEN_DRAWTEXT_AAAV bunker1StartX, bunkersDrawY, bunkerMiddleLine, Bunker1Color
        LIBSCREEN_DRAWTEXT_AAAV bunker2StartX, bunkersDrawY, bunkerMiddleLine, Bunker2Color
        LIBSCREEN_DRAWTEXT_AAAV bunker3StartX, bunkersDrawY, bunkerMiddleLine, Bunker3Color

        inc bunkersDrawY
        LIBSCREEN_DRAWTEXT_AAAV bunker1StartX, bunkersDrawY, bunkerBottomLine, Bunker1Color
        LIBSCREEN_DRAWTEXT_AAAV bunker2StartX, bunkersDrawY, bunkerBottomLine, Bunker2Color
        LIBSCREEN_DRAWTEXT_AAAV bunker3StartX, bunkersDrawY, bunkerBottomLine, Bunker3Color
        rts

;===============================================================================

defm    GAMEBUNKERS_COLLIDED_AA ; /1 = XChar            (Address)
                                ; /2 = YChar            (Address)
        lda /1
        sta bunkersXCharCol
        lda /2
        sta bunkersYCharCol
        jsr gameBunkers_Collided
        endm

gameBunkers_Collided

        LIBSCREEN_SETCHARPOSITION_AA bunkersXCharCol, bunkersYCharCol
        LIBSCREEN_GETCHAR_ACC
        and #%11111000 ; use bitmask to check if char belongs to bunker
        cmp #BunkerCharGroup
        beq bunkerHit
        lda #False
        rts

bunkerHit
        ; check if a damaged bunker char was hit
        LIBSCREEN_GETCHAR_ACC
        and #%00000100 ; damaged bunker chars have 3rd bit set
        bne clearBunkerChar 

        ; show damaged version of the bunker char
        LIBSCREEN_GETCHAR_ACC
        ora #%00000100 ; set 3rd bit to damage the bunker char
        jmp drawChar

clearBunkerChar
        lda #SpaceCharacter ; remove/clear bunker char

drawChar
        LIBSCREEN_SETCHAR_ACC
        lda #True
        rts
