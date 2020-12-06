SPCR                equ       $1028               ; SPI Control
SPSR                equ       $1029               ; SPI Status
SPDR                equ       $102A               ; SPI Data
DDRD                equ       $1009               ; Register D
PORTD               equ       $1008
DECIMAL             equ       $0000

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $2000

Start               proc
                    bsr       SPI_INIT            ; Init SPI System
Loop@@              bsr       SS0_EN              ; Enables Slave Select
                    ldd       #$FF                ; Generic Request over SPI
                    bsr       SPI_RW              ; Writes then reads bite from SPI
                    tba                           ; Transfers most sig to top register
                    ldb       #$FF
                    bsr       SPI_RW
                    bsr       SS0_EN              ; Disables Slave Select
                    lsld                          ; Formats A to contain entire int temp
                    tab                           ; Transfers A -> B for least sig figures
                    clra                          ; Loads 0 for most sig figures
                    bsr       HEXtoDEC            ; Creates decimal values from hex stored in D
                    bsr       SPI_RW
                    bsr       delay
                    bra       Loop@@

;*******************************************************************************
; Init SPI

SPI_INIT            proc
                    ldb       DDRD                ; Load Current state of DDRD
                    orb       #$38                ; Turn on Slave select
                    stb       DDRD                ; store
                    ldb       #$70                ; Enable SPI
                    stb       SPCR
                    ldb       PORTD
                    orb       #$20
                    stb       PORTD
                    rts

;*******************************************************************************
; Toggles *SS0 - temp sensor

SS0_EN              proc
                    psha
                    lda       PORTD               ; Load Current State of DDRD
                    eora      #$20                ; Toggle Slave Select
                    sta       PORTD               ; Store back
                    pula
                    rts

;*******************************************************************************
; Returns {B} temp from sensor

SPI_RW              proc
                    psha
                    stb       SPDR                ; Store $FF into SPI Data
                    lda       PORTD
                    anda      #$20
Loop@@              ldb       SPSR                ; Reads SPI Status Register
                    andb      #$80                ; Checks for status high on bit 7
                    beq       Loop@@              ; Checks again if not high
                    ldb       SPDR                ; Pulls data from SPI
                    pula
                    rts

;*******************************************************************************

delay               proc
                    pshx
                    ldx       #$FFFF
Loop@@              cpx       #0
                    beq       Done@@
                    dex
                    bra       Loop@@
Done@@              pulx
                    rts

;*******************************************************************************
; Returns {B} temp in 4 bit most sig decimal in binary -> 0000 and 4 bit lest sig decimal in binary -> 0000

HEXtoDEC            proc
                    pshx
                    ldx       #10
                    idiv                          ; Divide D/X
                    stb       DECIMAL
                    xgdx                          ; Exchange remainder(D) with int(X)
                    lslb:4                        ; Left shift D 4 times putting it to most sig
                    addb      DECIMAL             ; Add x to b which is the remainder as least sig
                    pulx
                    rts
