;===============================================================================
;  libMultiplex.asm - Sprite Multiplex & Sort
;
;  Original sprite multiplex & sort routine:
;  Copyright (C) 1998-2018 Lasse Öörni - <https://cadaver.github.io>
;  Animation Routines:
;  Copyright (C) 2017,2018 RetroGameDev - <https://www.retrogamedev.com>
;  Macros, improvements and adaptation:
;  Copyright (C) 2018,2019 Marcelo Lv Cabral - <https://lvcabral.com>
;
;  Distributed under the MIT software license, see the accompanying
;  file LICENSE or https://opensource.org/licenses/MIT
;
;===============================================================================
; Constants

MAXSPR          = 16            ;Maximum number of sprites (8, 16 or 24)
MINSPRY         = 35            ;Minimum visible sprite Y-coordinate
MAXSPRY         = 245           ;Maximum visible sprite Y-coordinate + 1
IRQ1LINE        = 251           ;Screen raster line where IRQ happens
HideY           = 255

;===============================================================================
; Page Zero

temp1           = $02
temp2           = $03
temp3           = $04
sprupdateflag   = $05           ;Update flag for IRQ
sortsprstart    = $06           ;First used sorted table index (doublebuffered)
sortsprend      = $07           ;Last used sorted table index + 1

shieldOrder     = $08
playerOrder     = $09

sprAnimaCurrent = $16
sprAnimaFrame   = $17
sprAnimaEndFrame= $18

spry            = $40           ;Y & order tables need to be on zeropage due to
sprorder        = $41+MAXSPR    ;addressing modes & sorting speed. It also needs
                                ;to have 17 elements to contain an endmark
irqenabled      = $8D

;===============================================================================
; Variables

sprxl           dcb MAXSPR,0    ;Unsorted sprite tables
sprxh           dcb MAXSPR,0
sprf            dcb MAXSPR,0
sprc            dcb MAXSPR,0
sprm            dcb MAXSPR,1
sprp            dcb MAXSPR,0

sortsprx        dcb MAXSPR*2,0  ;Sorted sprites are doublebuffered
sortsprd010     dcb MAXSPR*2,0
sortspry        dcb MAXSPR*2,0
sortsprf        dcb MAXSPR*2,0
sortsprc        dcb MAXSPR*2,0
sortsprm        dcb MAXSPR*2,1
sortsprp        dcb MAXSPR*2,0
sprirqline      dcb MAXSPR*2,0  ;Table used to control sprite IRQs

sprirqadvtbl    ;$d012 advance for raster IRQs based on number of sprites in the same IRQ
                byte -4,-5,-6,-7,-7,-8,-9,-10

d015tbl         ;Table of sprites that are "on" for $d015
                byte %00000000
                byte %00000001
                byte %00000011
                byte %00000111
                byte %00001111
                byte %00011111
                byte %00111111
                byte %01111111
                byte %11111111

sprortbl        ;Or table for $d010 manipulation, repeated for 2x max sprites (doublebuffer)
                byte $01,$02,$04,$08,$10,$20,$40,$80
                byte $01,$02,$04,$08,$10,$20,$40,$80
                byte $01,$02,$04,$08,$10,$20,$40,$80
                byte $01,$02,$04,$08,$10,$20,$40,$80
                byte $01,$02,$04,$08,$10,$20,$40,$80
                byte $01,$02,$04,$08,$10,$20,$40,$80

sprandtbl       ;And table likewise repeated for 2x max sprites
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
                byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

sprirqjumptbllo ;Jump table for starting the spriteIRQ at correct sprite
                byte <irq2_spr0
                byte <irq2_spr1
                byte <irq2_spr2
                byte <irq2_spr3
                byte <irq2_spr4
                byte <irq2_spr5
                byte <irq2_spr6
                byte <irq2_spr7

sprirqjumptblhi byte >irq2_spr0
                byte >irq2_spr1
                byte >irq2_spr2
                byte >irq2_spr3
                byte >irq2_spr4
                byte >irq2_spr5
                byte >irq2_spr6
                byte >irq2_spr7

