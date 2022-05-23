; OUT ports
#define PORT_CONTROL $E ; 1110 - bit 0 is low
#define PORT_LCD $D     ; 1101 - bit 1 is low

; IN ports
#define PORT_BUTTONS $E ; 1110 - bit 0 is low

; Bit flags in LCDCONTROL port
#define LCD_REG_COMMAND $4

; LCD commands
#define LCD_COMMAND_INTERFACE8 $3C  ; 8-bit interface, 2-line display, 5x10 font
#define LCD_COMMAND_INTERFACE4 $2C  ; 4-bit interface, 2-line display, 5x10 font

; LCD timing constants
#define LCD_CLEAR_HOME_DELAY_US 1520
#define LCD_SINGLE_COMMAND_DELAY_US 37
#define CPU_CLOCKS_PER_US 2.4576

; memory locations
#define LCD_DELAY_1 $004
#define LCD_DELAY_2 $005

#define MUL_CARRY $006
#define MUL_TMP $007
; two nibbles
#define MUL_RES $008
#define LCD_BUFFER_INDEX $00A
#define LCD_CONTROL_STATE $00B

#define RETURN_ADDRESS $00C
#define RETURN_ADDRESS_1 $00D

#define NEW_BUTTON_STATE $00E
#define INPUT_BUF_INDEX $00F

#define INPUT_BUF_1 $010
#define INPUT_BUF_2 $014
#define NUM_BUF_1 $018
#define NUM_BUF_2 $01C

#define LCD_BUFFER $020
#define SUB_BUF_1 $030
#define SUB_BUF_2 $034
#define SUB_CARRY $041
#define DEBOUNCE_COUNTER_0 $042
#define DEBOUNCE_COUNTER_1 $043
#define DEBOUNCE_COUNTER_2 $044
#define TMP $048

; buttons
#define DEBOUNCE_TIME_0 $F
#define DEBOUNCE_TIME_1 $F
#define DEBOUNCE_TIME_2 $F
#define BUTTON_LEFT $1
#define BUTTON_NOT_LEFT $E
#define BUTTON_RIGHT $2
#define BUTTON_NOT_RIGHT $D
#define BUTTON_DOWN $4
#define BUTTON_NOT_DOWN $B
#define BUTTON_UP $8
#define BUTTON_NOT_UP $7

init_lcd:
; To initialize the LCD from an unknown state, we must first set it to 8-bit mode three times. Then it can be set to 4-bit mode.

    ; prepare to send an LCD command
    lit #LCD_REG_COMMAND
    st LCD_CONTROL_STATE

    ; the command is INTERFACE8
    lit #<LCD_COMMAND_INTERFACE8
    st LCD_BUFFER
    ; zero more nibbles to read from the buffer
    lit #0
    calli lcd_write_buffer
    call lcd_long_delay

    ; the command is INTERFACE8
    lit #<LCD_COMMAND_INTERFACE8
    st LCD_BUFFER
    lit #0
    calli lcd_write_buffer
    call lcd_long_delay

    ; the command is INTERFACE8
    lit #<LCD_COMMAND_INTERFACE8
    st LCD_BUFFER
    ; zero more nibbles to read from the buffer
    lit #0
    calli lcd_write_buffer

    ; the command is INTERFACE4
    lit #<LCD_COMMAND_INTERFACE4
    st LCD_BUFFER
    ; zero more nibbles to read from the buffer
    lit #0
    calli lcd_write_buffer

    ; The LCD is now in 4-bit mode, and we can send byte-wide commands as a pair of nibble, high nibble first.
start:
    lit #0
    st INPUT_BUF_INDEX

    lit #9
    st INPUT_BUF_1
    lit #8
    st INPUT_BUF_1+1
    lit #7
    st INPUT_BUF_1+2
    lit #6
    st INPUT_BUF_1+3

main_loop:
    call wait_for_button

check_right_pressed:
    ; is the right button currently pressed?
    lit #BUTTON_NOT_RIGHT
    norm NEW_BUTTON_STATE
    jz check_left_pressed
    ld INPUT_BUF_INDEX
    cmpi #3
    jz end_checks
    addi #1
    st INPUT_BUF_INDEX
    jmp end_checks

