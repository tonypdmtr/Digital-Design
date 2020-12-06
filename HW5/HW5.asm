                    #CaseOn

PWCLK               equ       $0840               ; Clk
PWEN                equ       $0842               ; Enable
PWSCAL0             equ       $0844               ; Scale Clock
PWCNT0              equ       $0848               ; Channel Counters
PWPER0              equ       $084C               ; Period
PWDTY0              equ       $0850               ; Duty Cycle
PWCTL               equ       $0854               ; control

TIOS                equ       $0880               ; In/Out
TCNT                equ       $0884               ; CNT High
TSCR                equ       $0886               ; Control
TMSK1               equ       $088C               ; Enable flag
TFLG1               equ       $088E               ; Flags
TC1                 equ       $0892               ; CNT Set

PORTH               equ       $0829
DDRH                equ       $082B

PORTG               equ       $0828
DDRG                equ       $082A

DelayC              equ       1420                ; 1527
DelayD              equ       1253                ; 1360
DelayE              equ       1212
DelayF              equ       1146
DelayG              equ       1020
DelayA              equ       909
DelayB              equ       810

;*******************************************************************************
                    #RAM
;*******************************************************************************
                    org       $2000

note                rmb       2
sample              rmb       2
buffer              rmb       2

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $1000

Start               proc
                    cli
                    bsr       InitTimer
                    bsr       InitPWM
                    bsr       PlayC
                    bra       *

;*******************************************************************************

InitTimer           proc
                    lda       #$02                ; TC1 Timer
                    sta       TIOS
                    lda       #$80                ; Enable Timer
                    sta       TSCR
                    rts

;*******************************************************************************

InitPWM             proc
                    clr       PWCLK
                    lda       PWCTL
                    ora       #$08
                    sta       PWCTL
                    rts

;*******************************************************************************

PlayC               proc
                    ldd       #DelayD             ; load delay time
                    bra       StartNote

;*******************************************************************************

PlayD               proc
                    ldd       #DelayD             ; load delay time
                    bra       StartNote

;*******************************************************************************

PlayE               proc
                    ldd       #DelayE             ; load delay time
;                   bra       StartNote

;*******************************************************************************

StartNote           proc
                    std       note
                    ldx       #SinWave            ; Set to begging of buffer
                    inx
                    lda       ,x                  ; load sample
                    sta       PWDTY0              ; store sample to PWM Duty
                    stx       sample              ; Store inc to sample
                    ldd       TCNT
                    addd      note
                    std       TC1                 ; Set 1/20 C Period
                    lda       #$A0
                    sta       PWPER0
                    lda       #$02                ; Enable Interuppt
                    sta       TMSK1
                    lda       #$01                ; Enable PWM
                    sta       PWEN
                    rts

;*******************************************************************************

StopNote            proc
                    psha
                    clra
                    sta       TMSK1
                    sta       PWEN
                    pula
                    rts

;*******************************************************************************
; Checks Rows

SelectRow           proc
                    psha
                    lda       #$10
                    sta       DDRH
                    sta       PORTH
                    pula
                    rts

;*******************************************************************************
; Checks Cols

CheckCol            proc
                    psha
                    pshx
                    pshb
                    clrx                          ; Init to 0
                    lda       PORTH               ; load port
                    anda      #$0F                ; mask MSBs
                    beq       Done@@              ; Exit if none set
                    bita      #$01
                    beq       _1@@
                    bita      #$02
                    beq       _2@@
                    bita      #$04
                    beq       _3@@
                    bita      #$08
                    beq       _4@@
                    bra       Done@@
          ;--------------------------------------
_1@@                bsr       PlayC
Loop1@@             ldb       PORTH
                    andb      #$01
                    bne       Loop1@@
                    bsr       StopNote
                    bra       Done@@
          ;--------------------------------------
_2@@                bsr       PlayD
Loop2@@             ldb       PORTH
                    andb      #$02
                    bne       Loop2@@
                    bsr       StopNote
                    bra       Done@@
          ;--------------------------------------
_3@@                bsr       PlayE
Loop3@@             ldb       PORTH
                    andb      #$04
                    bne       Loop3@@
                    bsr       StopNote
                    bra       Done@@
          ;--------------------------------------
_4@@                ldd       buffer
                    anda      #]SinWave
                    andb      #[SinWave
                    cmpd      #0
                    bne       Sine@@
                    ldd       #TriWave
                    bra       _5@@
Sine@@              ldd       #SinWave
_5@@                std       buffer
Done@@              pulb
                    pulx
                    pula
                    rts

;*******************************************************************************

ISR_Timer           proc
                    pshd
                    pshx
                    ldd       TCNT                ; Get Current value
                    addd      note                ; Add delay
                    std       TC1                 ; Store delay
                    lda       #$02                ; Reset Flag
                    sta       TFLG1
                    ldx       sample              ; Load Current Sample addr
                    lda       1,x                 ; Load sample value inc
                    bne       _1@@                ; if sample is zero restart buffer
                    ldx       #SinWave
                    lda       1,x
_1@@                inx
                    stx       sample              ; Store current sample addr
                    sta       PWDTY0              ; Set Duty Cycle
                    clr       PWCNT0              ; Reset PWM
                    cli
                    pulx
                    puld
                    rti

;*******************************************************************************

                    org       $62c
                    fdb       ISR_Timer

;*******************************************************************************

                    org       $2010

SinWave             fcb       128
                    fcb       165
                    fcb       200
                    fcb       227
                    fcb       246
                    fcb       255
                    fcb       252
                    fcb       238
                    fcb       214
                    fcb       183
                    fcb       147
                    fcb       109
                    fcb       73
                    fcb       42
                    fcb       18
                    fcb       4
                    fcb       1
                    fcb       10
                    fcb       29
                    fcb       56
                    fcb       91
                    fcb       0

TriWave             fcb       128
                    fcb       0
