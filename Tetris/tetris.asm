                    #CaseOn

SP0CR1              equ       $08D0               ; SPI Control
SP0SR               equ       $08D3               ; SPI Status
SP0DR               equ       $08D5               ; SPI Data
SP0BR               equ       $08D2               ; BAUD register
DDRS                equ       $08D7
PORTS               equ       $08D6

SC0SR1              equ       $08C4
SC0DRL              equ       $08C7

PORTG               equ       $0828               ; Expanded Address of Command
DDRG                equ       $082A
PORTH               equ       $0829               ; Expanded Address of Data
DDRH                equ       $082B

TIOS                equ       $0880               ; In/Out
TCNT                equ       $0884               ; CNT High
TSCR                equ       $0886               ; Control
TMSK1               equ       $088C               ; Enable flag
TMSK2               equ       $088D               ; prescaler
TFLG1               equ       $088E               ; Flags
TC1                 equ       $0892               ; CNT Set
TC2                 equ       $0894

BIT_0               equ       1                   ; /RESET
BIT_1               equ       2                   ; /READ
BIT_2               equ       4                   ; /WRITE
BIT_3               equ       8                   ; /CS
BIT_4               equ       16                  ; A0

CursorInit          equ       $0005               ; Initial Condition for LCD stage

Mwrite              equ       $42                 ; Memory write command for LCD

all_block_hght      equ       112

;*******************************************************************************
                    #RAM
;*******************************************************************************
                    org       $00

          ;-------------------------------------- ; cursor pointers used to define location on screen
CPointer            rmb       2                   ; Pointer for current block
CCPointer           rmb       2                   ; Pointer for clearning current block
CSPointer           rmb       2                   ; Pointer for stage
CHPointer           rmb       2                   ; Pointer for header

Score               rmb       2                   ; Score memory for game
          ;-------------------------------------- ; define memory range to store the stage in.
                                                  ; stage = all unmovable pixels
stage_beg           rmb       16
stage_end           rmb       1

block_ptr           rmb       2                   ; points to the bottom memory location that defines the block shape
block_height        rmb       1                   ; it's the block height

buttons1            rmb       1                   ; L D R U Start _ _ Select
buttons2            rmb       1                   ; Square X O /\ R1 L1 R2 L2
          ;-------------------------------------- ; saves last button configs
buttons1l           rmb       1
buttons2l           rmb       1

stage_block_ptr     rmb       2                   ; offset from top of the stage, downwards
          ;-------------------------------------- ; FF if vertical collision detected
collision           rmb       1
game_over           rmb       1

temp                rmb       2
shift_offset        rmb       1
rot_offset          rmb       1
cur_block_id        rmb       1
          ;-------------------------------------- ; save state information here
sav_block_ptr       rmb       2
sav_shft_offset     rmb       1
sav_rot_offset      rmb       1

;*******************************************************************************
                    #ROM
;*******************************************************************************
                    org       $1000

Init                proc
                    sei
                    bsr       ClearStateMemory
                    bsr       SPI_INIT
                    bsr       Var_Init
                    jsr       LCD_INIT
                    jsr       InitCurPointers
                    bsr       InitStage
                    bsr       InitTimer
                    cli
                    bra       Main

;*******************************************************************************

SPI_INIT            proc
                    ldb       DDRS                ; Load Current state of DDRS
                    orb       #%11100000          ; Define output ports for Port S
                    stb       DDRS                ; store
                    ldb       #%01011101          ; Enable SPI
                    stb       SP0CR1
                    ldb       #%00000110          ; set rate to 64kHz
                    stb       SP0BR
                    ldb       PORTS
                    orb       #$80
                    stb       PORTS
                    rts

;*******************************************************************************
; initialize variables here

Var_Init            proc
                    lda       #4
                    clr       buttons1l
                    clr       buttons2l
                    sta       block_height
                    lda       #128
                    sta       rot_offset
                    clr       shift_offset
                    clrd
                    std       Score
                    coma
                    sta       stage_end
                    clr       game_over
                    clr       collision
                    rts

;*******************************************************************************
; initialize timer subsystem

InitTimer           proc
                    ldd       #$FFFF
                    std       TC1
                    lda       #$0F
                    std       TC2
                    lda       #$07
                    sta       TMSK2
                    lda       #$06                ; TC1, TC2 Timer
                    sta       TIOS
                    lda       #$80                ; Enable Timer
                    sta       TSCR
                    lda       #$06                ; TC1 - EN, TC2 - EN
                    sta       TMSK1
                    rts

;*******************************************************************************
; draw up the stage

InitStage           proc
                    jsr       DrawStageBounds
                    jsr       ScoreBoard
                    jsr       DetermineBlock
                    jsr       ServeBlock
                    jsr       DrawShape
                    jmp       TetrisTitle

;*******************************************************************************

ClearStateMemory    proc
                    ldx       #stage_beg
                    ldb       #16
Loop@@              clr       ,x
                    inx
                    decb
                    bne       Loop@@
                    rts

;*******************************************************************************

Main                proc
                    jsr       GetButtons
          ;-------------------------------------- ; check for down button
                    lda       buttons1
                    anda      #$40
                    beq       _2@@
                    sei
_1@@                jsr       move_down
                    lda       collision
                    beq       _1@@
                    clr       collision
                    cli
                    bra       Finish@@
_2@@      ;-------------------------------------- ; check for left button
                    lda       buttons1
                    anda      #$80
                    beq       _3@@
                    jsr       check_hcol_l
                    lda       collision
                    bne       Finish@@
                    jsr       MoveLeft
                    dec       shift_offset
                    bra       Finish@@
