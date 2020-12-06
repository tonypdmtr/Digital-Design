; Christoph Koehler
; Project 4

; Counter with LCD display and LED indicators for high/low status
; p 137 toggle
; vars and equ
PORTA               equ       $1000               ; port a, using bit 6 for OC2/square wave output
TOC1                equ       $1016               ; timer output compare 1
TOC2                equ       $1018               ; timer output compare 2
TMSK1               equ       $1022               ; to enable OC1 interrupt
TFLG1               equ       $1023               ; timer flag register
TCNT                equ       $100E               ; read only timer count
TCTL1               equ       $1020               ; control for OC2 toggle - square wave

SCCR2               equ       $102D               ; SCI ports
BAUD                equ       $102B
SCSR                equ       $102E
SCDR                equ       $102F

ms                  equ       $0001               ; this is 16-bit, 0-1000
sec                 equ       $0003
min                 equ       $0004
events              equ       $0005
breaktime_1         equ       $0006               ; this one is 16 bit!
breaktime_2         equ       $0008               ; this one, too! They hold the last TOC time
command             equ       $000A               ; receiving byte, i.e. command
tx_byte             equ       $000B               ; byte to transmit to the serial port

hex                 equ       $000C               ; hex dummy var for the converter
ascii_1             equ       $000D               ; 3 ascii dummy vars for the converter. Each of the next 3 is one digit.
ascii_2             equ       $000E               ; They end up being ascii, we add $30 to it to make ASCII 5 out of decimal 5
ascii_3             equ       $000F

                    org       $D000
Init
                    lds       #$01FF              ; set stack pointer
                    bsr       init_ports
                    bsr       init_sci            ; init ports and variables
                    bsr       init_timers
Loop
                    bsr       parse_command       ; parse the incoming command from the SCI and process
                    bra       Loop                ; repeat

; subs
init_ports
; clear a bunch of vars
                    clr       ms
                    clr       $0002
                    clr       sec
                    clr       min
                    clr       events
                    clr       breaktime_1
                    clr       command
                    clr       ascii_1
                    clr       ascii_2
                    clr       ascii_3
                    clr       hex

; enable interrupts
                    cli

                    rts

init_timers
; set TOC1 for 1 ms = 2000 cycles
                    ldd       #$07D0
                    std       TOC1
                    std       breaktime_1

; set TOC2 for .5/2 ms = 500 cycles
                    ldd       #$03E8
                    std       breaktime_2
                    std       TOC2

; enable OC1, but not OC2 yet
                    lda       #%10000000
                    sta       TMSK1
                    rts

init_sci
                    lda       #$2C
                    sta       SCCR2               ; turn on tx/rx and rx interrupts
                    clr       BAUD                ; choose 125k baud
                    rts

parse_command
                    lda       command
                    beq       parse_end
                    cmpa      #'!'                ; compare for ! and register event if so
                    beq       register_event
                    cmpa      #'r'                ; compare for r and reset if so
                    beq       reset_all
                    cmpa      #'?'                ; compare for ? and print query if so
                    beq       send_query
                    cmpa      #'a'                ; compare for a and generate square wave
                    beq       enable_alarm
parse_end
                    clr       command
                    rts

check_tx_byte
                    lda       tx_byte
                    bne       check_tx_byte
                    rts

; simply register an event
register_event
                    inc       events
                    clr       command
                    rts

; clear everything
reset_all
                    clr       ms
                    clr       $0002
                    clr       sec
                    clr       min
                    clr       events
                    clr       command
                    bsr       disable_alarm
                    rts

; enable square wave by setting appropriate registers
enable_alarm
                    lda       TMSK1
; enable OC2 bit
                    ora       #%01000000
                    sta       TMSK1
; toggle OC2 output line on each successful compare
                    lda       #$C0
                    sta       TCTL1
                    clr       command
                    rts

; turn off square wave
disable_alarm
                    lda       TMSK1
; clear OC2 bit to disable alarm
                    anda      #%10111111
                    sta       TMSK1
; disable toggle of OC2 output line on each successful compare
                    clr       TCTL1
                    clr       command
; clear PORTA, so that if we disable the toggle on a high, it doesn't stay on high
                    clr       PORTA
                    rts

; looong method, sending out the query
send_query
; turn on tx interrupt
                    lda       #$AC
                    sta       SCCR2               ; turn on tx/rx and tx/rx interrupts

; we repeat the following construction a few times.
; all it does is take an input, min in this case, and converts
; it to ASCII, saving each digit into ascii_1 and ascii_2.
                    lda       min
                    sta       hex
                    jsr       Hex2ASCII
                    lda       ascii_1
                    sta       tx_byte
                    bsr       check_tx_byte

                    lda       ascii_2
                    sta       tx_byte
                    bsr       check_tx_byte
