; ;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Reset memory locations ;;
; ;;;;;;;;;;;;;;;;;;;;;;;;;;
START_ADDRESS       equ       $0000
END_ADDRESS         equ       $0100

                    org       $D000
Main
                    lds       #$01FF
                    bsr       Init_Memory
End                 bra       End



Init_Memory
                    ldx       #START_ADDRESS
                    lda       #00
Loop
                    sta       0,X
                    inx
                    cpx       #END_ADDRESS
                    bne       Loop
Init_Memory_End
                    rts

                    org       $FFFE
                    dw        Main