_3@@      ;-------------------------------------- ; check for right button
                    lda       buttons1
                    anda      #$20
                    beq       _4@@
                    jsr       check_hcol_r
                    lda       collision
                    bne       Finish@@
                    jsr       MoveRight
                    inc       shift_offset
                    bra       Finish@@
_4@@      ;-------------------------------------- ; check for rotate left (square)
                    lda       buttons2
                    anda      #$80
                    beq       _5@@
                    jsr       SaveState
                    jsr       RotateLeft
                    jsr       check_rcol
                    lda       collision
                    beq       Finish@@
                    jsr       RevertState
                    bra       Finish@@
_5@@      ;-------------------------------------- ; check for rotate right (X)
                    lda       buttons2
                    anda      #$40
                    beq       _6@@
                    jsr       SaveState
                    jsr       RotateRight
                    jsr       check_rcol
                    lda       collision
                    beq       Finish@@
                    jsr       RevertState
                    bra       Finish@@
_6@@      ;-------------------------------------- ; check for Pause (Start button )
                    lda       buttons1
                    anda      #$08
                    beq       Finish@@
                    sei
                    jsr       DrawPause
Loop@@              bsr       GetButtons
                    lda       buttons1
                    anda      #$08
                    beq       Loop@@
                    jsr       ClearPause
                    cli
;                   bra       Finish@@
Finish@@            lda       game_over
                    jne       ShowGameOver
          ;-------------------------------------- ; reset collision byte. It's a new dawn!
                    clr       collision
                    jmp       Main

;*******************************************************************************
; saves buttons in buttons1 and buttons2

GetButtons          proc
                    psha
                    pshb
                    bsr       Pad_En
                    ldb       #$01                ; send Hello to pad
                    bsr       Pad_RW
                    ldb       #$42                ; now send request for data
                    bsr       Pad_RW              ; after this we get Pad ID
                    ldb       #$00
                    bsr       Pad_RW
                    ldb       #$00
                    bsr       Pad_RW
                    comb
                    cmpb      buttons1l
                    bne       _1@@
                    clr       buttons1
                    bra       _2@@
_1@@                stb       buttons1
                    stb       buttons1l
_2@@                clrb
                    bsr       Pad_RW
                    comb
                    cmpb      buttons2l
                    bne       _3@@
                    clr       buttons2
                    bra       _4@@
_3@@                stb       buttons2
                    stb       buttons2l
_4@@                bsr       Pad_En
                    pulb
                    pula
                    rts

;*******************************************************************************
; SPI utility methods
;*******************************************************************************

;*******************************************************************************
; Toggles Pad SS

Pad_En              proc
                    pshb
                    ldb       PORTS               ; Load Current State of PORTS
                    eorb      #$80                ; Toggle Slave Select
                    stb       PORTS               ; Store back
                    pulb
                    rts

;*******************************************************************************
; In: {B} with what's sent to the pad
; Out: {B} with what's returned

Pad_RW              proc
                    psha
                    stb       SP0DR               ; Store {B} to send to pad
Loop@@              ldb       SP0SR               ; Reads Pad Status Register
                    andb      #$80                ; Checks for status high on bit 7
                    beq       Loop@@              ; Checks again if not high
                    ldb       SP0DR               ; Pulls data from Pad
                    pula
                    rts


;*******************************************************************************
; Button actions
;*******************************************************************************

;*******************************************************************************
; shift block left

MoveLeft            proc
                    pshx
                    pshb
                    ldx       block_ptr
                    ldb       block_height
Loop@@              lsl       ,x
                    dex
                    decb
                    bne       Loop@@
                    pulb
                    pulx
                    rts

;*******************************************************************************
; shift the block right

MoveRight           proc
                    pshx
                    pshb
                    ldx       block_ptr
                    ldb       block_height
Loop@@              lsr       ,x
                    dex
                    decb
                    bne       Loop@@
                    pulb
                    pulx
                    rts

;*******************************************************************************

RotateLeft          proc
                    pshx
                    pshb
                    inc       rot_offset
                    ldb       cur_block_id
                    jsr       ServeBlock
                    pulb
                    pulx
                    rts

;*******************************************************************************

RotateRight         proc
                    pshx
                    pshb
                    dec       rot_offset
                    ldb       cur_block_id
                    jsr       ServeBlock
                    pulb
                    pulx
                    rts

;*******************************************************************************

move_down           proc
                    ldx       block_ptr
                    jsr       check_vcol
                    lda       collision
                    cmpa      #$FF
; if we have a collision, merge block into the stage.
; else increment stage block pointer
                    beq       move_down_2
                    ldd       stage_block_ptr
                    incb
                    std       stage_block_ptr
                    bra       move_down_end

move_down_2
                    bsr       merge_blk2stg
                    bsr       clr_fl_rws
                    jsr       DrawStage
                    bsr       CheckGameOver
move_down_3
                    jsr       DetermineBlock
                    jsr       ServeBlock
move_down_end
                    rts

;*******************************************************************************

ShowGameOver        proc
                    sei
                    jsr       GameOver
Loop@@              jsr       GetButtons
                    lda       buttons1
                    anda      #$08
                    beq       Loop@@
                    jmp       Init

;*******************************************************************************
; Game Logic subs
;*******************************************************************************

CheckGameOver       proc
                    pshx
                    psha
                    ldx       #stage_beg
                    lda       ,x
                    anda      #$FF
                    beq       Done@@
                    lda       #$FF
                    sta       game_over