; animation arrays
spriteAnimsActive          dcb MAXSPR, 0
spriteAnimsStartFrame      dcb MAXSPR, 0
spriteAnimsFrame           dcb MAXSPR, 0
spriteAnimsEndFrame        dcb MAXSPR, 0
spriteAnimsStopFrame       dcb MAXSPR, 0
spriteAnimsSpeed           dcb MAXSPR, 0
spriteAnimsDelay           dcb MAXSPR, 0
spriteAnimsLoop            dcb MAXSPR, 0

spriteNumberMask           byte %00000001, %00000010, %00000100, %00001000
                           byte %00010000, %00100000, %01000000, %10000000

;===============================================================================
; Macros/Subroutines

defm    LIBSPRITE_SETCOLOR_AV           ; /1 = Sprite Number    (Address)
                                       ; /2 = Color            (Value)
        ldy /1
        lda #/2
        sta sprc,y
        endm

;===============================================================================

defm    LIBSPRITE_SETCOLOR_AA           ; /1 = Sprite Number    (Address)
                                       ; /2 = Color            (Address)
        ldy /1
        lda /2
        sta sprc,y
        endm

;===============================================================================

defm    LIBSPRITE_SETCOLOR_A            ; /1 = Sprite Number    (Address)
        ldy /1
        sta sprc,y
        endm

;==============================================================================

defm    LIBSPRITE_SETFRAME_AA           ; /1 = Sprite Number    (Address)
                                        ; /2 = Frame Index      (Address)
        ldy /1
        
        clc     ; Clear carry before add
        lda /2  ; Get frame
        adc #SPRITERAM ; Add
         
        sta sprf,y
        endm

;==============================================================================

defm    LIBSPRITE_SETFRAME_AV           ; /1 = Sprite Number    (Address)
                                        ; /2 = Frame Index      (Value)
        ldy /1
        
        clc     ; Clear carry before add
        lda #/2  ; Get frame
        adc #SPRITERAM ; Add
         
        sta sprf,y
        endm

;===============================================================================

defm    LIBSPRITE_SETPRIORITY_AV        ; /1 = Sprite Number           (Address)
                                       ; /2 = True=Back, False=Front  (Value)
        ldy /1
        lda #/2
        sta sprp,y
        endm

;===============================================================================

defm    LIBSPRITE_SETPRIORITY_AA        ; /1 = Sprite Number           (Address)
                                       ; /2 = True=Back, False=Front  (Address)
        ldy /1
        lda /2
        sta sprp,y
        endm

;===============================================================================

defm    LIBSPRITE_SETPOSITION_AAAA      ; /1 = Sprite Number    (Address)
                                       ; /2 = XPos High Byte   (Address)
                                       ; /3 = XPos Low Byte    (Address)
                                       ; /4 = YPos             (Address)
        ldy /1
        lda /2
        sta sprxh,y
        lda /3
        sta sprxl,y
        lda /4
        sta spry,y
        endm

;===============================================================================

defm    LIBSPRITE_SETVERTICALTPOS_AA    ; /1 = Sprite Number    (Address)
                                       ; /2 = YPos             (Address)
        ldy /1
        lda /2
        sta spry,y
        endm

;===============================================================================

defm    LIBSPRITE_MULTICOLORENABLE_AV   ; /1 = Sprite Number (Address)
                                       ; /2 = Enable/Disable (Value)
        ldy /1
        lda #/2
        sta sprm,y
        endm

;===============================================================================

defm    LIBSPRITE_MULTICOLORENABLE_AA   ; /1 = Sprite Number (Address)
                                       ; /2 = Enable/Disable (Address)
        ldy /1
        lda /2
        sta sprm,y
        endm

;===============================================================================

defm    LIBSPRITE_SETMULTICOLORS_VV     ; /1 = Color 1          (Value)
                                        ; /2 = Color 2          (Value)
        lda #/1
        sta SPMC0
        lda #/2
        sta SPMC1
        endm

;==============================================================================

defm    LIBSPRITE_PLAYANIM_AVVVV         ; /1 = Sprite Number    (Address)
                                        ; /2 = StartFrame       (Value)
                                        ; /3 = EndFrame         (Value)
                                        ; /4 = Speed            (Value)
                                        ; /5 = Loop True/False  (Value)

        ldy /1

        lda #True
        sta spriteAnimsActive,y
        lda #/2
        sta spriteAnimsStartFrame,y
        sta spriteAnimsFrame,y
        lda #/3
        sta spriteAnimsEndFrame,y
        lda #/4
        sta spriteAnimsSpeed,y
        sta spriteAnimsDelay,y
        lda #/5
        sta spriteAnimsLoop,y

        endm

