SCCR2               equ       $102D
SCSR                equ       $102E
SCDR                equ       $102F
BAUD                equ       $102B

BUFFER_BEG          equ       $0190               ; *Starting Point of Buffer
BUFFER_END          equ       $01CC               ; *End of buffer Store 3C for 60 addresses

CR                  equ       13
LF                  equ       10

;*******************************************************************************
                    #ROM      $2000               ; $E000 w/o Buffalo, $2000 with.
;*******************************************************************************

Init                proc
                    lds       #$01FF              ; init stack pointer
                    bsr       SCI_INIT            ; init SCI subsystem

                    ldx       #Name               ; Load our names into X
                    bsr       SCI_OUT_MSG         ; Dispay what's in X

Loop@@              ldx       #Prompt             ; Load the prompt into X...
                    bsr       SCI_OUT_MSG         ; ...and display it.

                    ldx       #BUFFER_BEG         ; save address to buffer in X
                    bsr       SCI_IN_MSG          ; read a message in

                    ldx       #Answer             ; send out answer
                    bsr       SCI_OUT_MSG

                    ldx       #BUFFER_BEG         ; send the message in the buffer
                    bsr       SCI_OUT_MSG
                    jsr       NewLine             ; finish with a line break
                    bra       Loop@@              ; rinse and repeat

;*******************************************************************************
; Define a few static strings

Name                fcs       'David Ibach & Christoph Koehler',CR,LF
Prompt              fcs       'Enter a message: '
Answer              fcs       'After ROT13: '

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
                    pshx
                    psha
Loop@@              lda       ,x                  ; get first character of what X points to
                    beq       Done@@              ; if we encounter a 0 char, end
                    bsr       SCI_Char_OUT        ; otherwise, print the character, from regA
                    inx                           ; increment x to get the next address to read from
                    bra       Loop@@              ; and start all over
Done@@              pula
                    pulx
                    rts

;*******************************************************************************
; expects data to send out in A

SCI_Char_OUT        proc
Loop@@              tst       SCSR                ; check to see if the transmit register is empty
                    bmi       Loop@@              ; if not, keep looping until it is
                    sta       SCDR                ; finally, write the character to the SCI
                    rts

;*******************************************************************************

SCI_IN_MSG          proc
                    psha
Loop@@              lda       SCSR                ; check to see if there is data incoming from the SCI
                    anda      #$20
                    beq       Loop@@              ; if not, keep checking
                    lda       SCDR                ; otherwise read the data into A
                    cmpa      #CR                 ; check for ASCII 13, enter key.
                    beq       Done@@              ; if so, finish the message
                    cpx       #BUFFER_END         ; check for end of buffer
                    beq       Loop@@              ; if we're at the end, loop back
                    bsr       SCI_Char_OUT        ; otherwise, print the character we just received
                    bsr       ROT13_CYPHER        ; now run the rotation cypher on regB
                    sta       ,x                  ; store the char we just received into
                    inx                           ; the address X points to, likely the buffer
                    clr       ,x                  ; terminate with 0 byte char.
                    bra       Loop@@              ; start over

;*******************************************************************************

NewLine             proc
                    psha
?NewLine            lda       #CR                 ; to finish off the input, go to the next line to start fresh
                    bsr       SCI_Char_OUT
                    lda       #LF
                    bsr       SCI_Char_OUT
                    pula
                    rts
                    endp

;*******************************************************************************

Done@@              equ       ?NewLine

;*******************************************************************************

ROT13_CYPHER        proc
                    cmpa      #'A'
                    blo       Done@@              ; if the character is lower than ASCII A, end

                    cmpa      #'['
                    blo       Upper@@             ; now compare to 5B, one character past Z. If lower, we know
                                                  ; that we have a upper case char.
                    cmpa      #'a'
                    blo       Done@@              ; now test against a. If we're lower, we have a special char: skip!

                    cmpa      #'{'
                    blo       Lower@@             ; check for 7B, one char past z. If we're lower,
                                                  ; we know we have a lower case char
                    bra       Done@@              ; otherwise we are too high and skip to the end again

Upper@@             cmpa      #'N'                ; compare to N. If we're lower, add 13, otherwise, add 13
                    blo       Add@@
                    bra       Subtract@@

Lower@@             cmpa      #'n'                ; compare to n. If we're lower, add 13, otherwise, add 13
                    bhs       Subtract@@

Add@@               adda      #13+13

Subtract@@          suba      #13
Done@@              rts

;*******************************************************************************
; Comment the following two lines out for Buffalo
;*******************************************************************************

;                  #VECTORS   $FFFE
;                  dw         Init