Done@@              pula
                    pulx
                    rts

;*******************************************************************************

clr_fl_rws          proc
                    pshx
                    psha
          ;-------------------------------------- ; start at the end of the stage
                    ldx       #stage_end
                    dex
                    clrb
Loop@@    ;-------------------------------------- ; see if the current row is full
                    lda       ,x
                    cmpa      #$FF
          ;-------------------------------------- ; if not, move on, else, do some stuff
                    bne       _3@@
          ;-------------------------------------- ; transfer X to Y and work with it for the internal loop
                    pshx
                    pshd
                    xgdx
                    xgdy
                    puld
                    pulx
          ;-------------------------------------- ; also increase the score
                    jsr       Score_Inc
                    incb
                    cmpb      #4
                    bne       _1@@
                    jsr       Score_Inc_Bonus
_1@@      ;--------------------------------------
          ; take the previous row and overwrite the current row with it
          ;--------------------------------------
                    dey
                    lda       ,y
                    sta       1,y
          ;--------------------------------------
          ; if we're at the top of the stage, exit this loop.
          ; otherwise, keep moving lines down
          ;--------------------------------------
                    cpy       #stage_beg
                    beq       _2@@
                    bra       _1@@
_3@@      ;--------------------------------------
          ; now move up to the next line and start the process over,
          ; until we arrive at the beginning of the stage.
          ;--------------------------------------
                    dex
_2@@                cpx       #stage_beg
                    bne       Loop@@
                    clrb
                    pula
                    pulx
                    rts

;*******************************************************************************

merge_blk2stg       proc
                    push
                    ldb       block_height
                    ldy       stage_block_ptr
                    tyx
                    aix       #stage_beg
                    ldy       block_ptr
Loop@@              lda       ,x
                    ora       ,y
                    sta       ,x
                    dex
                    dey
                    decb
                    bne       Loop@@
                    pull
                    rts

;*******************************************************************************

DetermineBlock      proc
                    bsr       rst_van_blks
                    lda       #128
                    sta       rot_offset
                    clr       shift_offset
                    ldd       TCNT
                    ldx       #7
                    idiv
          ;-------------------------------------- ; now we have a number from 0-4 in D/B
;                   ldb       #1
                    stb       cur_block_id
                    pshb
                    ldd       #$3
                    std       stage_block_ptr
                    pulb
                    rts

;*******************************************************************************
; serve the block with ID given in B

ServeBlock          proc
; shift the block back to initial position. Then, later, we
; move it forward again to the right spot.
;
                    lda       shift_offset
Loop@@              beq       _1@@
                    jsr       MoveLeft
                    deca
                    bra       Loop@@
_1@@      ;--------------------------------------
          ; this is the number of bytes per block to calc offset.
          ; it lands us at the right block type.
          ;--------------------------------------
                    lda       #16
                    mul
          ;-------------------------------------- ; now we have the offset from the first block in D
                    std       temp
          ;-------------------------------------- ; get rotation offset. Result will be one of [0-3].
                    clrb
                    ldb       rot_offset
                    ldx       #4
                    idiv
          ;--------------------------------------
          ; now we know which rotation. Multiply by 4 to
          ; get number of bytes
          ;--------------------------------------
                    lda       #4
                    mul
                    addd      temp
                    ldx       #BLK_squareU+3
                    jsr       leax_dx
          ;-------------------------------------- ; now we have a random block in X
                    stx       block_ptr
          ;-------------------------------------- ; now shift the block back right
                    lda       shift_offset
_2@@                beq       Done@@
                    jsr       MoveRight
                    deca
                    bra       _2@@
Done@@              equ       :AnRTS

;*******************************************************************************

rst_van_blks        proc
                    ldx       #BLK_squareU
                    ldy       #BLK_van_squareU
                    ldb       #all_block_hght
Loop@@              lda       ,y
                    sta       ,x
                    inx
                    iny
                    decb
                    bne       Loop@@
                    rts

;*******************************************************************************

SaveState           proc
                    pshx
                    psha
                    ldx       block_ptr
                    stx       sav_block_ptr
                    lda       shift_offset
                    sta       sav_shft_offset
                    lda       rot_offset
                    sta       sav_rot_offset
                    pula
                    pulx
                    rts

;*******************************************************************************

RevertState         proc
                    pshx
                    pshd
                    ldb       block_height
                    ldx       block_ptr
                    aix       #all_block_hght
                    ldy       block_ptr
Loop@@              lda       ,x
                    sta       ,y
                    dex
                    dey
                    decb
                    bne       Loop@@
                    ldx       sav_block_ptr
                    stx       block_ptr
                    lda       sav_shft_offset
                    sta       shift_offset
                    lda       sav_rot_offset
                    sta       rot_offset
                    lda       shift_offset
_1@@                beq       Done@@
                    jsr       MoveRight
                    deca
                    bra       _1@@
Done@@              puld
                    pulx
                    rts

;*******************************************************************************

check_rcol          proc
                    pshx
                    psha
                    pshb
          ;--------------------------------------
          ; first, check if the rotation cut off the block.
          ; to do that, we move it left and compare it with
          ; vanilla. If it's the same, we're good and move on
          ; to stage collision check.
          ;--------------------------------------
                    lda       shift_offset
_1@@                beq       _2@@
                    jsr       MoveLeft
                    deca
                    bra       _1@@
_2@@                ldx       block_ptr
                    ldy       block_ptr
                    aiy       #all_block_hght
                    lda       block_height
