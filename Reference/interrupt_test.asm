; ;;;;;;;;;;
; interrupt test
; ;;;;;;

; variables and equates
PORTC               equ       $1003
DDRC                equ       $1007
TMSK2               equ       $1024
TCNT                equ       $100E
TFLG2               equ       $1025

                    org       $D000
; main
Init
                    lds       #$01FF
                    bsr       init_ports
                    bsr       init_interrupts
Main
                    bra       Main


; subroutines
init_ports
; set 3rd bit in data direction register for port c to output
                    lda       #$08
                    sta       DDRC
; reset bit 3 to 0 => LED off
                    lda       #$00
                    sta       PORTC
                    rts

init_interrupts
                    lda       #$80                ; enable timer overflow interrupt
                    sta       TMSK2
                    cli                           ; clear the global interrupt mask
                    rts

; Interrupt Service Routines
ISR_TimerOverflow
                    lda       PORTC
                    eora      #$08
                    sta       PORTC
                    lda       #$80
                    sta       TFLG2
                    rti


; interrupt vectors
                    org       $FFDE
                    dw        ISR_TimerOverflow


                    org       $FFFE
                    dw        Init
