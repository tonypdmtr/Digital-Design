;*******************************************************************************
; Hello World for the CRT
;*******************************************************************************

tx_byte             equ       $0000
SCCR2               equ       $102D
BAUD                equ       $102B
SCSR                equ       $102E
SCDR                equ       $102F

Vsci                equ       $FFD6
Vreset              equ       $FFFE

ROM                 equ       $D000
STACKTOP            equ       $01FF

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       ROM

Start               proc
                    lds       #STACKTOP
                    cli
                    bsr       InitSCI
          ;--------------------------------------
                    ldx       #Msg@@
Loop@@              lda       ,x
                    beq       Done@@
                    bsr       CheckTxByte
                    inx
                    bra       Loop@@
Done@@              bra       *

Msg@@               fcs       'Hello!'

;*******************************************************************************

SCI_Handler         proc
                    lda       SCSR
                    lda       tx_byte
                    sta       SCDR
                    clr       tx_byte
                    rti

;*******************************************************************************

CheckTxByte         proc
                    sta       tx_byte
Loop@@              lda       tx_byte
                    bne       Loop@@
                    rts

;*******************************************************************************

InitSCI             proc
                    lda       #$88
                    sta       SCCR2               ; turn on tx and tx interrupts
                    clr       BAUD                ; choose 125k baud
                    rts

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       Vsci
                    dw        SCI_Handler

                    org       Vreset
                    dw        Start