_3@@                ldb       ,x
                    eorb      ,y
                    bne       CheckRCol@@
                    dex
                    dey
                    deca
                    bne       _3@@
          ;--------------------------------------
          ; at this point we know the block isn't cut off, so check the stage
          ;--------------------------------------
                    lda       shift_offset
_4@@                beq       _5@@
                    jsr       MoveRight
                    deca
                    bra       _4@@
_5@@                ldb       block_height
                    ldx       block_ptr
                    ldy       stage_block_ptr
                    aiy       #stage_beg
_6@@                lda       ,x
                    anda      ,y
                    bne       CheckRCol@@
                    dex
                    dey
                    decb
                    beq       Done@@
                    bra       _6@@
CheckRCol@@         jsr       set_collision
Done@@              pulb
                    pula
                    pulx
                    rts

;*******************************************************************************
; check for horizontal collision left

check_hcol_l        proc
                    pshx
                    pshy
                    pshd
                    ldb       block_height
                    ldx       block_ptr
Loop@@    ;--------------------------------------
          ; first make sure if any line of the block already occupies bit 7
          ;--------------------------------------
                    lda       ,x
                    anda      #$80
                    bne       _2@@
                    dex
                    decb
                    bne       Loop@@
          ;--------------------------------------
          ; now that we checked bit 7, check collision with the stage.
          ;--------------------------------------
                    ldb       block_height
                    ldx       block_ptr
                    ldy       stage_block_ptr
                    aiy       #stage_beg
_1@@                lda       ,x
                    lsla
                    anda      ,y
                    bne       _2@@
                    dex
                    dey
                    decb
                    beq       Done@@
                    bra       _1@@
_2@@                bsr       set_collision
Done@@              puld
                    puly
                    pulx
                    rts

;*******************************************************************************
; check for horizontal collision right

check_hcol_r        proc
                    pshx
                    pshy
                    pshd
                    ldb       block_height
                    ldx       block_ptr
Loop@@    ;--------------------------------------
          ; first make sure if any line of the block already occupies bit 0
          ;--------------------------------------
                    lda       ,x
                    anda      #$01
                    bne       CheckHCol@@
                    dex
                    decb
                    bne       Loop@@
          ;--------------------------------------
          ; now that we checked bit 7, check collision with the stage.
          ;--------------------------------------
                    ldb       block_height
                    ldx       block_ptr
                    ldy       stage_block_ptr
                    aiy       #stage_beg
_1@@                lda       ,x
                    lsra
                    anda      ,y
                    bne       CheckHCol@@
                    dex
                    dey
                    decb
                    beq       Done@@
                    bra       _1@@
CheckHCol@@         bsr       set_collision
Done@@              puld
                    puly
                    pulx
                    rts

;*******************************************************************************
; checks for vertical collisions

check_vcol          proc
                    psha
                    pshb
                    pshx
                    pshy
                    ldb       block_height
                    ldx       block_ptr           ; x will keep track of the block line
                    ldy       stage_block_ptr     ; y will keep track of the stage line
                    aiy       #stage_beg
Loop@@              lda       1,y                 ; look ahead one row
                    anda      ,x                  ; and it with the current line of the block
                    bne       _1@@                ; if we don't get 0, we have a collision
                    dex
                    dey
                    decb
                    bne       Loop@@
                    bra       Done@@
_1@@                bsr       set_collision
Done@@              puly
                    pulx
                    pulb
                    pula
                    rts

;*******************************************************************************

set_collision       proc
                    lda       #$FF
                    sta       collision
                    rts

;*******************************************************************************
; Score
;*******************************************************************************

Score_Inc           proc
                    pshd
                    ldd       Score
                    addd      #3
                    std       Score
                    puld
                    bra       ScoreBoard

;*******************************************************************************

Score_Inc_Bonus     proc
                    pshd
                    ldd       Score
                    addd      #10
                    std       Score
                    puld
                    bra       ScoreBoard

;*******************************************************************************

Score_Rst           proc
                    pshd
                    clrd
                    std       Score
                    puld
;                   bra       ScoreBoard

;*******************************************************************************

ScoreBoard          proc
                    pshd
                    pshx
                    pshy
                    ldd       #$1002              ; Set cursor to beginning of line
                    std       CHPointer
                    jsr       UpdateCursor
          ;-------------------------------------- ; Clears Line
                    lda       #Mwrite
                    jsr       LCD_Command
                    ldx       #$20
Loop@@              clra                          ; Clear line loop
                    jsr       LCD_Data
                    dex
                    bne       Loop@@

                    ldd       CHPointer           ; Set Cursor Back to beginning of line
                    jsr       UpdateCursor
          ;-------------------------------------- ; Hex to Decimal
                    ldd       Score

                    ldx       #10
                    idiv
                    ldy       #NumTbl
                    bsr       leay_dy
                    bsr       DrawScore

                    xgdx
                    ldx       #10
                    idiv
                    ldy       #NumTbl
                    bsr       leay_dy
                    bsr       DrawScore

                    xgdx
                    ldy       #NumTbl
                    bsr       leay_dy
                    bsr       DrawScore

                    puly
                    pulx
                    puld
                    rts

;*******************************************************************************

leax_dx             proc
                    pshd
                    xgdx
                    tsx
                    addd      ,x
                    tdx
                    puld
                    rts

;*******************************************************************************

leay_dy             proc
                    pshd
                    xgdy
                    tsy
                    addd      ,y
                    tdy
                    puld
                    rts

;*******************************************************************************

ldx_dy              proc
                    pshd
                    tyd
                    tsx
                    addd      ,x
                    tdx
                    puld
                    rts

