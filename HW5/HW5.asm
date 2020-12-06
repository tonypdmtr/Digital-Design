; ;;;;;;;;;;;;
; Vars
; ;;;;;;;;;;;;

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

                    org       $2000
Note                rmb       2
Sample              rmb       2
Buffer              rmb       2

; ;;;;;;;;;;
; Main
; ;;;;;;;;;;

                    org       $1000
Start
                    cli
                    bsr       InitTimer
                    bsr       InitPWM
                    bsr       PlayC
Loop                bra       Loop

; ;;;;;;;;;;
; Subs
; ;;;;;;;;;;


InitTimer           lda       #$02                ; TC1 Timer
                    sta       TIOS
                    lda       #$80                ; Enable Timer
                    sta       TSCR
                    rts

InitPWM             clr       PWCLK
                    lda       PWCTL
                    ora       #$08
                    sta       PWCTL
                    rts

PlayC               ldd       #DelayD             ; load delay time
                    std       Note
                    bsr       StartNote
                    rts

PlayD               ldd       #DelayD             ; load delay time
                    std       Note
                    bsr       StartNote
                    rts

PlayE               ldd       #DelayE             ; load delay time
                    std       Note
                    bsr       StartNote
                    rts

StartNote           ldx       #SinWave            ; Set to begging of buffer
                    lda       1,x                 ; load sample
                    inx
                    sta       PWDTY0              ; store sample to PWM Duty
                    stx       Sample              ; Store inc to sample
                    ldd       TCNT
                    addd      Note
                    std       TC1                 ; Set 1/20 C Period
                    lda       #$A0
                    sta       PWPER0

                    lda       #$02                ; Enable Interuppt
                    sta       TMSK1
                    lda       #$01                ; Enable PWM
                    sta       PWEN
                    rts

StopNote            pshd
                    lda       #$00
                    sta       TMSK1
                    lda       #$00
                    sta       PWEN
                    puld
                    rts

; Checks Rows
SelectRow           psha
                    lda       #$10
                    sta       DDRH
                    sta       PORTH
SelectRowRTS        pula
                    rts

; Checks Cols
CheckCol            psha
                    pshx
                    pshb
                    ldx       #0                  ; Init to 0
                    lda       PORTH               ; load port
                    anda      #$0F                ; mask MSBs
                    beq       CheckColRTS         ; Exit if none set
                    bita      #$01
                    beq       Act1
                    bita      #$02
                    beq       Act2
                    bita      #$04
                    beq       Act3
                    bita      #$08
                    beq       Act4
                    bra       CheckColRTS

Act1                bsr       PlayC
A1_LOOP             ldb       PORTH
                    andb      #$01
                    bne       A1_LOOP
                    bsr       StopNote
                    bra       CheckColRTS

Act2                bsr       PlayD
A2_LOOP             ldb       PORTH
                    andb      #$02
                    bne       A2_LOOP
                    bsr       StopNote
                    bra       CheckColRTS

Act3                jsr       PlayE
A3_LOOP             ldb       PORTH
                    andb      #$04
                    bne       A3_LOOP
                    bsr       StopNote
                    bra       CheckColRTS

Act4                ldd       Buffer
                    anda      #]SinWave
                    andb      #[SinWave
                    cmpd      #0
                    bne       Sine
                    ldd       #TriWave
                    bra       CheckCol1

Sine                ldd       #SinWave

CheckCol1           std       Buffer
CheckColRTS         pulb
                    pulx
                    pula
                    rts

; ;;;;;;;;;;;
; ISRs
; ;;;;;;;;;;;

ISR_Timer           pshd
                    pshx
                    ldd       TCNT                ; Get Current value
                    addd      Note                ; Add delay
                    std       TC1                 ; Store delay
                    lda       #$02                ; Reset Flag
                    sta       TFLG1
                    ldx       Sample              ; Load Current Sample addr
                    lda       1,x                 ; Load sample value inc
                    bne       ISR_Timer1          ; if sample is zero restart buffer
                    ldx       #SinWave
                    lda       1,x
ISR_Timer1
                    inx
                    stx       Sample              ; Store current sample addr
                    sta       PWDTY0              ; Set Duty Cycle
                    clr       PWCNT0              ; Reset PWM
                    cli
                    pulx
                    puld
                    rti

                    org       $62c
                    fdb       ISR_Timer

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
