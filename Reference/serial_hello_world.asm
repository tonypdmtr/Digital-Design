; Hello World for the CRT

; equ
tx_byte             equ       $0000
SCCR2               equ       $102D
BAUD                equ       $102B
SCSR                equ       $102E
SCDR                equ       $102F

; main
                    org       $D000
init
                    lds       #$01FF
                    cli
                    bsr       init_sci
main
                    lda       #'H'
                    sta       tx_byte
                    bsr       check_tx_byte
                    lda       #'e'
                    sta       tx_byte
                    bsr       check_tx_byte
                    lda       #'l'
                    sta       tx_byte
                    bsr       check_tx_byte
                    lda       #'l'
                    sta       tx_byte
                    bsr       check_tx_byte
                    lda       #'o'
                    sta       tx_byte
                    bsr       check_tx_byte
                    lda       #'!'
                    sta       tx_byte
                    bsr       check_tx_byte
endloop             bra       endloop

; isr's
isr_sci
                    lda       SCSR
                    lda       tx_byte
                    sta       SCDR
                    clr       tx_byte
                    rti

; subs
check_tx_byte
                    lda       tx_byte
                    bne       check_tx_byte
                    rts

init_sci
                    lda       #$88
                    sta       SCCR2               ; turn on tx and tx interrupts
                    clr       BAUD                ; choose 125k baud
                    rts

                    org       $FFD6
                    dw        isr_sci

                    org       $FFFE
                    dw        init
