;*******************************************************************************
; Christoph Koehler
; Project 4
; Counter with LCD display and LED indicators for high/low status
;*******************************************************************************

REGS                def       $1000
PORTA               equ       REGS+$00            ; port a, using bit 6 for OC2/square wave output
TOC1                equ       REGS+$16            ; timer output compare 1
TOC2                equ       REGS+$18            ; timer output compare 2
TMSK1               equ       REGS+$22            ; to enable OC1 interrupt
TFLG1               equ       REGS+$23            ; timer flag register
TCNT                equ       REGS+$0E            ; read only timer count
TCTL1               equ       REGS+$20            ; control for OC2 toggle - square wave

SCCR2               equ       REGS+$2D            ; SCI ports
BAUD                equ       REGS+$2B
SCSR                equ       REGS+$2E
SCDR                equ       REGS+$2F

ROM                 def       $D000
STACKTOP            def       $01FF

Vsci                equ       $FFD6
Vtoc2               equ       $FFE6
Vtoc1               equ       $FFE8
Vreset              equ       $FFFE

CR                  equ       13
LF                  equ       10

BUS_KHZ             def       2000

ONE_MSEC            equ       BUS_KHZ
HALF_MSEC           equ       BUS_KHZ/2
QUARTER_MSEC        equ       BUS_KHZ/4

;*******************************************************************************
                    #RAM
;*******************************************************************************

ms                  rmb       2                   ; this is 16-bit, 0-1000
sec                 rmb       1
min                 rmb       1
events              rmb       1
command             rmb       1                   ; receiving byte, i.e. command
tx_byte             rmb       1                   ; byte to transmit to the serial port
hex                 rmb       1                   ; hex dummy var for the converter
ascii_1             rmb       1                   ; 3 ASCII dummy vars for the converter. Each of the next 3 is one digit.
ascii_2             rmb       1                   ; They end up being ASCII, we add $30 to it to make ASCII 5 out of decimal 5
ascii_3             rmb       1

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       ROM

Start               proc
                    lds       #STACKTOP           ; set stack pointer
                    bsr       InitPorts
                    bsr       InitSCI             ; init ports and variables
                    bsr       InitTimers
Loop@@              bsr       ParseCommand        ; parse the incoming command from the SCI and process
                    bra       Loop@@              ; repeat

;*******************************************************************************

InitPorts           proc
                    clr       ms
                    clr       $0002
                    clr       sec
                    clr       min
                    clr       events
                    clr       command
                    clr       ascii_1
                    clr       ascii_2
                    clr       ascii_3
                    clr       hex
                    cli                           ; enable interrupts
                    rts

;*******************************************************************************

InitTimers          proc
          ;-------------------------------------- ; set TOC1 for 1 ms = 2000 cycles
                    ldd       #ONE_MSEC
                    std       TOC1
          ;-------------------------------------- ; set TOC2 for .5/2 ms = 500 cycles
                    ldd       #HALF_MSEC
                    std       TOC2
          ;-------------------------------------- ; enable OC1, but not OC2 yet
                    lda       #%10000000
                    sta       TMSK1
                    rts

;*******************************************************************************

InitSCI             proc
                    lda       #$2C
                    sta       SCCR2               ; turn on tx/rx and rx interrupts
                    clr       BAUD                ; choose 125k baud
                    rts

;*******************************************************************************

ParseCommand        proc
                    lda       command
                    beq       Done@@
                    cmpa      #'!'                ; compare for ! and register event if so
                    beq       RegisterEvent
                    cmpa      #'r'                ; compare for r and reset if so
                    beq       ResetAll
                    cmpa      #'?'                ; compare for ? and print query if so
                    beq       SendQuery
                    cmpa      #'a'                ; compare for a and generate square wave
                    beq       EnableAlarm
Done@@              clr       command
                    rts

;*******************************************************************************

CheckTxByte         proc
                    sta       tx_byte
Loop@@              lda       tx_byte
                    bne       Loop@@
                    rts

;*******************************************************************************
; simply register an event

RegisterEvent       proc
                    inc       events
                    clr       command
                    rts

;*******************************************************************************
; clear everything

ResetAll            proc
                    clr       ms
                    clr       $0002
                    clr       sec
                    clr       min
                    clr       events
                    clr       command
;                   bra       DisableAlarm

;*******************************************************************************
; turn off square wave

DisableAlarm        proc
                    lda       TMSK1
                    anda      #%10111111          ; clear OC2 bit to disable alarm
                    sta       TMSK1
          ;-------------------------------------- ; disable toggle of OC2 output line on each successful compare
                    clr       TCTL1
                    clr       command
          ;-------------------------------------- ; clear PORTA, so that if we disable the toggle on a high, it doesn't stay on high
                    clr       PORTA
                    rts

;*******************************************************************************
; enable square wave by setting appropriate registers

EnableAlarm         proc
                    lda       TMSK1
                    ora       #%01000000          ; enable OC2 bit
                    sta       TMSK1
          ;-------------------------------------- ; toggle OC2 output line on each successful compare
                    lda       #$C0
                    sta       TCTL1
                    clr       command
                    rts

;*******************************************************************************
; looong method, sending out the query

