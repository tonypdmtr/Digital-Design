;*******************************************************************************
; Christoph Koehler
; Project 2
; Counter with LCD display and LED indicators for high/low status
;*******************************************************************************

DDRC                equ       $1007               ; data direction register for PORT C
PORTA               equ       $1000               ; counter/switch input on bit 0, mode toggle switch on bit 1
PORTB               equ       $1004               ; output for LCD. bits 0-7
PORTC               equ       $1003               ; output for LEDs, bit 0 green and bit 1 red

;*******************************************************************************
                    #RAM
;*******************************************************************************

last_time           rmb       1
switched            rmb       1                   ; set to 1 if switch triggered, 0 otherwise
hex                 rmb       1
decimal             rmb       1
counter             rmb       1
mode                rmb       1

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $D000

Start               proc
                    lds       #$01FF              ; set stack pointer
                    bsr       InitPorts           ; init ports and variables
Loop@@              bsr       SanityCheck         ; makes sure the counter is between 0 and 50
                    bsr       CheckMode           ; see if we're counting up or down. 0 = up, 1 = down
                    jsr       SwitchCheck         ; check if we switched the counting switch
                    bsr       CheckLEDs           ; check leds and set if count is 0 or 50
                    bsr       PrintCounter        ; display the counter on the LCDs
                    bsr       ChangeCounter       ; decrement or increment the counter
                    bra       Loop@@              ; repeat

;*******************************************************************************

InitPorts           proc
          ;-------------------------------------- ; clear a bunch of vars
                    clr       last_time
                    clr       switched
                    clr       hex
                    clr       decimal
                    clr       counter
                    clr       mode
          ;-------------------------------------- ; set PORT C for output
                    lda       #$3
                    sta       DDRC
                    rts

;*******************************************************************************
; make sure the counter is between 0 and 50 at all times

SanityCheck         proc
                    lda       counter
                    cmpa      #50
                    bgt       ResetCounter
                    tsta
                    bpl       Done@@
;                   bra       ResetCounter
Done@@              equ       :AnRTS

;*******************************************************************************
; resets counter to 0

ResetCounter        proc
                    clr       counter
                    rts

;*******************************************************************************
; checks which mode we are in, inc or dec counter

CheckMode           proc
                    lda       PORTA
                    anda      #$02                ; get bit 1 only
                    sta       mode
                    clr       switched            ; reset switched. prevents counter from changing if
                    rts                           ; we just toggle the mode switch

;*******************************************************************************
; increments or decrements the counter depending on our mode

ChangeCounter       proc
                    lda       mode
          ;--------------------------------------
          ; increment if mode == 0, decrement if mode == 1 - corresponds to mode switch
          ;--------------------------------------
                    bne       DecCounter
;                   bra       IncCounter

;*******************************************************************************

IncCounter          proc
                    lda       switched            ; get switched...
                    beq       Done@@              ; ...if we aren't, end
                    ldb       counter             ; ...else, proceed
                    subb      #50                 ; subtract decimal 50, which will result in 0 if counter is 50
          ;--------------------------------------
          ; if we get 0 in B, we are at the max of 50 and end here
                    beq       Done@@
          ;-------------------------------------- ; else increment the counter
                    lda       counter
                    inca
                    sta       counter
                    clr       switched
Done@@              rts

;*******************************************************************************
; same as increment counter, except we decrement

DecCounter          proc
                    lda       switched
                    beq       Done@@
                    lda       counter
                    beq       Done@@
                    deca
                    sta       counter
                    clr       switched
Done@@              rts

;*******************************************************************************
; determine if we need to light up any of the LEDs

CheckLEDs           proc
          ;--------------------------------------
          ; get counter, subtract 50 to see if we're at 50. If we are, Z flag will be set
          ; and we activate the green led
          ;--------------------------------------
                    lda       counter
                    suba      #50
                    beq       ActivateGreenLED
          ;--------------------------------------
          ; load counter again and check for Z flag. If it's set, counter == 0 and we
          ; need to activate the red led
          ;--------------------------------------
                    lda       counter
                    beq       ActivateRedLED
          ;-------------------------------------- ; otherwise reset both LEDs
                    clr       PORTC
                    rts

;*******************************************************************************

ActivateGreenLED    proc
                    lda       #$01
                    sta       PORTC
                    rts

;*******************************************************************************

ActivateRedLED      proc
                    lda       #$02
                    sta       PORTC
                    rts

;*******************************************************************************
; print the counter to the LCDs

PrintCounter        proc
          ;-------------------------------------- ; get counter and store it in hex, since it's a hex number
                    lda       counter
                    sta       hex
          ;-------------------------------------- ; then convert it. we will get the result in decimal
                    bsr       HexToDec
          ;-------------------------------------- ; take decimal and output to the LCDs on PORT B
                    lda       decimal
                    sta       PORTB
                    rts

;*******************************************************************************
; check if we switched the switch once

SwitchCheck         proc
          ;--------------------------------------
          ; get switch status into A, mask out all but bit 0, and push that onto the stack
          ;--------------------------------------
                    lda       PORTA
                    anda      #$01
                    psha
          ;--------------------------------------
          ; we don't care if switch is 1 because we are switched on release, i.e. 0.
          ;--------------------------------------
                    bne       Done@@
          ;--------------------------------------
          ; getting here means the switch is off, i.e. 0
          ; now load the last status and mask out all but bit 0.
          ;--------------------------------------
                    lda       last_time
                    anda      #1
          ;--------------------------------------
          ; current status is 0, if last status was 0 also, end.
          ;--------------------------------------
                    beq       Done@@
          ;-------------------------------------- ; if not, we are switched, so indicate that
                    lda       #1
                    sta       switched
          ;-------------------------------------- ; store current status as last status
Done@@              pula
                    sta       last_time
                    rts

;*******************************************************************************
; convert number in hex to decimal

HexToDec            proc
                    ldx       #10                 ; that's what we divide by
          ;--------------------------------------
          ; load hex into least significant position of D, i.e. B.
          ; Most significant, i.e. A, is set to 0.
          ;--------------------------------------
                    clra
                    ldb       hex
                    idiv                          ; divide hex by 10 (0A)
                    stb       decimal
                    xgdx                          ; swap x and d because we can't move x directly to decimal
                    lslb:4                        ; move most significant byte over
                    addb      decimal             ; combine the bytes
                    stb       decimal
                    rts

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       $FFFE
                    dw        Start
