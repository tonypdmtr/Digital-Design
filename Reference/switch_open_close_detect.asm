; switch close to open detector

; vars and equ
DDRC                equ       $1007
PORTC               equ       $1003
LastTime            equ       $0000
switched            equ       $0001               ; set to 1 if switch triggered, 0 otherwise

                    org       $D000

Init
                    lds       #$01FF
                    clr       LastTime
                    bsr       init_ports
Loop
                    bsr       switch_check
                    bra       Loop

; subs
init_ports
                    lda       #$00
                    sta       DDRC

                    rts

switch_check
                    lda       PORTC
                    anda      #$08
                    psha
                    beq       switch_check_end
                    lda       LastTime
                    anda      #$08
                    bne       switch_check_end
                    lda       #$01
                    sta       switched
switch_check_end
                    pula
                    sta       LastTime
                    rts

                    org       $FFFE
                    dw        Init
