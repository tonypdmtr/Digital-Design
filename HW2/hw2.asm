; ===========
; = Equates =
; ===========
; here are our external devices
LIGHTS1             equ       $B580
LIGHTS2             equ       $B590
SWITCHES            equ       $B5A0               ; Switch 0010 and 0100 both request State 1
;                                                       Switch 0001 requests State 2, and 1000 State 3

COPOPT              equ       $1039
COPRST              equ       $103A


; State 1 is free E-W traffic
STATE11             equ       $0C                 ; 00 001 100
STATE12             equ       $0C                 ; 00 001 100

; State 2 is free traffic from the South
STATE21             equ       $24                 ; 00 100 100
STATE22             equ       $21                 ; 00 100 001

; State 3 is turning lane green
STATE31             equ       $09                 ; 00 001 001
STATE32             equ       $24                 ; 00 100 100

; transition state from State 1 to State 2
TRANSTATE121        equ       $14                 ; 00 010 100
TRANSTATE122        equ       $14                 ; 00 010 100

; transition state from State 2 to State 1
TRANSTATE211        equ       $24                 ; 00 100 100
TRANSTATE212        equ       $22                 ; 00 100 010

; transition state from State 1 to State 3
TRANSTATE131        equ       $0C                 ; 00 001 100
TRANSTATE132        equ       $14                 ; 00 010 100

; transition state from State 3 to State 1
TRANSTATE311        equ       $0A                 ; 00 001 010
TRANSTATE312        equ       $24                 ; 00 100 100

; transition state from State 2 to State 3
TRANSTATE231        equ       $24                 ; 00 100 100
TRANSTATE232        equ       $22                 ; 00 100 010

; transition state from State 3 to State 2
TRANSTATE321        equ       $12                 ; 00 010 010
TRANSTATE322        equ       $24                 ; 00 100 100

;**************
; Main
;**************
                    org       $E000               ; $E000 w/o Buffalo, $2000 with.
Init                lds       #$01FF              ; init stack pointer
                    lda       COPOPT              ; Set COP to ~ 1s timeout
                    ora       #$03
                    sta       COPOPT
                    lda       #$55
                    sta       COPRST
                    lda       #$AA
                    sta       COPRST

Main               ;bra       gotoState1          ; start with state 1

gotoState1
                    lda       #STATE11            ; get state info from definitions
                    sta       LIGHTS1             ; and store into the light ext device
                    lda       #STATE12
                    sta       LIGHTS2
                    jsr       delay10             ; then delay for 10 seconds before changing
State1Loop
                    jsr       resetCOP            ; reset the COP
                    lda       SWITCHES            ; read Switches in
                    ldb       SWITCHES
                    andb      #$01                ; Switch A -> State 2
                    bne       trans12
                    tab
                    andb      #$08                ; Switch D -> State 3
                    bne       trans13
                    bra       State1Loop          ; else no switch, or go to current state, so

;                                                       ignore and keep checking

; sets transition state
trans12
                    lda       #TRANSTATE121       ; set lights to transition state
                    sta       LIGHTS1
                    lda       #TRANSTATE122
                    sta       LIGHTS2
                    jsr       delay2              ; wait for 2 seconds
                    bra       gotoState2

; analogous to trans12
trans13
                    lda       #TRANSTATE131
                    sta       LIGHTS1
                    lda       #TRANSTATE132
                    sta       LIGHTS2
                    jsr       delay2
                    bra       gotoState3

; See State 1 for comments, same thing is happening
gotoState2
                    lda       #STATE21
                    sta       LIGHTS1
                    lda       #STATE22
                    sta       LIGHTS2
                    jsr       delay10
State2Loop
                    bsr       resetCOP
                    lda       SWITCHES
                    ldb       SWITCHES
                    andb      #$08                ; Switch D -> State 3
                    bne       trans23
                    tab
                    andb      #$02                ; Switch B -> State 1
                    bne       trans21
                    tab
                    andb      #$04                ; Switch C -> State 1
                    bne       trans21
                    bra       State2Loop

; analogous to trans12
trans23
                    lda       #TRANSTATE231
                    sta       LIGHTS1
                    lda       #TRANSTATE232
                    sta       LIGHTS2
                    bsr       delay2
                    bra       gotoState3

; analogous to trans12
trans21
                    lda       #TRANSTATE211
                    sta       LIGHTS1
                    lda       #TRANSTATE212
                    sta       LIGHTS2
                    bsr       delay2
                    bra       gotoState1

; See State 1 for comments, same thing is happening
gotoState3
                    lda       #STATE31
                    sta       LIGHTS1
                    lda       #STATE32
                    sta       LIGHTS2
                    bsr       delay10
State3Loop
                    bsr       resetCOP
                    lda       SWITCHES
                    ldb       SWITCHES
                    andb      #$01                ; Switch A -> State 2
                    bne       trans32
                    tab
                    andb      #$02                ; Switch B -> State 1
                    bne       trans31
                    bra       State3Loop

; analogous to trans12
trans32
                    lda       #TRANSTATE321
                    sta       LIGHTS1
                    lda       #TRANSTATE322
                    sta       LIGHTS2
                    bsr       delay2
                    bra       gotoState2

; analogous to trans12
trans31
                    lda       #TRANSTATE311
                    sta       LIGHTS1
                    lda       #TRANSTATE312
                    sta       LIGHTS2
                    bsr       delay2
                    jmp       gotoState1

; subroutine to reset the COP timer. We're doing this periodically
resetCOP            psha
                    lda       #$55
                    sta       COPRST
                    lda       #$AA
                    sta       COPRST
                    pula
                    rts

; 2 second delay
delay2              psha
                    lda       #10                 ; 5*2
delay2_1            cmpa      #$00
                    beq       delay2_end
                    bsr       delay_small
                    deca
                    bra       delay2_1

delay2_end          pula
                    rts

; 10 second delay
delay10             psha
                    lda       #50                 ; 5*10
delay10_1           cmpa      #00
                    beq       delay10_end
                    bsr       delay_small
                    deca
                    bra       delay10_1

delay10_end         pula
                    rts


; a small delay of 0.19 seconds, used as a building block
; for the other delays
delay_small         pshx
                    ldx       #$79E7
delay_small_1       cpx       #$00
                    beq       delay_small_end
                    dex
                    bra       delay_small_1

delay_small_end     pulx
                    rts


; ISR to flash red lights on COP error
COPAlert
                    lda       #$00
                    sta       LIGHTS1
                    sta       LIGHTS2
                    bsr       delay2
                    lda       #$24
                    sta       LIGHTS1
                    sta       LIGHTS2
                    bsr       delay2
                    bra       COPAlert

; Vectors
                    org       $FFFA
                    fdb       COPAlert

                    org       $FFFE
                    fdb       Init