;*******************************************************************************

DrawScore           proc
                    pshx
                    bsr       ldx_dy              ; ldx with top memory address of CG number
                    pshd
                    lda       #Mwrite
                    jsr       LCD_Command
                    ldy       #8
Loop@@              lda       1,x
                    inx
                    jsr       LCD_Data
                    dey
                    bne       Loop@@
                    puld
                    pulx
                    rts

;*******************************************************************************
; LCD
;*******************************************************************************

InitCurPointers     proc
                    pshd
                    ldd       #CursorInit
                    std       CPointer
                    addd      #3
                    std       CCPointer
                    ldd       #$0000
                    std       CSPointer
                    std       CHPointer
                    puld
                    rts

;*******************************************************************************
; Draws Shape based on values in memory (void)

DrawShape           proc
                    pshd
                    pshx
                    pshy
                    bsr       ClearShape          ; Clears Old shape
                    ldd       #CursorInit
                    addd      #1
                    addd      stage_block_ptr
                    std       CCPointer           ; Sets Cursor to correct location
                    addd      #$0400
                    std       CPointer

                    ldx       block_ptr           ; pointer to memory
Loop@@              ldd       CPointer
                    jsr       UpdateCursor
                    lda       #Mwrite             ; init memory write
                    jsr       LCD_Command
                    lda       1,x
                    dex
                    ldy       #8
_1@@                lsra
                    bcs       _2@@
                    jsr       Blank
                    bra       _3@@

_2@@                jsr       Square
_3@@                dey
                    bne       _1@@
                    ldd       CPointer
                    xgdx
                    dex
                    xgdx
                    std       CPointer
                    txd
                    addd      #4
                    cpd       block_ptr
                    bne       Loop@@
                    puly
                    pulx
                    puld
                    rts

;*******************************************************************************
; Clears old shape based on CCPointer which has old cursor position (void)

ClearShape          proc
                    pshd
                    pshx
                    pshy
                    ldd       CCPointer
                    jsr       UpdateCursor        ; Set Cursor to start of shape
                    ldy       #4
Loop@@              lda       #Mwrite
                    jsr       LCD_Command
                    clra
                    ldx       #$7F
_1@@                jsr       LCD_Data
                    dex
                    bne       _1@@
                    ldd       CCPointer
                    xgdx
                    dex
                    xgdx
                    std       CCPointer
                    jsr       UpdateCursor
                    dey
                    bne       Loop@@
                    puly
                    pulx
                    puld
                    rts

;*******************************************************************************

DrawStageBounds     proc
                    pshx
                    pshy
                    pshd
                    ldd       #CursorInit         ; Load Starting Cursor Point on LCD for stage
                    addd      #$1000
                    dex
                    xgdx
                    txd
                    jsr       UpdateCursor
                    lda       #Mwrite             ; Draw divide line between score board and stage
                    jsr       LCD_Command
                    lda       #%10111101
                    ldy       #$7F
_1@@                jsr       LCD_Data
                    dey
                    bne       _1@@
                    txd
                    addd      #17
                    jsr       UpdateCursor
                    lda       #Mwrite
                    jsr       LCD_Command
                    lda       #%01011101
                    ldy       #$7F
_2@@                jsr       LCD_Data
                    dey
                    bne       _2@@
                    lda       #$4C                ; Curser auto inc AP+1
                    jsr       LCD_Command
                    txd
                    addd      #$03C1
                    jsr       UpdateCursor
                    lda       #Mwrite
                    jsr       LCD_Command
                    ldy       #16
_3@@                lda       #$FF
                    jsr       LCD_Data
                    dey
                    bne       _3@@
                    txd
                    addd      #$0C21
                    jsr       UpdateCursor
                    lda       #Mwrite
                    jsr       LCD_Command
                    ldy       #16
_4@@                lda       #$FF
                    jsr       LCD_Data
                    dey
                    bne       _4@@
                    lda       #$4F                ; Curser auto inc AP+1
                    jsr       LCD_Command
                    puld
                    puly
                    pulx
                    rts

;*******************************************************************************

DrawStage           proc
                    pshx
                    pshy
                    pshd
                    ldd       #CursorInit         ; Load Starting Cursor Point on LCD for stage
                    addd      #$1401
                    std       CSPointer           ; Set CSPointer to top of stage
                    ldx       #stage_beg
Loop@@              ldd       CSPointer           ; Update LCD Cursor for drawing blocks on stage
                    jsr       UpdateCursor
                    lda       #Mwrite
                    jsr       LCD_Command
                    ldy       #8
                    lda       1,x
                    inx
_1@@                lsra
                    bcs       _2@@                ; Draw Each block on stage
                    jsr       Blank
                    bra       _3@@
_2@@                jsr       Square
_3@@                dey
                    bne       _1@@
                    ldd       CSPointer
                    xgdx
                    inx
                    xgdx
                    std       CSPointer
                    cpx       #stage_end
                    bne       Loop@@
                    puld
                    puly
                    pulx
                    rts

;*******************************************************************************
; GAME OVER

GameOver            proc
                    pshx
                    pshy
                    pshd
                    ldd       #CursorInit
                    addd      #$1008
                    tdx
                    jsr       UpdateCursor
                    ldy       #$7F
                    lda       #Mwrite
                    jsr       LCD_Command

_1@@                clra
                    jsr       LCD_Data
                    dey
                    bne       _1@@

                    txd
                    addd      #$0360
                    bsr       UpdateCursor

                    ldy       #GAME_OVER
                    lda       #Mwrite
                    jsr       LCD_Command