;==============================================================================

defm    LIBSPRITE_PLAYANIM_AAAVV         ; /1 = Sprite Number    (Address)
                                        ; /2 = StartFrame       (Address)
                                        ; /3 = EndFrame         (Address)
                                        ; /4 = Speed            (Value)
                                        ; /5 = Loop True/False  (Value)

        ldy /1

        lda #True
        sta spriteAnimsActive,y
        lda /2
        sta spriteAnimsStartFrame,y
        sta spriteAnimsFrame,y
        lda /3
        sta spriteAnimsEndFrame,y
        lda #/4
        sta spriteAnimsSpeed,y
        sta spriteAnimsDelay,y
        lda #/5
        sta spriteAnimsLoop,y

        endm

;==============================================================================

defm    LIBSPRITE_ISANIMPLAYING_A      ; /1 = Sprite Number    (Address)

        ldy /1
        lda spriteAnimsActive,y

        endm

;==============================================================================

defm    LIBSPRITE_STOPANIM_A            ; /1 = Sprite Number    (Address)

        ldy /1
        lda #0
        sta spriteAnimsActive,y

        endm

;===============================================================================

defm    LIBSPRITE_SETUPSPRITE_VAA        ; /1 = Sprite Number   (Value)
                                        ; /2 = X High Address  (Address)
                                        ; /3 = X Low Address   (Address)
        lda sortspry,x
        sta /3
        lda sortsprx,x
        ldy sortsprd010,x
        sta /2
        sty MSIGX
        lda sortsprf,x
        sta SPRITE0+/1
@multicolor
        lda spriteNumberMask+/1
        ldy sortsprm,x
        beq @disablemc
        ora SPMC
        sta SPMC
        jmp @priority
@disablemc
        eor #$FF
        and SPMC
        sta SPMC
@priority
        lda spriteNumberMask+/1
        ldy sortsprp,x
        beq @moveup
        ora SPBGPR
        sta SPBGPR
        jmp @color
@moveup
        eor #$FF
        and SPBGPR
        sta SPBGPR
@color
        lda sortsprc,x
        sta SP0COL+/1
endm

;===============================================================================
;Routine to init the sprite multiplexing system

libMultiplexInit
        lda #$00               ;Reset update flag & doublebuffer side
        sta sprupdateflag
        sta sortsprstart
        lda #True
        sta irqenabled
        ldx #MAXSPR            ;Init the order table with a 0,1,2,3,4,5.. order.
is_orderlist    
        txa                    ;Init all Y-coordinates with $ff (unused)
        sta sprorder,x
        lda #$FF
        sta spry,x
        dex
        bpl is_orderlist
initraster      
        sei                    ;Routine to init the raster interrupt system
        lda #<irq1
        sta CINVLOW
        lda #>irq1
        sta CINVHIGH
        lda #$7F               ;CIA interrupts off
        sta CIAICR
        sta CI2ICR
        lda #$01               ;Raster interrupt on
        sta IRQCTRL
        lda #27                ;High bit of interrupt position = 0
        sta SCROLY
        lda #IRQ1LINE          ;Line where next IRQ happens
        sta RASTER
        lda CIAICR             ;Acknowledge IRQ (to be sure)
        lda CI2ICR             ;Acknowledge IRQ (to be sure)
        cli
        lda #%11111111         ;Multicolor on all sprites by default
        sta SPMC
        rts

;===============================================================================
;Routine to reset the sprite multiplexing system (hide all sprites)

libMultiplexReset
        lda #$00               ;Reset update flag & doublebuffer side
        sta sprupdateflag
        sta sortsprstart
        sta SPENA              ;Hide all sprites now
        sta XXPAND             ;Reset sprite expand flags
        sta YXPAND

        ldx #MAXSPR            ;Init the order table with a 0,1,2,3,4,5.. order.
lmr_orderlist
        txa                    ;Init all Y-coordinates with $ff (unused)
        sta sprorder,x
        lda #$FF
        sta spry,x
        dex
        bpl lmr_orderlist
        lda #True
        sta irqenabled
        ; don't move this routine
        ; it needs to run sortsprites to avoid sprites to reappear for a frame

