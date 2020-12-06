;***************
; VARs
;***************
SPCR                equ       $1028               ; *SPI Control
SPSR                equ       $1029               ; *SPI Status
SPDR                equ       $102A               ; *SPI Data
DDRD                equ       $1009               ; *Register D
PORTD               equ       $1008
DECIMAL             equ       $0000

;***************
; Main
;***************

                    org       $2000

                    bsr       SPI_INIT            ; *Init SPI System
Loop                bsr       SS0_EN              ; *Enables Slave Select
                    lda       #$00
                    ldb       #$FF                ; *Generic Request over SPI
                    bsr       SPI_RW              ; *Writes then reads bite from SPI
                    tba                           ; *Transfers most sig to top register
                    ldb       #$FF
                    bsr       SPI_RW
                    bsr       SS0_EN              ; *Disables Slave Select

                    lsld                          ; *Formats A to contain entire int temp
                    tab                           ; *Transfers A -> B for least sig figures
                    lda       #$00                ; *Loads 0 for most sig figures
                    bsr       HEXtoDEC            ; *Creates decimal values from hex stored in D
                    bsr       SPI_RW
                    bsr       delay
                    bra       Loop

;**************
; SUBs
;**************

; *Init SPI
SPI_INIT
                    ldb       DDRD                ; *Load Current state of DDRD
                    orb       #$38                ; *Turn on Slave select
                    stb       DDRD                ; *store
                    ldb       #$70                ; *Enable SPI
                    stb       SPCR
                    ldb       PORTD
                    orb       #$20
                    stb       PORTD
                    rts

; *Toggles *SS0 - temp sensor
SS0_EN
                    pshb
                    ldb       PORTD               ; *Load Current State of DDRD
                    eorb      #$20                ; *Toggle Slave Select
                    stb       PORTD               ; *Store back
                    pulb
                    rts

; *Returns {B} temp from sensor
SPI_RW
                    psha
                    stb       SPDR                ; *Store $FF into SPI Data
                    lda       PORTD
                    anda      #$20

SPI_RW1
                    ldb       SPSR                ; *Reads SPI Status Register
                    andb      #$80                ; *Checks for status high on bit 7
                    beq       SPI_RW1             ; *Checks again if not high
                    ldb       SPDR                ; *Pulls data from SPI
SPI_RW_E            pula
                    rts

delay
                    pshx
                    ldx       #$FFFF
delay1              cpx       #$00
                    beq       delay2
                    dex
                    bra       delay1

delay2              pulx
                    rts

; *Returns {B} temp in 4 bit most sig decimal in binary -> 0000 and 4 bit lest sig decimal in binary -> 0000
HEXtoDEC
                    pshx
                    ldx       #$000A              ; *Load x with 10
                    idiv                          ; *Divide D/X
                    stb       DECIMAL
                    xgdx                          ; *Exchange remainder(D) with int(X)
                    lslb                          ; *Left shift D 4 times putting it to most sig
                    lslb
                    lslb
                    lslb
                    addb      DECIMAL             ; *Add x to b which is the remainder as least sig
                    pulx
                    rts