_2@@                lda       1,y
                    iny
                    cmpa      #$FF
                    beq       Done@@
                    jsr       LCD_Data
                    bra       _2@@

Done@@              puld
                    puly
                    pulx
                    rts

;*******************************************************************************

TetrisTitle         proc
                    pshx
                    pshy
                    pshd
                    ldd       #$1802
                    bsr       UpdateCursor

                    ldy       #TETRIS
                    lda       #Mwrite
                    jsr       LCD_Command

_1@@                lda       1,y
                    iny
                    cmpa      #$FF
                    beq       Done@@
                    jsr       LCD_Data
                    bra       _1@@

Done@@              puld
                    puly
                    pulx
                    rts

;*******************************************************************************

DrawPause           proc
                    pshx
                    pshy
                    pshd
                    clrd
                    bsr       UpdateCursor

                    ldy       #PAUSE
                    lda       #Mwrite
                    jsr       LCD_Command

Loop@@              lda       1,y
                    iny
                    cmpa      #$FF
                    beq       Done@@
                    jsr       LCD_Data
                    bra       Loop@@

Done@@              puld
                    puly
                    pulx
                    rts

;*******************************************************************************

ClearPause          proc
                    pshd
                    clrd
                    bsr       UpdateCursor
                    lda       #Mwrite
                    jsr       LCD_Command
                    bsr       Blank
                    puld
                    rts

;*******************************************************************************
; Requires D have cursor position (D)

UpdateCursor        proc
                    pshd
                    lda       #$46
                    jsr       LCD_Command
                    puld
                    psha
                    tba
                    jsr       LCD_Data
                    pula
                    jmp       LCD_Data

;*******************************************************************************
; Draws single square within shape (void) *WORKING

Square              proc
                    psha
                    pshx
                    ldx       #8
Loop@@              lda       #$FF
                    jsr       LCD_Data
                    dex
                    bne       Loop@@
                    pulx
                    pula
                    rts

;*******************************************************************************

Blank               proc
                    psha
                    pshx
                    ldx       #8
Loop@@              clra
                    jsr       LCD_Data
                    dex
                    bne       Loop@@
                    pulx
                    pula
                    rts

;*******************************************************************************

LCD_INIT            proc
                    psha
                    pshx

                    lda       #$FF
                    sta       DDRG
                    sta       DDRH

                    lda       #$1F
                    sta       PORTG               ; Init PORTG

                    bclr      PORTG,BIT_0         ; RESET LOW
          ;-------------------------------------- ; Need 3ms Delay
                    ldx       #$FFFF
_1@@                dex
                    bne       _1@@

                    bset      PORTG,BIT_0         ; Reset Complete PORTG

                    ldx       #$FFFF
_2@@                dex
                    bne       _2@@

                    lda       #$58                ; Turn off Display
                    jsr       LCD_Command
          ;-------------------------------------- ; Init Setup
                    lda       #$40
                    jsr       LCD_Command
                    lda       #$30
                    jsr       LCD_Data
                    lda       #$87                ; 8-2 frame AC Drive 7 - Char Width FX
                    jsr       LCD_Data
                    lda       #$07                ; Char Height FY
                    jsr       LCD_Data
                    lda       #$1F                ; 32 Diplay bites per line
                    jsr       LCD_Data
                    lda       #$23                ; Total addr range per line TC/R (C/R+4 H-Blanking)
                    jsr       LCD_Data
                    lda       #$7F                ; 128 diplay lines L/F
                    jsr       LCD_Data
                    lda       #$20                ; Low Bite APL (Virtual Screen)
                    jsr       LCD_Data
                    lda       #$00                ; High Bite APL (Virtual Screen)
                    bsr       LCD_Data
          ;-------------------------------------- ; Scroll Settings
                    lda       #$44                ; Set Scroll Command
                    bsr       LCD_Command
                    lda       #$00                ; Layer 1 Start Address
                    bsr       LCD_Data            ; Lower byte
                    lda       #$00
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    lda       #$00                ; Layer 2 Start Address
                    bsr       LCD_Data            ; Lower byte
                    lda       #$10
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
                    lda       #$00
                    bsr       LCD_Data            ; Layer 3 Start Address
                    lda       #$20
                    bsr       LCD_Data            ; High byte
                    lda       #$7F
                    bsr       LCD_Data            ; 128 lines
          ;-------------------------------------- ; Horizonal Scroll Set
                    lda       #$5A                ; Horizonal Scroll CMD
                    bsr       LCD_Command
                    lda       #$00                ; At Origin on X
                    bsr       LCD_Data
          ;-------------------------------------- ; Overlay Settings
                    lda       #$5B
                    bsr       LCD_Command         ; Overlay CMD
                    lda       #$1C
                    bsr       LCD_Data            ; 3 layers, Graphics,OR layers
          ;-------------------------------------- ; Set Cursor increment to increment for memory clear
                    lda       #$4C                ; Curser auto inc AP+1
                    bsr       LCD_Command
          ;-------------------------------------- ; Set Cursor location
                    lda       #$46
                    bsr       LCD_Command         ; Set Cursor
                    clra
                    bsr       LCD_Data            ; to 0000h
                    clra
                    bsr       LCD_Data
          ;-------------------------------------- ; Clear Memeory
                    clrx
                    lda       #$42
                    bsr       LCD_Command