;===============================================================================
; Routine to sort the sprites, copy them to the sorted table, and
; arrange the sprite IRQ's beforehand

libMultiplexSortSprites
        lda sprupdateflag      ;Wait until IRQ is done with current sprite update
        bne libMultiplexSortSprites
        ;inc EXTCOL
        lda sortsprstart       ;Switch sprite doublebuffer side
        eor #MAXSPR
        sta sortsprstart
        ldx #$00
        stx temp3              ;D010 bits for first irq
        stx shieldOrder
        stx playerOrder
        txa
sspr_loop1      
        ldy sprorder,x         ;Check for Y-coordinates being in order
zpopt off
        cmp spry,y
zpopt on
        beq sspr_noswap2
        bcc sspr_noswap1
        stx temp1              ;If not in order, begin insertion loop
        sty temp2
        lda spry,y
        ldy sprorder-1,x
        sty sprorder,x
        dex
        beq sspr_swapdone1
sspr_swap1      
        ldy sprorder-1,x
        sty sprorder,x
zpopt off
        cmp spry,y
zpopt on
        bcs sspr_swapdone1
        dex
        bne sspr_swap1
sspr_swapdone1  
        ldy temp2
        sty sprorder,x
        ldx temp1
        ldy sprorder,x
sspr_noswap1    
        lda spry,y
sspr_noswap2    
        inx
        cpx #MAXSPR
        bne sspr_loop1
        ldx #$00
sspr_findfirst  
        ldy sprorder,x         ;Find upmost visible sprite
        lda spry,y
        cmp #MINSPRY
        bcs sspr_firstfound
        inx
        bne sspr_findfirst
sspr_firstfound 
        txa
        adc #<sprorder         ;Add one more, C=1 becomes 0
        sbc sortsprstart       ;subtract one more to cancel out
        sta sspr_copyloop1+1
        ldy sortsprstart
        tya
        adc #8-1               ;C=1
        sta sspr_copyloop1end+1;Set endpoint for first copyloop
        bpl sspr_copyloop1
sspr_copyloop1skip             ;Copyloop for the first 8 sprites
        inc sspr_copyloop1+1
sspr_copyloop1  
        ldx sprorder,y
        jsr sspr_saveorder     ;Save shield and player order
        lda spry,x             ;If reach the maximum Y-coord, all done
        cmp #MAXSPRY
        bcs sspr_copyloop1done
        sta sortspry,y
        lda sprc,x             ;Copy sprite's properties to sorted table
        sta sortsprc,y
        lda sprf,x
        sta sortsprf,y
        lda sprm,x
        sta sortsprm,y
        lda sprp,x
        sta sortsprp,y
        lda sprxl,x
        sta sortsprx,y
        lda sprxh,x            ;Handle sprite X coordinate MSB
        beq sspr_copyloop1msblow
        lda temp3
        ora sprortbl,y
        sta temp3
sspr_copyloop1msblow
        iny
sspr_copyloop1end
        cpy #$00
        bcc sspr_copyloop1
        lda temp3
        sta sortsprd010-1,y
        lda sortsprc-1,y       ;Make first irq endmark
        ora #$80
        sta sortsprc-1,y
        lda sspr_copyloop1+1   ;Copy sortindex from first copyloop
        sta sspr_copyloop2+1   ;To second
        bcs sspr_copyloop2
sspr_copyloop1done
        lda temp3
        sta sortsprd010-1,y
        sty temp1              ;Store sorted sprite end index
        cpy sortsprstart       ;Any sprites at all?
        beq sspr_nosprites
        lda sortsprc-1,y       ;Make first (and final) IRQ endmark
        ora #$80               ;(stored in the color table)
        sta sortsprc-1,y
        jmp sspr_finalendmark
sspr_nosprites  
        jmp sspr_alldone
sspr_copyloop2skip             ;Copyloop for subsequent sprites,
        inc sspr_copyloop2+1   ;with "9th sprite" (physical overlap) prevention
