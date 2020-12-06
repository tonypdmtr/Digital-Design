PORTG               equ       $0828               ; Expanded Address of Command
DDRG                equ       $082A
PORTH               equ       $0829               ; Expanded Address of Data
DDRH                equ       $082B

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
                    #ROM
;*******************************************************************************
                    org       $1000

Start               proc
                    jsr       LCD_INIT
                    swi

;*******************************************************************************
; Init Cursor Pointers to starting position (void)

InitCurPointers     proc
                    pshd
                    ldd       cursor_init
                    std       c_pointer
                    std       cs_pointer
                    puld
                    rts

;*******************************************************************************
; Draws Shape based on values in memory (void)

DrawShape           proc
                    pshd
                    pshx
                    pshy
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
                    xgdx
                    dex
                    xgdx
                    bsr       UpdateCursor
                    ldy       #8
_@@                 lsla
                    bcs       Square
                    dey
                    bne       _@@
          ;-------------------------------------- ; Check
                    cmpx      #SOME_VALUE
                    bne       Loop@@
                    puly
                    pulx
                    puld
                    rts

;*******************************************************************************
; Clears old shape based on cs_pointer which has old cursor position (void)

ClearShape          proc
                    pshd
                    pshx
                    pshy
                    ldd       cc_pointer
                    bsr       UpdateCursor        ; Set Cursor to start of shape
                    ldy       #4
                    lda       #MEM_WRITE
                    jsr       LCD_Command
                    clra
Loop@@              ldx       #78
_1@@                jsr       LCD_Data
                    dex
                    bne       _1@@
                    dey
                    beq       Done@@
          ;--------------------------------------
                    ldd       cc_pointer
                    xgdx
                    dex
                    xgdx
                    std       cc_pointer
                    bsr       UpdateCursor
                    bra       Loop@@
          ;--------------------------------------
Done@@              puly
                    pulx
                    puld
                    rts

;*******************************************************************************
; Requires D have cursor position (D)

UpdateCursor        proc
                    pshd
                    lda       #$46
                    jsr       LCD_Command
                    puld
                    jsr       LCD_Data
                    tba
                    jsr       LCD_Data
                    rts

;*******************************************************************************
; Draws single square within shape (void)

Square              proc
                    psha
                    pshx
                    ldd       c_pointer
                    bsr       UpdateCursor
                    ldx       #8
Loop@@             lda       #$FF
                    jsr       LCD_Data
                    dex
                    bne       Loop@@
                    clra
                    jsr:2     LCD_Data
                    pulx
                    pula
                    rts

;*******************************************************************************

LCD_INIT            proc
                    psha
                    pshx

                    lda       #$FF
                    sta       DDRG
                    sta       DDRH

                    lda       #$1F
                    sta       PORTG               ; Init PORTG

                    bclr      PORTG,BIT_0         ; RESET LOW
          ;-------------------------------------- ; Need 3ms Delay
                    ldx       #$FFFF
_1@@                dex
                    bne       _1@@

                    bset      PORTG,BIT_0         ; Reset Complete PORTG

                    ldx       #$FFFF
_2@@                dex
                    bne       _2@@

                    lda       #$58                ; Turn off Display
                    jsr       LCD_Command
          ;-------------------------------------- ; Init Setup
                    lda       #$40
                    bsr       LCD_Command
                    lda       #$30
                    jsr       LCD_Data
                    lda       #$87                ; 8-2 frame AC Drive 7 - Char Width FX
                    jsr       LCD_Data
                    lda       #$07                ; Char Height FY
                    jsr       LCD_Data
                    lda       #$1F                ; 32 Diplay bites per line
                    jsr       LCD_Data
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
                    bsr       LCD_Data            ; Lower byte
                    clra
                    bsr       LCD_Data            ; High byte
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
                    bsr       LCD_Data            ; to 0000h
                    clra
                    bsr       LCD_Data
          ;-------------------------------------- ; Clear Memeory
                    clrx
                    lda       #$42
                    bsr       LCD_Command

Loop@@              clra                          ; Zero
                    bsr       LCD_Data
                    inx
                    cpx       #$3000
                    bne       Loop@@
          ;-------------------------------------- ; Turn on Display
                    lda       #$59
                    bsr       LCD_Command         ; Display On
                    lda       #%01010100          ; Layer 1,2 on layer 3,4, curser off
                    bsr       LCD_Data
          ;-------------------------------------- ; Set CGRAM
;                   lda       #$5C
;                   jsr       LCD_Command
;                   clra
;                   jsr       LCD_Data
;                   lda       #$04
;                   jsr       LCD_Data
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
                    pshb
                    bset      PORTG,BIT_4         ; Set A0
                    sta       PORTH               ; Write Command
                    bset      PORTG,BIT_1         ; Read disabled
                    bclr      PORTG,BIT_3         ; CS enabled
                    bclr      PORTG,BIT_2         ; Write enabled
                    ldb       #$FF
                    stb       PORTG               ; Restore PG
                    pulb
                    rts

;*******************************************************************************

LCD_Data            proc
                    pshb
                    bclr      PORTG,BIT_4         ; Clear A0
                    sta       PORTH               ; Write Data
                    bset      PORTG,BIT_1         ; Read disabled
                    bclr      PORTG,BIT_3         ; CS enabled
                    bclr      PORTG,BIT_2         ; Write enabled
                    ldb       #$FF
                    stb       PORTG               ; Restore PG
                    pulb
                    rts
