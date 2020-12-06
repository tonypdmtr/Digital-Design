; =============
; = Variables =
; =============
ADCTL               equ       $1030
ADR2                equ       $1032
OPTION              equ       $1039
SCCR2               equ       $102D
SCSR                equ       $102E
SCDR                equ       $102F
BAUD                equ       $102B
R_H                 equ       $5

Dig5                equ       $0000
Dot                 equ       $0001
Dig4                equ       $0002
Dig3                equ       $0003
Dig2                equ       $0004
Dig1                equ       $0005
Space               equ       $0006
Unit                equ       $0007
CR                  equ       $0008
LF                  equ       $0009
Finish              equ       $000A

ADResult            equ       $000B
; reference Resistor / 4 = 250 ohms
Rref                equ       $FA
; ========
; = Main =
; ========
                    org       $B600               ; $E000 w/o Buffalo, $2000 with.

Init                lds       #$01FF              ; initiate stack pointer
                    bsr       SCI_INIT
                    lda       OPTION              ; enable A/D subsystem
                    ora       #$80
                    sta       OPTION
                    lda       #$2E                ; set some ascii constants
                    sta       Dot
                    lda       #$00
                    sta       Finish
                    lda       #$0A
                    sta       LF
                    lda       #$0D
                    sta       CR
                    lda       #$20
                    sta       Space

Main               ;bra       Mode1               ; go to voltmeter by default

Mode1
                    ldx       #Voltage
                    bsr       Output
                    lda       #$56                ; get V for unit
                    sta       Unit
Mode11
                    bsr       Read_AD             ; get value from A/D
                    jsr       Fill_Digits         ; do the math and save digits
                    ldx       #Dig5               ; load address to first digit into x
                    bsr       Output              ; output that sequence
                    bsr       Check_Input         ; check for mode change
                    cmpa      #$6F                ; check for lowercase o
                    beq       Mode2               ; if we have an o, move to mode 2
                    bra       Mode11              ; else stay in mode1

Mode2
                    ldx       #Resistance
                    bsr       Output
                    lda       #$4F                ; get V for unit
                    sta       Unit
Mode22
                    bsr       Read_AD             ; get value from A/D
;        jsr     Calc_Res       * calculate resistance
                    bsr       Check_Input         ; check for mode change
                    cmpa      #$76                ; check for v and switch mode if found
                    beq       Mode1
                    bra       Mode22

; ========
; = Subs =
; ========

; *Init SCI
SCI_INIT
                    psha
                    lda       #$0C                ; enable Tx and Rx
                    sta       SCCR2
                    lda       #$30                ; set BAUD to 9600
                    sta       BAUD
                    pula
                    rts

; returns either 0 or character in {A}
Check_Input
                    lda       SCSR                ; check to see if there is data incoming from the SCI
                    anda      #$20
                    beq       Check_Input_End     ; if not, end here
                    lda       SCDR                ; otherwise read the data into A
Check_Input_End     rts

; work on the byte that X points to that we get
Output
                    psha
Output1             lda       0,x                 ; get first character of what X points to
                    inx                           ; increment x to get the next address to read from
                    cmpa      #$00                ; did we encounter a 0 char?
                    beq       OutputEnd           ; if so, end
                    bsr       Output_Char         ; otherwise, print the character, from regA
                    bra       Output1             ; and start all over

OutputEnd           pula
                    rts

; expects data to send out in A
Output_Char
                    pshb
Output_Char1        ldb       SCSR                ; check to see if the transmit register is empty
                    andb      #$80
                    cmpb      #$80
                    bne       Output_Char1        ; if not, keep looping until it is
                    sta       SCDR                ; finally, write the character to the SCI
                    pulb
                    rts

; read from A/D converter and store in ADResult
Read_AD             psha
                    lda       #$01                ; prime A/D
                    sta       ADCTL
Read_AD1            lda       ADCTL               ; read status bit
                    anda      #$80
                    beq       Read_AD1            ; keep checking
                    lda       ADR2                ; we should have a result now
                    sta       ADResult
                    pula
                    rts

Voltage             fcb       $D
                    fcc       "Voltage:    "
                    fcb       0

Resistance          fcb       $D
                    fcc       "Resistance: "
                    fcb       0

; do the conversion.
; note that we never need to divide by 256, since it's just a shift right
; several times. We get the values out our own way.
Fill_Digits
                    psha
                    pshb
; multiply the result with our ref voltage
                    ldb       ADResult
                    lda       #R_H
                    mul
; we end up with the most sig in A. Convert to ASCII
                    adda      #$30
                    sta       Dig5                ; save that digit

; multiply the remainder by 10 and convert to ASCII. That's the next digit.
; continue that until we get the desired precision
                    lda       #10
                    mul
                    adda      #$30
                    sta       Dig4
                    lda       #10
                    mul
                    adda      #$30
                    sta       Dig3
                    lda       #10
                    mul
                    adda      #$30
                    sta       Dig2
                    lda       #10
                    mul
                    adda      #$30
                    sta       Dig1
                    pula
                    pulb
                    rts

Calc_Res            psha
                    pshb
                    clrb
                    ldb       ADResult
                    negb
; we now have (256 - ADResult) in D. Switch to X to prepare for division
                    xgdx
                    lda       ADResult
                    ldb       #Rref
                    mul
                    idiv
                    xgdx
                    lsld
                    lsld
; now D contains the measured resistor value in HEX
                    ldx       #$64
                    idiv
                    xgdx
                    ldx       #$A
                    idiv
                    xgdx
                    pula
                    pulb
                    rts


; ===========
; = Vectors =
; ===========
                    org       $FFFE
                    fdb       Init