check_left_pressed:
    lit #BUTTON_NOT_LEFT
    norm NEW_BUTTON_STATE
    jz check_down_pressed
    ld INPUT_BUF_INDEX
    jz end_checks
    addi #-1
    st INPUT_BUF_INDEX
    jmp end_checks

check_down_pressed:
    lit #BUTTON_NOT_DOWN
    norm NEW_BUTTON_STATE
    jz check_up_pressed
    ld INPUT_BUF_INDEX
    ldi INPUT_BUF_1 3
    jz end_checks
    addi #-1
    st TMP
    ld INPUT_BUF_INDEX
    sti INPUT_BUF_1 TMP 3
    jmp end_checks

check_up_pressed:
    lit #BUTTON_NOT_UP
    norm NEW_BUTTON_STATE
    jz end_checks
    ld INPUT_BUF_INDEX
    ldi INPUT_BUF_1 3
    cmpi #9
    jc end_checks   ; >= 9
    addi #1
    st TMP
    ld INPUT_BUF_INDEX
    sti INPUT_BUF_1 TMP 3

end_checks:
    call convert_input
    jmp main_loop

    ; clear input buf
    lit #0
    st INPUT_BUF_1
    st INPUT_BUF_1+1
    st INPUT_BUF_1+2
    st INPUT_BUF_1+3

    ; put number for subtraction
    ld NUM_BUF_1
    st SUB_BUF_1
    ld NUM_BUF_1+1
    st SUB_BUF_1+1
    ld NUM_BUF_1+2
    st SUB_BUF_1+2
    ld NUM_BUF_1+3
    st SUB_BUF_1+3

    call convert_output

    jmp halt

convert_output:
    ; 1000
    lit #$8
    st SUB_BUF_2
    lit #$E
    st SUB_BUF_2+1
    lit #$3
    st SUB_BUF_2+2
    lit #$0
    st SUB_BUF_2+3

-   addi #0 ; NOP
    call cmp_buf
    ld SUB_CARRY
    jnz +
    call sub_buf
    ld INPUT_BUF_1
    addi #1
    st INPUT_BUF_1
    jmp -
    ; 100
+   lit #$4
    st SUB_BUF_2
    lit #$6
    st SUB_BUF_2+1
    lit #$0
    st SUB_BUF_2+2
-   addi #0 ; NOP
    call cmp_buf
    ld SUB_CARRY
    jnz +
    call sub_buf
    ld INPUT_BUF_1+1
    addi #1
    st INPUT_BUF_1+1
    jmp -
    ; 10
+   lit #$A
    st SUB_BUF_2
    lit #$0
    st SUB_BUF_2+1
-   addi #0 ; NOP
    call cmp_buf
    ld SUB_CARRY
    jnz +
    call sub_buf
    ld INPUT_BUF_1+2
    addi #1
    st INPUT_BUF_1+2
    jmp -
    ; 1
+   ld SUB_BUF_1
    st INPUT_BUF_1+3
    ret

cmp_buf:
    ld SUB_BUF_2+3
    cmpm SUB_BUF_1+3
    jnc ++
    jnz +
    ld SUB_BUF_2+2
    cmpm SUB_BUF_1+2
    jnc ++
    jnz +
    ld SUB_BUF_2+1
    cmpm SUB_BUF_1+1
    jnc ++
    jnz +
    ld SUB_BUF_2
    cmpm SUB_BUF_1
    jnc ++
    jnz +
++  lit #0
    st SUB_CARRY
    jmp +++
+   lit #1
    st SUB_CARRY
+++ ret

