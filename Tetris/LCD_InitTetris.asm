BUS_KHZ             def       2000

REGS                equ       $0800
PORTG               equ       REGS+$28            ; Expanded Address of Command
DDRG                equ       REGS+$2A
PORTH               equ       REGS+$29            ; Expanded Address of Data
DDRH                equ       REGS+$2B

BIT_0               equ       1                   ; /RESET
BIT_1               equ       2                   ; /READ
BIT_2               equ       4                   ; /WRITE
BIT_3               equ       8                   ; /CS
BIT_4               equ       16                  ; A0

;*******************************************************************************
                    #RAM
;*******************************************************************************

cursor_init         rmb       2
c_pointer           rmb       2
cs_pointer          rmb       2
cc_pointer          rmb       2
.stage_block        rmb       2
.block              rmb       2

SOME_VALUE          def       0

MEM_WRITE           equ       $42

;*******************************************************************************
                    #ROM      $1000
;*******************************************************************************

Start               proc
                    jsr       LCD_INIT
                    swi

;*******************************************************************************
; Init Cursor Pointers to starting position (void)

InitCurPointers     proc
                    pshx
                    ldx       cursor_init
                    stx       c_pointer
                    stx       cs_pointer
                    pulx
                    rts

;*******************************************************************************
; Draws Shape based on values in memory (void)

DrawShape           proc
                    push
                    bsr       ClearShape
                    ldd       cursor_init
                    addd      .stage_block
                    std       cc_pointer
                    std       c_pointer

                    ldx       .block              ;*** CheckLocation

                    lda       #MEM_WRITE          ; init memory write
                    jsr       LCD_Command

Loop@@              lda       1,x
                    dex
                    ldd       c_pointer
                    decd
                    bsr       UpdateCursor
                    ldy       #8
_@@                 lsla
                    bcs       Square
                    dey
                    bne       _@@
          ;-------------------------------------- ; Check
                    cmpx      #SOME_VALUE
                    bne       Loop@@
                    pull
                    rts

;*******************************************************************************
; Clears old shape based on cs_pointer which has old cursor position (void)

ClearShape          proc
                    push
                    ldd       cc_pointer
                    bsr       UpdateCursor        ; Set Cursor to start of shape
                    ldy       #4
                    lda       #MEM_WRITE
                    jsr       LCD_Command
                    clra
Loop@@              ldx       #78
_1@@                bsr       ?LCD_Data
                    dex
                    bne       _1@@
                    dey
                    beq       Done@@
          ;--------------------------------------
                    ldd       cc_pointer
                    decd
                    std       cc_pointer
                    bsr       UpdateCursor
                    bra       Loop@@
          ;--------------------------------------
Done@@              pull
                    rts

;*******************************************************************************
; Draws single square within shape (void)

Square              proc
                    psha
                    pshx
                    ldd       c_pointer
                    bsr       UpdateCursor
                    ldx       #8
                    lda       #$FF
Loop@@              bsr       ?LCD_Data
                    dex
                    bne       Loop@@
                    clra
                    bsr:2     ?LCD_Data
                    pulx
                    pula
                    rts

;*******************************************************************************
                              #Cycles
?Delay_3ms          proc
                    pshx
                    ldx       #DELAY@@            ;WAS: $FFFF
                              #Cycles
Loop@@              dex
                    bne       Loop@@
                              #temp :cycles
                    pulx
                    rts

DELAY@@             equ       3*BUS_KHZ-:cycles-:ocycles/:temp

;*******************************************************************************
; Requires D have cursor position (D)

UpdateCursor        proc
                    psha
                    lda       #$46
                    jsr       LCD_Command
                    pula
                    bsr       ?LCD_Data
                    tba
?LCD_Data           jmp       LCD_Data

;*******************************************************************************

