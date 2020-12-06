;*******************************************************************************
; Interrupt test
;*******************************************************************************

PORTC               equ       $1003
DDRC                equ       $1007
TMSK2               equ       $1024
TCNT                equ       $100E
TFLG2               equ       $1025

ROM                 equ       $D000
STACKTOP            equ       $01FF

Vtovf               equ       $FFDE
Vreset              equ       $FFFE

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       ROM

Start               proc
                    lds       #STACKTOP
                    bsr       InitPorts
                    bsr       InitInterrupts
                    bra       *

;*******************************************************************************

InitPorts           proc
          ;-------------------------------------- ; set 3rd bit in data direction register for port c to output
                    lda       #$08
                    sta       DDRC
          ;-------------------------------------- ; reset bit 3 to 0 => LED off
                    clr       PORTC
                    rts

;*******************************************************************************

InitInterrupts      proc
                    lda       #$80                ; enable timer overflow interrupt
                    sta       TMSK2
                    cli                           ; clear the global interrupt mask
                    rts

;*******************************************************************************
; Interrupt Service Routines

TOV_Handler         proc
                    lda       PORTC
                    eora      #$08
                    sta       PORTC
                    lda       #$80
                    sta       TFLG2
                    rti

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       Vtovf
                    dw        TOV_Handler

                    org       Vreset
                    dw        Start