sspr_copyloop2  
        ldx sprorder,y
        jsr sspr_saveorder     ;Save shield and player order
        lda spry,x
        cmp #MAXSPRY
        bcs sspr_copyloop2done
        sta sortspry,y
        sbc #21-1
        cmp sortspry-8,y       ;Check for physical sprite overlap
        bcc sspr_copyloop2skip
        lda sprc,x
        sta sortsprc,y
        lda sprf,x
        sta sortsprf,y
        lda sprm,x
        sta sortsprm,y
        lda sprp,x
        sta sortsprp,y
        lda sprxl,x
        sta sortsprx,y
        lda sprxh,x
        beq sspr_copyloop2msblow
        lda sortsprd010-1,y
        ora sprortbl,y
        bne sspr_copyloop2msbdone
sspr_copyloop2msblow
        lda sortsprd010-1,y
        and sprandtbl,y
sspr_copyloop2msbdone
        sta sortsprd010,y
        iny
        bne sspr_copyloop2
sspr_copyloop2done
        sty temp1              ;Store sorted sprite end index
        ldy sspr_copyloop1end+1;Go back to the second IRQ start
        cpy temp1
        beq sspr_finalendmark
sspr_irqloop    
        sty temp2              ;Store IRQ startindex
        lda sortspry,y         ;C=0 here
        sbc #32                ;First sprite of IRQ  store the y-coord (21+12-1)
        sta sspr_irqycmp1+1    ;compare values
        adc #38                ;21+12+6-1
        sta sspr_irqycmp2+1
sspr_irqsprloop 
        iny
        cpy temp1
        bcs sspr_irqdone
        lda sortspry-8,y       ;Add next sprite to this IRQ?
sspr_irqycmp1   
        cmp #$00               ;(try to add as many as possible while
        bcc sspr_irqsprloop    ;avoiding glitches)
        lda sortspry,y
sspr_irqycmp2   
        cmp #$00
        bcc sspr_irqsprloop
sspr_irqdone    
        tya
        sbc temp2
        tax
        lda sprirqadvtbl-1,x
        ldx temp2
        adc sortspry,x
        sta sprirqline-1,x     ;Store IRQ start line (with advance)
        lda sortsprc-1,y       ;Make endmark
        ora #$80
        sta sortsprc-1,y
        cpy temp1              ;Sprites left?
        bcc sspr_irqloop
sspr_finalendmark
        lda #$00               ;Make final endmark
        sta sprirqline-1,y
sspr_alldone    
        sty sortsprend         ;Index of last sorted sprite + 1
        inc sprupdateflag      ;Increment the update flag which will be read by IRQ's
        ;dec EXTCOL
        rts

;===============================================================================

sspr_saveorder
        cpx #0
        beq sspr_foundshield
        cpx playerSprite
        beq sspr_foundplayer
        rts
sspr_foundshield
        sty shieldOrder
        rts
sspr_foundplayer
        sty playerOrder
        rts

;===============================================================================
; IRQ code
; IRQ at the bottom of the screen. Take sprite update from the main program and
; start showing the sprites

irq1            
        lda irqenabled
        bne irq1_process
        sta sprupdateflag
        inc IRQFLAG
        jmp IRQCONTINUE        ;IRQ disabled for direct sprite usage
irq1_process
        lda sprupdateflag      ;New sprites?
        beq irq1_nonewsprites
        lda #$00
        sta sprupdateflag
        lda sortsprstart
        sta irq1_sortsprstart+1;Copy sorted sprite start index for IRQ
        lda sortsprend
        sec
        sbc sortsprstart       ;Find out number of sprites
        cmp #$09               ;More than 8?
        bcc irq1_notover8
        lda #$08
irq1_notover8   
        tax
        lda d015tbl,x          ;Take the bit combination for $d015
        sta irq1_d015value+1
irq1_nonewsprites
irq1_d015value  
        lda #$00               ;Any sprites?
        sta SPENA
        bne irq1_hassprites
        inc IRQFLAG
        jmp IRQCONTINUE        ;If no sprites, can exit here
irq1_hassprites
        lda #<irq2
        sta $0314
        lda #>irq2
        sta $0315
irq1_sortsprstart
        ldx #$00               ;Go through the first sprite IRQ immediately
        ;inc EXTCOL

;===============================================================================
;IRQ for sprite displaying (repeated until done)