LCD_INIT            proc
                    psha
                    pshx
                    ldx       #REGS

                    lda       #$FF
                    sta       [DDRG,x
                    sta       [DDRH,x

                    lda       #$1F
                    sta       [PORTG,x            ; Init PORTG

                    bclr      [PORTG,x,BIT_0      ; RESET LOW
                    bsr       ?Delay_3ms

                    bset      [PORTG,x,BIT_0      ; Reset Complete PORTG
                    bsr       ?Delay_3ms

                    lda       #$58                ; Turn off Display
                    bsr       LCD_Command
          ;-------------------------------------- ; Init Setup
                    lda       #$40
                    bsr       LCD_Command
                    lda       #$30
                    bsr       ?LCD_Data
                    lda       #$87                ; 8-2 frame AC Drive 7 - Char Width FX
                    bsr       LCD_Data
                    lda       #$07                ; Char Height FY
                    bsr       LCD_Data
                    lda       #$1F                ; 32 Diplay bites per line
                    bsr       LCD_Data
                    lda       #$23                ; Total addr range per line TC/R (C/R+4 H-Blanking)
                    bsr       LCD_Data
                    lda       #$7F                ; 128 diplay lines L/F
                    bsr       LCD_Data
                    lda       #$20                ; Low Bite APL (Virtual Screen)
                    bsr       LCD_Data
                    clra                          ; High Bite APL (Virtual Screen)
                    bsr       LCD_Data
          ;-------------------------------------- ; Scroll Settings
                    lda       #$44                ; Set Scroll Command
                    bsr       LCD_Command
                    clra                          ; Layer 1 Start Address
                    bsr:2     LCD_Data            ; Lower byte and High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    clra                          ; Layer 2 Start Address
                    bsr       LCD_Data            ; Lower byte
                    lda       #$10
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    clra
                    bsr       LCD_Data            ; Layer 3 Start Address
                    lda       #$20
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
          ;-------------------------------------- ; Horizonal Scroll Set
                    lda       #$5A                ; Horizonal Scroll CMD
                    bsr       LCD_Command
                    clra                          ; At Origin on X
                    bsr       LCD_Data
          ;-------------------------------------- ; Overlay Settings
                    lda       #$5B
                    bsr       LCD_Command         ; Overlay CMD
                    lda       #$1C
                    bsr       LCD_Data            ; 3 layers, Graphics,OR layers

                    lda       #$4F                ; Curser auto inc AP+1
                    bsr       LCD_Command
          ;-------------------------------------- ; Set Cursor location
                    lda       #$46
                    bsr       LCD_Command         ; Set Cursor
                    clra
                    bsr:2     LCD_Data            ; to 0000h
          ;-------------------------------------- ; Clear Memeory
                    clrx
                    lda       #$42
                    bsr       LCD_Command

                    clra                          ; Zero
Loop@@              bsr       LCD_Data
                    inx
                    cpx       #$3000
                    bne       Loop@@
          ;-------------------------------------- ; Turn on Display
                    lda       #$59
                    bsr       LCD_Command         ; Display On
                    lda       #%01010100          ; Layer 1,2 on layer 3,4, curser off
                    bsr       LCD_Data
          ;-------------------------------------- ; Set CGRAM
          #ifdef
                    lda       #$5C
                    bsr       LCD_Command
                    clra
                    bsr       LCD_Data
                    lda       #$04
                    bsr       LCD_Data
          #endif
          ;--------------------------------------
                    pulx
                    pula
                    rts

;*******************************************************************************
; PORTG
; bit0 - /Reset
; bit1 - /Read
; bit2 - /Write
; bit3 - /CS
; bit4 - A0

LCD_Command         proc
                    pshx
                    ldx       #REGS
                    bset      [PORTG,x,BIT_4      ; Set A0
                    bsr       ?LCD_Common
                    pulx
                    rts

;*******************************************************************************

LCD_Data            proc
                    pshx
                    ldx       #REGS
                    bclr      [PORTG,x,BIT_4      ; Clear A0
                    bsr       ?LCD_Common
                    pulx
                    rts

;*******************************************************************************

?LCD_Common         proc
                    sta       [PORTH,x            ; Write Command/Data
                    bset      [PORTG,x,BIT_1      ; Read disabled
                    bclr      [PORTG,x,BIT_3      ; CS enabled
                    bclr      [PORTG,x,BIT_2      ; Write enabled
                    psha
                    lda       #$FF
                    sta       [PORTG,x            ; Restore PG
                    pula
                    rts
