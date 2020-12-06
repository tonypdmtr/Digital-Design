;****************
; Vars
;****************

SCCR2               equ       $102D
SCSR                equ       $102E
SCDR                equ       $102F
BAUD                equ       $102B

BUFFER_BEG          equ       $0190               ; *Starting Point of Buffer
BUFFER_END          equ       $01CC               ; *End of buffer Store 3C for 60 addresses


;**************
; Main
;**************
                    org       $2000               ; $E000 w/o Buffalo, $2000 with.

Init                proc
                    lds       #$01FF              ; init stack pointer
                    bsr       SCI_INIT            ; init SCI subsystem
                    ldx       #Name               ; Load our names into X
                    bsr       SCI_OUT_MSG         ; Dispay what's in X
Loop                ldx       #Prompt             ; Load the prompt into X...
                    bsr       SCI_OUT_MSG         ; ...and display it.
                    ldx       #BUFFER_BEG         ; save address to buffer in X
                    bsr       SCI_IN_MSG          ; read a message in
                    ldx       #Answer             ; send out answer
                    bsr       SCI_OUT_MSG
                    ldx       #BUFFER_BEG         ; send the message in the buffer
                    bsr       SCI_OUT_MSG
                    ldx       #CR                 ; finish with a line break
                    bsr       SCI_OUT_MSG
                    bra       Loop                ; rinse and repeat

;-------------------------------------------------------------------------------
; Define a few static strings
;-------------------------------------------------------------------------------
Name                fcc       "David Ibach & Christoph Koehler"
CR                  fcs       13,10
Prompt              fcs       "Enter a message: "
Answer              fcs       "After ROT13: "

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
; work on the byte in X that we get

SCI_OUT_MSG         proc
                    psha
SCI_OUT_MSG_1       lda       ,x                  ; get first character of what X points to
                    inx                           ; increment x to get the next address to read from
                    cmpa      #0                  ; did we encounter a 0 char?
                    beq       SCI_OUT_MSG_END     ; if so, end
                    bsr       SCI_Char_OUT        ; otherwise, print the character, from regA
                    bra       SCI_OUT_MSG_1       ; and start all over

SCI_OUT_MSG_END     pula
                    rts

;*******************************************************************************
; expects data to send out in A

SCI_Char_OUT        proc
                    pshb
SCI_Char_OUT_1      ldb       SCSR                ; check to see if the transmit register is empty
                    andb      #$80
                    cmpb      #$80
                    bne       SCI_Char_OUT_1      ; if not, keep looping until it is
                    sta       SCDR                ; finally, write the character to the SCI
                    pulb
                    rts

;*******************************************************************************

SCI_IN_MSG          proc
                    psha
SCI_IN_MSG_1        lda       SCSR                ; check to see if there is data incoming from the SCI
                    anda      #$20
                    beq       SCI_IN_MSG_1        ; if not, keep checking
                    lda       SCDR                ; otherwise read the data into A
                    cmpa      #$0D                ; check for ASCII 13, enter key.
                    beq       SCI_IN_MSG_END      ; if so, finish the message
                    cpx       #BUFFER_END         ; check for end of buffer
                    beq       SCI_IN_MSG_1        ; if we're at the end, loop back
                    bsr       SCI_Char_OUT        ; otherwise, print the character we just received
                    bsr       ROT13_CYPHER        ; now run the rotation cypher on regB
                    sta       0,x                 ; store the char we just received into
;                                                     the address X points to, likely the buffer
                    inx
                    clr       ,x                  ; terminate with 0 byte char.
                    bra       SCI_IN_MSG_1        ; start over

SCI_IN_MSG_END      lda       #$0D                ; to finish off the input, go to the next line to start fresh
                    bsr       SCI_Char_OUT
                    lda       #$0A
                    bsr       SCI_Char_OUT
                    pula
                    rts

ROT13_CYPHER        pshb
                    tab
                    cmpb      #$41
                    blo       ROT13_CYPHER_END    ; if the character is lower than ASCII A, end

                    tab
                    cmpb      #$5B
                    blo       ROT13_CYPHER_UP     ; now compare to 5B, one character past Z. If lower, we know
;                                                     that we have a upper case char.
                    tab
                    cmpb      #$61
                    blo       ROT13_CYPHER_END    ; now test against a. If we're lower, we have a special char: skip!

                    tab
                    cmpb      #$7B
                    blo       ROT13_CYPHER_LOW    ; check for 7B, one char past z. If we're lower,
;                                                     we know we have a lower case char

                    bra       ROT13_CYPHER_END    ; otherwise we are too high and skip to the end again

ROT13_CYPHER_UP
                    tab

                    cmpb      #$4E                ; compare to N. If we're lower, add 13, otherwise, add 13
                    blo       ROT13_CYPH_ADD13
                    bra       ROT13_CYPH_SUB13

ROT13_CYPHER_LOW
                    tab
                    cmpb      #$6E                ; compare to n. If we're lower, add 13, otherwise, add 13
                    blo       ROT13_CYPH_ADD13
                    bra       ROT13_CYPH_SUB13

ROT13_CYPH_ADD13
                    adda      #13
                    bra       ROT13_CYPHER_END

ROT13_CYPH_SUB13
                    suba      #13
;                   bra       ROT13_CYPHER_END

ROT13_CYPHER_END
                    pulb
                    rts

; comment the following two lines out for Buffalo
;                  org               $FFFE
;                  fdb               Init