irq2_spr0
        LIBSPRITE_SETUPSPRITE_VAA 0, $D000, $D001
        bmi irq2_sprirqdone2   ;Color high bit functions as IRQ endmark
        inx
irq2_spr1
        LIBSPRITE_SETUPSPRITE_VAA 1, $D002, $D003
        bpl irq2_tospr2
irq2_sprirqdone2
        jmp irq2_sprirqdone
irq2_tospr2
        inx
irq2_spr2
        LIBSPRITE_SETUPSPRITE_VAA 2, $D004, $D005
        bmi irq2_sprirqdone3
        inx
irq2_spr3
        LIBSPRITE_SETUPSPRITE_VAA 3, $D006, $D007
        bpl irq2_tospr4
irq2_sprirqdone3
        jmp irq2_sprirqdone
irq2_tospr4
        inx
irq2_spr4
        LIBSPRITE_SETUPSPRITE_VAA 4, $D008, $D009
        bmi irq2_sprirqdone4
        inx
irq2_spr5
        LIBSPRITE_SETUPSPRITE_VAA 5, $D00A, $D00B
        bpl irq2_tospr6
irq2_sprirqdone4
        jmp irq2_sprirqdone
irq2_tospr6
        inx

irq2_spr6
        LIBSPRITE_SETUPSPRITE_VAA 6, $D00C, $D00D
        bmi irq2_sprirqdone
        inx
irq2_spr7
        LIBSPRITE_SETUPSPRITE_VAA 7, $D00E, $D00F
        bmi irq2_sprirqdone
        inx
irq2_tospr0
        jmp irq2_spr0
irq2_sprirqdone
        ;dec EXTCOL
        ldy sprirqline,x       ;Get startline of next IRQ
        beq irq2_alldone       ;(0 if was last)
        inx
        stx irq2_sprindex+1    ;Store next irq sprite start-index
        txa
        and #$07
        tax
        lda sprirqjumptbllo,x  ;Get the correct jump address for next sprite IRQ
        sta irq2_sprjump+1
        lda sprirqjumptblhi,x
        sta irq2_sprjump+2
        tya
        sta RASTER
        sec
        sbc #$03               ;Already late from the next IRQ?
        cmp RASTER
        bcc irq2_direct        ;If yes, execute directly
        inc IRQFLAG            ;Acknowledge IRQ
        jmp IRQCONTINUE        ;Otherwise end IRQ
irq2
irq2_direct
        ;inc EXTCOL
irq2_sprindex
        ldx #$00
irq2_sprjump
        jmp irq2_spr0
irq2_alldone    
        lda #<irq1
        sta CINVLOW
        lda #>irq1
        sta CINVHIGH
        lda #IRQ1LINE
        sta RASTER
        inc IRQFLAG
        jmp IRQCONTINUE        ;All spriteIRQ's done, return to the top of screen IRQ

;==============================================================================

libSpritesUpdate
        ldx #0

lSoULoop
        ; skip this sprite anim if not active
        lda spriteAnimsActive,x
        bne lSoUActive
        jmp lSoUSkip

lSoUActive
        stx sprAnimaCurrent
        lda spriteAnimsFrame,x
        sta sprAnimaFrame

        lda spriteAnimsEndFrame,x
        sta sprAnimaEndFrame

        dec spriteAnimsDelay,x
        bne lSoUSkip

        LIBSPRITE_SETFRAME_AA sprAnimaCurrent, sprAnimaFrame

        ; reset the delay
        lda spriteAnimsSpeed,x
        sta spriteAnimsDelay,x

        ; change the frame
        inc spriteAnimsFrame,x

        ; check if reached the end frame
        lda sprAnimaEndFrame
        cmp spriteAnimsFrame,x
        bcs lSoUSkip

        ; check if looping
        lda spriteAnimsLoop,x
        beq lSoUDestroy

        ; reset the frame
        lda spriteAnimsStartFrame,x
        sta spriteAnimsFrame,x
        jmp lSoUSkip

lSoUDestroy
        ; turn off
        lda #False
        sta spriteAnimsActive,x
        LIBSPRITE_SETVERTICALTPOS_AA sprAnimaCurrent, #HideY

lSoUSkip
        ; loop for each sprite anim
        inx
        cpx #MAXSPR
        beq lSoUFinished
        jmp lSoUloop

lSoUFinished
        rts