SendQuery           proc
          ;-------------------------------------- ; turn on tx interrupt
                    lda       #$AC
                    sta       SCCR2               ; turn on tx/rx and tx/rx interrupts
          ;--------------------------------------
          ; we repeat the following construction a few times.
          ; all it does is take an input, min in this case, and converts
          ; it to ASCII, saving each digit into ascii_1 and ascii_2.
          ;--------------------------------------
                    lda       min
                    sta       hex
                    bsr       Hex2ASCII
                    lda       ascii_1
                    bsr       CheckTxByte

                    lda       ascii_2
                    bsr       CheckTxByte
          ;-------------------------------------- ; special construction ends here
                    lda       #':'
                    bsr       CheckTxByte
          ;-------------------------------------- ; see above for note, construction starts here
                    lda       sec
                    sta       hex
                    bsr       Hex2ASCII
                    lda       ascii_1
                    bsr       CheckTxByte

                    lda       ascii_2
                    bsr       CheckTxByte
          ;-------------------------------------- ; special construction ends here
                    lda       #':'
                    bsr       CheckTxByte
          ;--------------------------------------
          ; see above for note. This one is 16 bit and so includes
          ; an additional digit, ascii_3
          ;--------------------------------------
                    lda       ms
                    sta       hex
                    bsr       Hex2ASCII16
                    lda       ascii_1
                    bsr       CheckTxByte

                    lda       ascii_2
                    bsr       CheckTxByte

                    lda       ascii_3
                    bsr       CheckTxByte
          ;-------------------------------------- ; special construction ends here
                    lda       #','
                    jsr       CheckTxByte

                    lda       #' '
                    jsr       CheckTxByte
          ;-------------------------------------- ; see note above. construction starts here.
                    lda       events
                    sta       hex
                    bsr       Hex2ASCII
                    lda       ascii_1
                    jsr       CheckTxByte

                    lda       ascii_2
                    jsr       CheckTxByte
          ;-------------------------------------- ; special construction ends here
                    ldx       #MsgEvent@@
Loop@@              lda       ,x
                    beq       Done@@
                    jsr       CheckTxByte
                    inx
                    bra       Loop@@
          ;-------------------------------------- ; turn tx interrupt back off
Done@@              lda       #$2C
                    sta       SCCR2               ; turn on tx/rx and tx/rx interrupts
                    clr       command
                    rts

MsgEvent@@          fcs       ' Events',CR,LF

;*******************************************************************************
; convert hex to ASCII, by digit. 8 bit, 2 digits only in our case

Hex2ASCII           proc
                    ldx       #10
                    clra
                    ldb       hex
                    idiv                          ; divide hex by 10 (0A)
                    addb      #'0'
                    stb       ascii_2
                    xgdx                          ; swap x and d because we can't move x directly to decimal
                    addb      #'0'
                    stb       ascii_1
                    rts

;*******************************************************************************
; same as above, but with the 16 bit millisecond counter. Adds a 3rd digit, otherwise
; very similar to the above.

Hex2ASCII16         proc
                    ldx       #10
                    clra
                    ldd       ms
                    idiv                          ; divide hex by 10 (0A)
                    addd      #'0'
                    stb       ascii_3
                    xgdx                          ; swap x and d because we can't move x directly to decimal
                    ldx       #10
                    idiv
                    addd      #'0'
                    stb       ascii_2
                    xgdx
;                   addb      decimal             ; combine the bytes
                    addd      #'0'
                    stb       ascii_1
                    rts

;*******************************************************************************
; Counts the milliseconds

Counter_Handler     proc
          ;-------------------------------------- ; increment the millisecond counter
                    ldd       ms
                    incd
                    std       ms
          ;-------------------------------------- ; set next interrupt N cycles later
                    ldd       TOC1
                    addd      #ONE_MSEC
                    std       TOC1
          ;-------------------------------------- ; clear TFLG1 by writing 1 to it
                    lda       #$FF
                    sta       TFLG1
          ;-------------------------------------- ; now, see if we're past 1000 ms
                    ldd       ms
                    cpd       #1000
                    blo       _1@@
          ;--------------------------------------
                    inc       sec
                    clrd
                    std       ms
                    bra       Done@@
          ;-------------------------------------- ; now see if we're passed 60 seconds
_1@@                lda       sec
                    cmpa      #60
                    blo       Done@@
          ;--------------------------------------
                    inc       min
                    clr       sec
Done@@              rti

;*******************************************************************************

SquareWave          proc
          ;-------------------------------------- ; every N cycles we toggle the line. Set next alarm here.
                    ldd       TOC2
                    addd      #QUARTER_MSEC
                    std       TOC2
          ;-------------------------------------- ; clear TFLG1 by writing 1 to it
                    lda       #$FF
                    sta       TFLG1
                    rti

;*******************************************************************************

SCI_Handler         proc
                    lda       SCSR                ; get status
                    anda      #$20                ; is a character waiting?
                    cmpa      #$20                ; compare to $20.
                    beq       Rx@@                ; If equal, receive, if not, transmit
          ;-------------------------------------- ; now send if needed
                    lda       tx_byte
                    sta       SCDR
                    clr       tx_byte
;                   jsr       SendStatus
                    rti

Rx@@                lda       SCDR
                    sta       command
                    rti

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       Vsci
                    dw        SCI_Handler

                    org       Vtoc2
                    dw        SquareWave

                    org       Vtoc1
                    dw        Counter_Handler

                    org       Vreset
                    dw        Start