sub_buf:
    lit #1
    st SUB_CARRY
    ld SUB_BUF_2
    jz +
    nori #0 ; not
    addi #1 ; negative
    addm SUB_BUF_1  ; buf_1 - buf_2
    st SUB_BUF_1
    jc +
    ld SUB_BUF_1+1
    addi #-1
    st SUB_BUF_1+1
    jc +
    ld SUB_BUF_1+2
    addi #-1
    st SUB_BUF_1+2
    jc +
    ld SUB_BUF_1+3
    addi #-1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+1
    jz +
    nori #0 ; not
    addi #1 ; negative
    addm SUB_BUF_1+1
    st SUB_BUF_1+1
    jc +
    ld SUB_BUF_1+2
    addi #-1
    st SUB_BUF_1+2
    jc +
    ld SUB_BUF_1+3
    addi #-1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+2
    jz +
    nori #0 ; not
    addi #1 ; negative
    addm SUB_BUF_1+2
    st SUB_BUF_1+2
    jc +
    ld SUB_BUF_1+3
    addi #-1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+3
    jz +
    nori #0 ; not
    addi #1 ; negative
    addm SUB_BUF_1+3
    st SUB_BUF_1+3
    jc +
    lit #0
    st SUB_CARRY
+   ret


convert_input:
    ; input[0]
    ld INPUT_BUF_1
    ; input[0] * 10
    calli mul10
    ; store result
    ld MUL_RES+1
    st NUM_BUF_1+1
    ; input[0] * 10 + input[1]
    ld MUL_RES
    addm INPUT_BUF_1+1
    ; store result
    st NUM_BUF_1
    jnc +
    ld NUM_BUF_1+1
    addi #1
    st NUM_BUF_1+1
+   ld NUM_BUF_1+1
    ; <((input[0] * 10 + input[1]) * 10)
    calli mul10
    ld MUL_RES
    st NUM_BUF_1+1
    ld MUL_RES+1
    st NUM_BUF_1+2
    ld NUM_BUF_1
    ; >((input[0] * 10 + input[1]) * 10)
    calli mul10
    ld MUL_RES+1
    addm NUM_BUF_1+1
    st NUM_BUF_1+1
    jnc +
    ld NUM_BUF_1+2
    addi #1
    st NUM_BUF_1+2
+   ld MUL_RES
    ; (input[0] * 10 + input[1]) * 10 + input[2]
    addm INPUT_BUF_1+2
    st NUM_BUF_1
    jnc +
    ld NUM_BUF_1+1
    addi #1
    st NUM_BUF_1+1
    ; ((input[0] * 10 + input[1]) * 10 + input[2]) * 10
+   ld NUM_BUF_1+2
    calli mul10
    ld MUL_RES+1
    st NUM_BUF_1+3
    ld MUL_RES
    st NUM_BUF_1+2
    ld NUM_BUF_1+1
    calli mul10
    ld MUL_RES+1
    addm NUM_BUF_1+2
    st NUM_BUF_1+2
    jnc +
    ld NUM_BUF_1+3
    addi #1
    st NUM_BUF_1+3
+   ld MUL_RES
    st NUM_BUF_1+1
    ld NUM_BUF_1
    calli mul10
    ld MUL_RES+1
    addm NUM_BUF_1+1
    st NUM_BUF_1+1
    jnc +
    ld NUM_BUF_1+2
    addi #1
    st NUM_BUF_1+2
    jnc +
    ld NUM_BUF_1+3
    addi #1
    st NUM_BUF_1+3
+   ld MUL_RES
    st NUM_BUF_1
    ; ((input[0] * 10 + input[1]) * 10 + input[2]) * 10 + input[3]
    ld INPUT_BUF_1+3
    addm NUM_BUF_1
    st NUM_BUF_1
    jnc +
    ld NUM_BUF_1+1
    addi #1
    st NUM_BUF_1+1
    jnc +
    ld NUM_BUF_1+2
    addi #1
    st NUM_BUF_1+2
    jnc +
    ld NUM_BUF_1+3
    addi #1
    st NUM_BUF_1+3
+   ret

mul10:
    ; the value to mul is in accumulator
    st MUL_TMP

    lit #0
    st MUL_RES
    st MUL_RES+1

    ; 2x
    ld MUL_TMP
    addm MUL_TMP
    st MUL_RES
    jnc +
    lit #1
    st MUL_RES+1
    ; 4x
+   ld MUL_RES
    addm MUL_RES
    st MUL_RES
    jnc +
    lit #1
    st MUL_CARRY
+   ld MUL_RES+1
    addm MUL_RES+1
    st MUL_RES+1
    ld MUL_CARRY
    jz +
    ld MUL_RES+1
    addi #1
    st MUL_RES+1
    lit #0
    st MUL_CARRY
    ; 4x + x
