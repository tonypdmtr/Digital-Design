PORTG               equ       $0828               ; Expanded Address of Command
DDRG                equ       $082A
PORTH               equ       $0829               ; Expanded Address of Data
DDRH                equ       $082B

BIT_0               equ       1                   ; /RESET
BIT_1               equ       2                   ; /READ
BIT_2               equ       4                   ; /WRITE
BIT_3               equ       8                   ; /CS
BIT_4               equ       16                  ; A0


CPointer            rmb       2
CSPointer           rmb       2
CCPointer           rmb       2
stage_block_ptr     rmb       2
block_ptr           rmb       2

SomeValue           def       0
CursorInit          equ       $0000


Mwrite              equ       $42

                    org       $1000

                    jsr       LCD_INIT
                    swi

; Init Cursor Pointers to starting position (void)
InitCurPointers     pshd
                    ldd       CursorInit
                    std       CPointer
                    std       CSPointer
                    puld
                    rts

; Draws Shape based on values in memory (void)
DrawShape           pshd
                    pshx
                    pshy
                    bsr       ClearShape
                    ldd       CursorInit
                    addd      stage_block_ptr
                    std       CCPointer
                    std       CPointer

                    ldx       block_ptr           ;*************************************CheckLocation

                    lda       #Mwrite             ; init memory write
                    jsr       LCD_Command

DrawShape1          lda       1,x
                    dex
                    ldd       CPointer
                    xgdx
                    dex
                    xgdx
                    bsr       UpdateCursor
                    ldy       #8
DrawShape2          lsla
                    bcs       Square
                    dey
                    bne       DrawShape2

                    cmpx      #SomeValue          ;************************************Check
                    bne       DrawShape1
                    puly
                    pulx
                    puld
                    rts

; Clears old shape based on CSPointer which has old cursor position (void)
ClearShape          pshd
                    pshx
                    pshy
                    ldd       CCPointer
                    bsr       UpdateCursor        ; Set Cursor to start of shape
                    ldy       #4
                    lda       #Mwrite
                    jsr       LCD_Command
                    lda       #$00
ClearShape1         ldx       #78
ClearShape2         jsr       LCD_Data
                    dex
                    bne       ClearShape2
                    dey
                    bne       ClearShape3
                    bra       ClearShape_RTS

ClearShape3         ldd       CCPointer
                    xgdx
                    dex
                    xgdx
                    std       CCPointer
                    bsr       UpdateCursor
                    bra       ClearShape1

ClearShape_RTS      puly
                    pulx
                    puld
                    rts

; Requires D have cursor position (D)
UpdateCursor        pshd
                    lda       #$46
                    jsr       LCD_Command
                    puld
                    jsr       LCD_Data
                    tba
                    jsr       LCD_Data
                    rts

; Draws single square within shape (void)
Square              psha
                    pshx
                    ldd       CPointer
                    bsr       UpdateCursor


                    ldx       #8
Square1             lda       #$FF
                    jsr       LCD_Data
                    dex
                    bne       Square1
                    lda       #$00
                    jsr       LCD_Data
                    jsr       LCD_Data
                    pulx
                    pula
                    rts

LCD_INIT
                    psha
                    pshx

                    lda       #$FF
                    sta       DDRG
                    sta       DDRH
; sta 

                    lda       #$1F
                    sta       PORTG               ; Init PORTG

                    bclr      PORTG,BIT_0         ; RESET LOW

;***************** Need 3ms Delay
                    ldx       #$FFFF
LCD_INIT_LOOP1      dex
                    bne       LCD_INIT_LOOP1

                    bset      PORTG,BIT_0         ; Reset Complete PORTG

                    ldx       #$FFFF
LCD_INIT_LOOP2      dex
                    bne       LCD_INIT_LOOP2

                    lda       #$58                ; Turn off Display
                    jsr       LCD_Command

; *Init Setup
                    lda       #$40
                    jsr       LCD_Command
                    lda       #$30
                    jsr       LCD_Data
                    lda       #$87                ; 8-2 frame AC Drive 7 - Char Width FX
                    jsr       LCD_Data
                    lda       #$07                ; Char Height FY
                    jsr       LCD_Data
                    lda       #$1F                ; 32 Diplay bites per line
                    jsr       LCD_Data
                    lda       #$23                ; Total addr range per line TC/R (C/R+4 H-Blanking)
                    jsr       LCD_Data
                    lda       #$7F                ; 128 diplay lines L/F
                    jsr       LCD_Data
                    lda       #$20                ; Low Bite APL (Virtual Screen)
                    bsr       LCD_Data
                    lda       #$00                ; High Bite APL (Virtual Screen)
                    bsr       LCD_Data

; *Scorll Settings
                    lda       #$44                ; Set Scroll Command
                    bsr       LCD_Command
                    lda       #$00                ; Layer 1 Start Address
                    bsr       LCD_Data            ; Lower byte
                    lda       #$00
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    lda       #$00                ; Layer 2 Start Address
                    bsr       LCD_Data            ; Lower byte
                    lda       #$10
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    lda       #$00
                    bsr       LCD_Data            ; Layer 3 Start Address
                    lda       #$20
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines

; *Horizonal Scroll Set
                    lda       #$5A                ; Horizonal Scroll CMD
                    bsr       LCD_Command
                    lda       #$00                ; At Origin on X
                    bsr       LCD_Data
; *Overlay Settings
                    lda       #$5B
                    bsr       LCD_Command         ; Overlay CMD
                    lda       #$1C
                    bsr       LCD_Data            ; 3 layers, Graphics,OR layers

                    lda       #$4F                ; Curser auto inc AP+1
                    bsr       LCD_Command

; *Set Cursor location
                    lda       #$46
                    bsr       LCD_Command         ; Set Cursor
                    clra
                    bsr       LCD_Data            ; to 0000h
                    clra
                    bsr       LCD_Data


; *Clear Memeory
                    ldx       #$0000
                    lda       #$42
                    bsr       LCD_Command

INIT_L2_RAM         lda       #$00                ; Zero
                    bsr       LCD_Data
                    inx
                    cpx       #$3000
                    bne       INIT_L2_RAM

; *Turn on Display
                    lda       #$59
                    bsr       LCD_Command         ; Display On
                    lda       #%01010100          ; Layer 1,2 on layer 3,4, curser off
                    bsr       LCD_Data
; *Set CGRAM
; lda     #$5C
; jsr     LCD_Command
; lda     #$00
; jsr     LCD_Data
; lda     #$04
; jsr     LCD_Data

                    pulx
                    pula
                    rts

; PORTG
; bit0 - /Reset
; bit1 - /Read
; bit2 - /Write
; bit3 - /CS
; bit4 - A0

LCD_Command
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

LCD_Data
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