_3@@                clra
                    bsr       LCD_Data
                    inx
                    cpx       #$3000
                    bne       _3@@
          ;-------------------------------------- ; Set Cursor increment to increment for program
                    lda       #$4F                ; Curser auto inc AP+1
                    bsr       LCD_Command
          ;-------------------------------------- ; Turn on Display
                    lda       #$59
                    bsr       LCD_Command         ; Display On
                    lda       #%00010100          ; Layer 1,2 on layer 3,4, curser off
                    bsr       LCD_Data
          ;-------------------------------------- ; Set CGRAM
;                   lda       #$5C
;                   jsr       LCD_Command
;                   clra
;                   jsr       LCD_Data
;                   lda       #$04
;                   jsr       LCD_Data
                    pulx
                    pula
                    rts

;*******************************************************************************
; PORTG
; bit0 - /Reset
; bit1 - /Read
; bit2 - /Write
; bit3 - /CS
; bit4 - A0

LCD_Command         proc
                    pshb
                    bset      PORTG,BIT_4         ; Set A0
                    sta       PORTH               ; Write Command
                    bset      PORTG,BIT_1         ; Read disabled
                    bclr      PORTG,BIT_3         ; CS enabled
                    bclr      PORTG,BIT_2         ; Write enabled
                    ldb       #$FF
                    stb       PORTG               ; Restore PG
                    pulb
                    rts

;*******************************************************************************

LCD_Data            proc
                    pshb
                    bclr      PORTG,BIT_4         ; Clear A0
                    sta       PORTH               ; Write Data
                    bset      PORTG,BIT_1         ; Read disabled
                    bclr      PORTG,BIT_3         ; CS enabled
                    bclr      PORTG,BIT_2         ; Write enabled
                    ldb       #$FF
                    stb       PORTG               ; Restore PG
                    pulb
                    rts

;*******************************************************************************
; ISRs
;*******************************************************************************

;*******************************************************************************
; this ISR moves the block down one space periodically

ISR_Timer1          proc
                    pshd
                    pshx
                    pshy
                    pshcc
                    jsr       move_down           ;******************Currently does not inc stage_block_ptr
                    jsr       DrawShape
                    lda       TFLG1
                    anda      #$02                ; Reset Flag
                    sta       TFLG1
                    pulcc
                    puly
                    pulx
                    puld
                    rti

;*******************************************************************************

ISR_Timer2          proc
                    pshd
                    pshx
                    pshy
                    pshcc
                    jsr       DrawShape
                    ldd       TCNT
                    addd      #$0FFF
                    std       TC2
                    lda       TFLG1
                    anda      #$04
                    sta       TFLG1
                    pulcc
                    puly
                    pulx
                    puld
                    rti

;*******************************************************************************
; Blocks
;*******************************************************************************

BLK_squareU         fcb       $C0,$C0,0,0
BLK_squareL         fcb       $C0,$C0,0,0
BLK_squareD         fcb       $C0,$C0,0,0
BLK_squareR         fcb       $C0,$C0,0,0
BLK_teeU            fcb       $40,$E0,0,0
BLK_teeL            fcb       $40,$C0,$40,0
BLK_teeD            fcb       $E0,$40,0,0
BLK_teeR            fcb       $80,$C0,$80,0
BLK_longU           fcb       $F0,0,0,0
BLK_longL           fcb       $80,$80,$80,$80
BLK_longD           fcb       $F0,0,0,0
BLK_longR           fcb       $80,$80,$80,$80
BLK_ZU              fcb       $C0,$60,0,0
BLK_ZL              fcb       $40,$C0,$80,0
BLK_ZD              fcb       $C0,$60,0,0
BLK_ZR              fcb       $40,$C0,$80,0
BLK_ZiU             fcb       $60,$C0,0,0
BLK_ZiL             fcb       $80,$C0,$40,0
BLK_ZiD             fcb       $60,$C0,0,0
BLK_ZiR             fcb       $80,$C0,$40,0
BLK_LU              fcb       $E0,$80,0,0
BLK_LL              fcb       $80,$80,$C0,0
BLK_LD              fcb       $20,$E0,0,0
BLK_LR              fcb       $C0,$40,$40,0
BLK_LiU             fcb       $E0,$20,0,0
BLK_LiL             fcb       $C0,$80,$80,0
BLK_LiD             fcb       $80,$E0,0,0
BLK_LiR             fcb       $40,$40,$C0,0
          ;-------------------------------------- ; vanilla blocks. we never touch those.
BLK_van_squareU     fcb       $C0,$C0,0,0
BLK_van_squareL     fcb       $C0,$C0,0,0
BLK_van_squareD     fcb       $C0,$C0,0,0
BLK_van_squareR     fcb       $C0,$C0,0,0
BLK_van_teeU        fcb       $40,$E0,0,0
BLK_van_teeL        fcb       $40,$C0,$40,0
BLK_van_teeD        fcb       $E0,$40,0,0
BLK_van_teeR        fcb       $80,$C0,$80,0
BLK_van_longU       fcb       $F0,0,0,0
BLK_van_longL       fcb       $80,$80,$80,$80
BLK_van_longD       fcb       $F0,0,0,0
BLK_van_longR       fcb       $80,$80,$80,$80
BLK_van_ZU          fcb       $C0,$60,0,0
BLK_van_ZL          fcb       $40,$C0,$80,0
BLK_van_ZD          fcb       $C0,$60,0,0
BLK_van_ZR          fcb       $40,$C0,$80,0
BLK_van_ZiU         fcb       $60,$C0,0,0
BLK_van_ZiL         fcb       $80,$C0,$40,0
BLK_van_ZiD         fcb       $60,$C0,0,0
BLK_van_ZiR         fcb       $80,$C0,$40,0
BLK_van_LU          fcb       $E0,$80,0,0
BLK_van_LL          fcb       $80,$80,$C0,0
BLK_van_LD          fcb       $20,$E0,0,0
BLK_van_LR          fcb       $C0,$40,$40,0
BLK_van_LiU         fcb       $E0,$20,0,0
BLK_van_LiL         fcb       $C0,$80,$80,0
BLK_van_LiD         fcb       $80,$E0,0,0
BLK_van_LiR         fcb       $40,$40,$C0,0