+   ld MUL_RES
    addm MUL_TMP
    st MUL_RES
    jnc +
    ld MUL_RES+1
    addi #1
    st MUL_RES+1
    ; (4x + x) * 2
+   ld MUL_RES
    addm MUL_RES
    st MUL_RES
    jnc +
    lit #1
    st MUL_CARRY
+   ld MUL_RES+1
    addm MUL_RES+1
    st MUL_RES+1
    ld MUL_CARRY
    jz +
    ld MUL_RES+1
    addi #1
    st MUL_RES+1
    lit #0
    st MUL_CARRY
+   ret


halt:
    jmp halt

; ===== KEYS =====
wait_for_button:
-   in #PORT_BUTTONS
    cmpi #$F
    jz -

    st NEW_BUTTON_STATE

    ; init debounce
    lit #DEBOUNCE_TIME_0
    st DEBOUNCE_COUNTER_0
    lit #DEBOUNCE_TIME_1
    st DEBOUNCE_COUNTER_1
    lit #DEBOUNCE_TIME_2
    st DEBOUNCE_COUNTER_2

debounce:
    ; each loop is at least 7 instructions, 14 clocks
    in #PORT_BUTTONS
    cmpm NEW_BUTTON_STATE
    jnz wait_for_button
    ld DEBOUNCE_COUNTER_0
    addi #-1
    st DEBOUNCE_COUNTER_0
    jc debounce
    ld DEBOUNCE_COUNTER_1
    addi #-1
    st DEBOUNCE_COUNTER_1
    jc debounce
    ld DEBOUNCE_COUNTER_2
    addi #-1
    st DEBOUNCE_COUNTER_2
    jc debounce

    ; wait for all buttons to be up
-   in #PORT_BUTTONS
    cmpi #$F
    jnz -

    ret

; ===== LCD ===== 

; use LCD_BUFFER_INDEX to get the next nibble from LCD_BUFFER, and put it in LCD_NIBBLE
lcd_write_buffer:
    ; value for LCD_BUFFER_INDEX is in the accumulator
    st LCD_BUFFER_INDEX
    ldi LCD_BUFFER

    out #PORT_LCD
    ld LCD_CONTROL_STATE
    out #PORT_CONTROL ; setup RS
    _ori #1 ; set bit 1 (E)
    out #PORT_CONTROL
    _andi #$E ; clear bit 1 (E)
    out #PORT_CONTROL

    ; wait at least LCD_SINGLE_COMMAND_DELAY_US us for the LCD
    ; each loop iteration is 6 clocks
    ; initial count = round_up(LCD_SINGLE_COMMAND_DELAY_US * CPU_CLOCKS_PER_US / 6) - 1
    ; Initial count of 15 = 16 iterations = 96 clocks = 39 us @ 2.4576 MHz.
    lit #15
-   addi #0 ; NOP
    addi #-1
    jc -    ; carry will be clear when result goes negative

    ; decrement the buffer index
    ld LCD_BUFFER_INDEX
    addi #-1
    jc lcd_write_buffer

    ret

    ; unknown return address
    jmp halt

lcd_long_delay:
    ; wait at least LCD_CLEAR_HOME_DELAY_US us for the LCD
    ; each loop iteration is 6 clocks
    ; initial count = round_up(LCD_CLEAR_HOME_DELAY_US * CPU_CLOCKS_PER_US / 6) - 1
    ; Initial count of 656 = $290 hex = 657 iterations = 3942 clocks = 1604 us @ 2.4576 MHz
    lit #2
    st LCD_DELAY_2
    lit #9
    st LCD_DELAY_1
    lit #0
-   addi #0 ; NOP
    addi #-1
    jc -    ; carry will be clear when result goes negative
    ld LCD_DELAY_1
    addi #-1
    st LCD_DELAY_1
    jnc +
    lit #$F
    jmp -
+   ld LCD_DELAY_2
    addi #-1
    st LCD_DELAY_2
    jnc +
    lit #$F
    jmp -
+   ; end of delay loop

    ret

    ; unknown return address
    jmp halt
