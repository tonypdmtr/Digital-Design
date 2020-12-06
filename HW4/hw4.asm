                    #CaseOn

REGS                def       $1000
ADCTL               equ       REGS+$30
ADR2                equ       REGS+$32
OPTION              equ       REGS+$39
SCCR2               equ       REGS+$2D
SCSR                equ       REGS+$2E
SCDR                equ       REGS+$2F
BAUD                equ       REGS+$2B

R_REF               equ       $FA                 ; reference Resistor / 4 = 250 ohms
R_H                 equ       5
CR                  equ       13
LF                  equ       10

;*******************************************************************************
                    #RAM
;*******************************************************************************

dig5                rmb       1
dot                 rmb       1
dig4                rmb       1
dig3                rmb       1
dig2                rmb       1
dig1                rmb       1
space               rmb       1
unit                rmb       1
cr                  rmb       1
lf                  rmb       1
finish              rmb       1
adresult            rmb       1

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $B600               ; $E000 w/o Buffalo, $2000 with.

Start               proc
                    lds       #$01FF              ; initiate stack pointer
                    bsr       SCI_INIT
                    lda       OPTION              ; enable A/D subsystem
                    ora       #$80
                    sta       OPTION
                    lda       #'.'                ; set some ASCII constants
                    sta       dot
                    clr       finish
                    lda       #LF
                    sta       lf
                    lda       #CR
                    sta       cr
                    lda       #' '
                    sta       space
;                   bra       Mode1               ; go to voltmeter by default

;*******************************************************************************

Mode1               proc
Loop@@              ldx       #MsgVoltage@@
                    bsr       Output
                    lda       #'V'                ; get V for unit
                    sta       unit
_1@@                bsr       Read_AD             ; get value from A/D
                    jsr       FillDigits          ; do the math and save digits
                    ldx       #dig5               ; load address to first digit into x
                    bsr       Output              ; output that sequence
                    bsr       Check_Input         ; check for mode change
                    cmpa      #'o'                ; check for lowercase o
                    bne       _1@@                ; if we have an o, move to mode 2 else stay in mode1
                    ldx       #MsgResistance@@
                    bsr       Output
                    lda       #'O'                ; get V for unit
                    sta       unit
_2@@                bsr       Read_AD             ; get value from A/D
;                   jsr       Calc_Res            ; calculate resistance
                    bsr       Check_Input         ; check for mode change
                    cmpa      #'v'                ; check for v and switch mode if found
                    beq       Loop@@
                    bra       _2@@

MsgVoltage@@        fcs       CR,'Voltage:    '
MsgResistance@@     fcs       CR,'Resistance: '

;*******************************************************************************
; Init SCI

SCI_INIT            proc
                    psha
                    lda       #$0C                ; enable Tx and Rx
                    sta       SCCR2
                    lda       #$30                ; set BAUD to 9600
                    sta       BAUD
                    pula
                    rts

;*******************************************************************************
; returns either 0 or character in {A}

Check_Input         proc
                    lda       SCSR                ; check to see if there is data incoming from the SCI
                    anda      #$20
                    beq       Done@@              ; if not, end here
                    lda       SCDR                ; otherwise read the data into A
Done@@              rts

;*******************************************************************************
; work on the byte that X points to that we get

Output              proc
                    psha
Loop@@              lda       ,x                  ; get first character of what X points to
                    inx                           ; increment x to get the next address to read from
                    tsta                          ; did we encounter a 0 char?
                    beq       Done@@              ; if so, end
                    bsr       Output_Char         ; otherwise, print the character, from regA
                    bra       Loop@@              ; and start all over
Done@@              pula
                    rts

;*******************************************************************************
; expects data to send out in A

Output_Char         proc
                    pshb
Loop@@              ldb       SCSR                ; check to see if the transmit register is empty
                    andb      #$80
                    cmpb      #$80
                    bne       Loop@@              ; if not, keep looping until it is
                    sta       SCDR                ; finally, write the character to the SCI
                    pulb
                    rts

;*******************************************************************************
; read from A/D converter and store in adresult

Read_AD             proc
                    psha
                    lda       #$01                ; prime A/D
                    sta       ADCTL
Loop@@              lda       ADCTL               ; read status bit
                    anda      #$80
                    beq       Loop@@              ; keep checking
                    lda       ADR2                ; we should have a result now
                    sta       adresult
                    pula
                    rts

;*******************************************************************************
; Do the conversion.
; Note that we never need to divide by 256, since it's just a shift right
; several times. We get the values out our own way.

FillDigits          proc
                    pshd                          ; Bug? WAS PSHA/PSHB
          ;-------------------------------------- ; multiply the result with our ref voltage
                    ldb       adresult
                    lda       #R_H
                    mul
          ;-------------------------------------- ; we end up with the most sig in A. Convert to ASCII
                    adda      #'0'
                    sta       dig5                ; save that digit
          ;--------------------------------------
          ; Multiply the remainder by 10 and convert to ASCII.
          ; That's the next digit.
          ; Continue until we get the desired precision
          ;--------------------------------------
                    bsr       ?Time10Ascii
                    sta       dig4

                    bsr       ?Time10Ascii
                    sta       dig3

                    bsr       ?Time10Ascii
                    sta       dig2

                    bsr       ?Time10Ascii
                    sta       dig1

                    puld
                    rts

;*******************************************************************************

?Time10Ascii        proc
                    lda       #10
                    mul
                    adda      #'0'
                    rts

;*******************************************************************************

Calc_Res            proc
                    psha
                    pshb
                    clrb
                    ldb       adresult
                    negb
          ;--------------------------------------
          ; we now have (256 - adresult) in D. Switch to X to prepare for division
          ;--------------------------------------
                    xgdx
                    lda       adresult
                    ldb       #R_REF
                    mul
                    idiv
                    xgdx
                    lsld:2
          ;--------------------------------------
          ; now D contains the measured resistor value in HEX
          ;--------------------------------------
                    ldx       #100
                    idiv
                    xgdx
                    ldx       #10
                    idiv
                    xgdx
                    pula
                    pulb
                    rts

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       $FFFE
                    fdb       Start