;*******************************************************************************
; LCD CHAR TABLE
;*******************************************************************************

Zero                fcb       $00
                    fcb       $00
                    fcb       $7C                 ; 01111100
                    fcb       $A2                 ; 10100010
                    fcb       $92                 ; 10010010
                    fcb       $8A                 ; 10001010
                    fcb       $7C                 ; 01111100
                    fcb       $00

One                 fcb       $00
                    fcb       $00
                    fcb       $00
                    fcb       $01
                    fcb       $FE
                    fcb       $42
                    fcb       $00
                    fcb       $00

Two                 fcb       $00
                    fcb       $00
                    fcb       $42
                    fcb       $A2
                    fcb       $92
                    fcb       $8A
                    fcb       $46
                    fcb       $00

Three               fcb       $00
                    fcb       $00
                    fcb       $8C
                    fcb       $D2
                    fcb       $A2
                    fcb       $82
                    fcb       $84
                    fcb       $00

Four                fcb       $00
                    fcb       $00
                    fcb       $08
                    fcb       $FE
                    fcb       $48
                    fcb       $28
                    fcb       $18
                    fcb       $00

Five                fcb       $00
                    fcb       $00
                    fcb       $9C
                    fcb       $A2
                    fcb       $A2
                    fcb       $A2
                    fcb       $E4
                    fcb       $00

Six                 fcb       $00
                    fcb       $00
                    fcb       $0C
                    fcb       $92
                    fcb       $92
                    fcb       $52
                    fcb       $3C
                    fcb       $00

Seven               fcb       $00
                    fcb       $00
                    fcb       $C0
                    fcb       $A0
                    fcb       $90
                    fcb       $8E
                    fcb       $80
                    fcb       $00

Eight               fcb       $00
                    fcb       $00
                    fcb       $6C
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $6C
                    fcb       $00

Nine                fcb       $00
                    fcb       $00
                    fcb       $78
                    fcb       $94
                    fcb       $92
                    fcb       $92
                    fcb       $60
                    fcb       $00

TETRIS              fcb       $00                 ; S
                    fcb       $00
                    fcb       $4C
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $64
                    fcb       $00

                    fcb       $00                 ; I
                    fcb       $00
                    fcb       $00
                    fcb       $82
                    fcb       $fe
                    fcb       $82
                    fcb       $00
                    fcb       $00

                    fcb       $00                 ; R
                    fcb       $00
                    fcb       $62
                    fcb       $94
                    fcb       $98
                    fcb       $90
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; T
                    fcb       $00
                    fcb       $80
                    fcb       $80
                    fcb       $fe
                    fcb       $80
                    fcb       $80
                    fcb       $00

                    fcb       $00                 ; E
                    fcb       $00
                    fcb       $82
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; T
                    fcb       $00
                    fcb       $80
                    fcb       $80
                    fcb       $fe
                    fcb       $80
                    fcb       $80
                    fcb       $00

                    fcb       $FF                 ; END

GAME_OVER           fcb       $00                 ; R
                    fcb       $00
                    fcb       $62
                    fcb       $94
                    fcb       $98
                    fcb       $90
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; E
                    fcb       $00
                    fcb       $82
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; V
                    fcb       $00
                    fcb       $f8
                    fcb       $04
                    fcb       $02
                    fcb       $04
                    fcb       $f8
                    fcb       $00

                    fcb       $00                 ; O
                    fcb       $00
                    fcb       $7C
                    fcb       $82
                    fcb       $82
                    fcb       $82
                    fcb       $7C
                    fcb       $00

                    fcb       $00                 ; Space
                    fcb       $00
                    fcb       $00
                    fcb       $00
                    fcb       $00
                    fcb       $00
                    fcb       $00
                    fcb       $00

                    fcb       $00                 ; E
                    fcb       $00
                    fcb       $82
                    fcb       $92
                    fcb       $92
                    fcb       $92
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; M
                    fcb       $00
                    fcb       $FE
                    fcb       $40
                    fcb       $30
                    fcb       $40
                    fcb       $fe
                    fcb       $00

                    fcb       $00                 ; A
                    fcb       $00
                    fcb       $7e
                    fcb       $88
                    fcb       $88
                    fcb       $88
                    fcb       $7e
                    fcb       $00

                    fcb       $00                 ; G
                    fcb       $00
                    fcb       $5e
                    fcb       $92
                    fcb       $92
                    fcb       $82
                    fcb       $7c
                    fcb       $00

                    fcb       $FF                 ; END

PAUSE               fcb       $00                 ; P
                    fcb       $00
                    fcb       $60
                    fcb       $90
                    fcb       $90
                    fcb       $90
                    fcb       $FE
                    fcb       $00

                    fcb       $FF                 ; END

                    org       $2500
NumTbl              fdb       Zero,One,Two,Three,Four,Five,Six,Seven,Eight,Nine

;*******************************************************************************
                    #VECTORS
;*******************************************************************************

                    org       $62c
                    fdb       ISR_Timer1

                    org       $62a
                    fdb       ISR_Timer2
