; switch close to open detector

DDRC                equ       $1007
PORTC               equ       $1003

Vreset              equ       $FFFE

;*******************************************************************************
                    #RAM
;*******************************************************************************

last_time           rmb       1
switched            rmb       1                   ; set to 1 if switch triggered, 0 otherwise

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $D000

Start               proc
                    lds       #$01FF
                    clr       last_time
                    bsr       InitPorts
Loop@@              bsr       SwitchCheck
                    bra       Loop@@

;*******************************************************************************

InitPorts           proc
                    clr       DDRC
                    rts

;*******************************************************************************

SwitchCheck         proc
                    lda       PORTC
                    anda      #$08
                    psha
                    beq       Done@@
                    lda       last_time
                    anda      #$08
                    bne       Done@@
                    lda       #1
                    sta       switched
Done@@              pula
                    sta       last_time
                    rts

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       Vreset
                    dw        Start