; special construction ends here

                    lda       #':'
                    sta       tx_byte
                    bsr       check_tx_byte

; see above for note, construction starts here
                    lda       sec
                    sta       hex
                    jsr       Hex2ASCII
                    lda       ascii_1
                    sta       tx_byte
                    bsr       check_tx_byte

                    lda       ascii_2
                    sta       tx_byte
                    bsr       check_tx_byte
; special construction ends here

                    lda       #':'
                    sta       tx_byte
                    bsr       check_tx_byte

; see above for note. This one is 16 bit and so includes an additional
; digit, ascii_3
                    lda       ms
                    sta       hex
                    jsr       Hex2ASCII16
                    lda       ascii_1
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       ascii_2
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       ascii_3
                    sta       tx_byte
                    jsr       check_tx_byte
; special construction ends here

                    lda       #','
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #' '
                    sta       tx_byte
                    jsr       check_tx_byte

; see note above. construction starts here.
                    lda       events
                    sta       hex
                    bsr       Hex2ASCII
                    lda       ascii_1
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       ascii_2
                    sta       tx_byte
                    jsr       check_tx_byte
; special construction ends here

                    lda       #' '
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'E'
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'v'
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'e'
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'n'
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'t'
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #'s'
                    sta       tx_byte
                    jsr       check_tx_byte

; now send newline an carriage return
                    lda       #$0A
                    sta       tx_byte
                    jsr       check_tx_byte

                    lda       #$0D
                    sta       tx_byte
                    jsr       check_tx_byte

; turn tx interrupt back off
                    lda       #$2C
                    sta       SCCR2               ; turn on tx/rx and tx/rx interrupts
                    clr       command
                    rts

; convert hex to ascii, by digit. 8 bit, 2 digits only in our case
Hex2ASCII
                    ldx       #$000A
                    clra
                    ldb       hex
                    idiv                          ; divide hex by 10 (0A)
                    addb      #$30
                    stb       ascii_2
                    xgdx                          ; swap x and d because we can't move x directly to decimal
                    addb      #$30
                    stb       ascii_1
                    rts

; same as above, but with the 16 bit milisecond counter. Adds a 3rd digit, otherwise
; very similar to the above.
Hex2ASCII16
                    ldx       #$000A
                    clra
                    ldd       ms
                    idiv                          ; divide hex by 10 (0A)
                    addd      #$30
                    stb       ascii_3
                    xgdx                          ; swap x and d because we can't move x directly to decimal
                    ldx       #$000A
                    idiv
                    addd      #$30
                    stb       ascii_2
                    xgdx
; addb   decimal ; combine the bytes
                    addd      #$30
                    stb       ascii_1
                    rts

; ISRs
roll_over_ms2sec
                    inc       sec
                    ldd       #$0000
                    std       ms
                    rti

roll_over_sec2min
                    inc       min
                    lda       #$00
                    sta       sec
                    rti

; counts the miliseconds
counter1_isr

; increment the milisecond counter
                    ldd       ms
                    addd      #$0001
                    std       ms

; set next interrupt 2000 cycles later
                    ldd       breaktime_1
                    addd      #$07D0
                    std       TOC1
                    std       breaktime_1

; clear TFLG1 by writing 1 to it
                    lda       #$FF
                    sta       TFLG1

; now, see if we're past 1000 ms
                    ldd       ms
                    cpd       #1000
                    bhs       roll_over_ms2sec

; now see if we're passed 60 seconds
                    lda       sec
                    cmpa      #60
                    bhs       roll_over_sec2min
                    rti

square_wave
; every 500 cycles we toggle the line. Set next alarm here.
                    ldd       breaktime_2
                    addd      #500
                    std       breaktime_2
                    std       TOC2

; clear TFLG1 by writing 1 to it
                    lda       #$FF
                    sta       TFLG1
                    rti

SCI_isr
                    lda       SCSR
; AND status with 0010 0000 to get whether there is a character to read
                    anda      #$20
; compare to $20. If equal, receive, if not, transmit
                    cmpa      #$20
                    beq       receive_byte

; now send if needed
                    lda       tx_byte
                    sta       SCDR
                    clr       tx_byte
; jsr send_status
                    rti

receive_byte
                    lda       SCDR
                    sta       command

                    rti

                    org       $FFD6
                    dw        SCI_isr

                    org       $FFE6
                    dw        square_wave

                    org       $FFE8
                    dw        counter1_isr

                    org       $FFFE
                    dw        Init
