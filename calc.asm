; OUT ports
#define PORT_CONTROL $E ; 1110 - bit 0 is low
#define PORT_LCD $D     ; 1101 - bit 1 is low

; IN ports
#define PORT_BUTTONS $E ; 1110 - bit 0 is low

; Bit flags in LCDCONTROL port
#define LCD_REG_COMMAND $4
#define LCD_REG_DATA $6

; LCD commands
#define LCD_COMMAND_INTERFACE8 $3C  ; 8-bit interface, 2-line display, 5x10 font
#define LCD_COMMAND_INTERFACE4 $2C  ; 4-bit interface, 2-line display, 5x10 font
#define LCD_COMMAND_DISPLAY $0F     ; display on, cursor on, blinking cursor on
#define LCD_COMMAND_CLEAR $01       ; clear display, home cursor
#define LCD_COMMAND_CURSOR_POS_LINE_1 $80 ; OR the desired cursor position with $80 to create a cursor position command. Line 2 begins at pos 64
#define LCD_COMMAND_CURSOR_POS_LINE_2 $C0  
#define LCD_COMMAND_CURSOR_SHIFT_LEFT $10
#define LCD_COMMAND_CURSOR_SHIFT_RIGHT $14

; digits operations
#define DIGIT_OP_INC $1
#define DIGIT_OP_DEC $2

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
#define RESULT_CARRY $042
#define DEBOUNCE_COUNTER_0 $043
#define DEBOUNCE_COUNTER_1 $044
#define DEBOUNCE_COUNTER_2 $045

#define DIGIT_OP_FLAG $046
#define OP_IDX $047

#define TMP $048
#define TMP_1 $049

#define DIGITS_BUF  $050
#define NUMBER_BUF  $054
#define OUTPUT_BUF  $058    ; 5 nibbles

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

start:
    call init_lcd

    ; prepare to send an LCD command
    lit #LCD_REG_COMMAND
    st LCD_CONTROL_STATE

    writebuf LCD_BUFFER LCD_COMMAND_INTERFACE4,LCD_COMMAND_DISPLAY,LCD_COMMAND_CLEAR

    lit #5
    calli lcd_write_buffer
    call lcd_long_delay

    lit #0
    st INPUT_BUF_INDEX

    lit #0
    st INPUT_BUF_1
    lit #0
    st INPUT_BUF_1+1
    lit #0
    st INPUT_BUF_1+2
    lit #6
    st INPUT_BUF_1+3

    lit #0
    st INPUT_BUF_2
    st INPUT_BUF_2+1
    st INPUT_BUF_2+2
    lit #9
    st INPUT_BUF_2+3

    ; prepare to send an LCD command
    lit #LCD_REG_COMMAND
    st LCD_CONTROL_STATE

    writebuf LCD_BUFFER LCD_COMMAND_CURSOR_POS_LINE_1
    lit #1
    calli lcd_write_buffer

    ; prepare to send LCD character data
    lit #LCD_REG_DATA
    st LCD_CONTROL_STATE

    ; fill LCD buf with digits
    lit #3
    st LCD_BUFFER+7
    st LCD_BUFFER+5
    st LCD_BUFFER+3
    st LCD_BUFFER+1

    ld INPUT_BUF_1
    st LCD_BUFFER+6
    ld INPUT_BUF_1+1
    st LCD_BUFFER+4
    ld INPUT_BUF_1+2
    st LCD_BUFFER+2
    ld INPUT_BUF_1+3
    st LCD_BUFFER

    lit #7
    calli lcd_write_buffer

    writebuf LCD_BUFFER "+"
    lit #1
    calli lcd_write_buffer

    lit #3
    st LCD_BUFFER+1

    ld INPUT_BUF_2
    st LCD_BUFFER+6
    ld INPUT_BUF_2+1
    st LCD_BUFFER+4
    ld INPUT_BUF_2+2
    st LCD_BUFFER+2
    ld INPUT_BUF_2+3
    st LCD_BUFFER

    lit #7
    calli lcd_write_buffer

main_loop:

    call wait_for_button

check_right_pressed:
    ; is the right button currently pressed?
    lit #BUTTON_NOT_RIGHT
    norm NEW_BUTTON_STATE
    jz check_left_pressed
    ld INPUT_BUF_INDEX
    cmpi #8
    jz do_the_calc
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
    lit #DIGIT_OP_DEC
    st DIGIT_OP_FLAG
    jmp change_number

check_up_pressed:
    lit #BUTTON_NOT_UP
    norm NEW_BUTTON_STATE
    jz end_checks
    lit #DIGIT_OP_INC
    st DIGIT_OP_FLAG
    jmp change_number

change_number:
    ld INPUT_BUF_INDEX
    calli cursor_set_pos_line1
    lit #LCD_REG_DATA
    st LCD_CONTROL_STATE

    ld INPUT_BUF_INDEX
    cmpi #4             ; idx < 4 => first buffer
    jnc ++
    jz change_op       ; idx == 4 => operation
    addi #-5            ; else: idx > 4 => second buffer
    ldi INPUT_BUF_2 3
    jmp +++
++  ld INPUT_BUF_INDEX
    ldi INPUT_BUF_1 3
+++ st TMP_1
    ld DIGIT_OP_FLAG
    cmpi #DIGIT_OP_INC
    jz to_inc
    cmpi #DIGIT_OP_DEC
    jz to_dec
    ; invalid op
    jmp halt

to_inc:
    ld TMP_1
    cmpi #9
    jc +
    addi #1
    jmp ++
+   lit #0
++  st TMP_1
    jmp +++

to_dec:
    ld TMP_1
    jz +
    addi #-1
    jmp ++
+   lit #9
++  st TMP_1

    ; print digit on the screen
+++ ld TMP_1
    st LCD_BUFFER
    lit #3
    st LCD_BUFFER+1
    lit #1
    calli lcd_write_buffer

    ld INPUT_BUF_INDEX
    cmpi #4                 ; idx < 4 => first buffer
    jnc ++
    jz halt           ; idx == 4 => operation; should not end up here; halt
    addi #-5                ; else: idx > 4 => second buffer
    sti INPUT_BUF_2 TMP_1 3
    jmp end_checks
++  ld INPUT_BUF_INDEX
    sti INPUT_BUF_1 TMP_1 3
    jmp end_checks

change_op:
    ld DIGIT_OP_FLAG
    cmpi #DIGIT_OP_INC
    jz op_inc
    cmpi #DIGIT_OP_DEC
    jz op_dec
    jmp halt

op_inc:
    ld OP_IDX
    cmpi #2
    jz +
    addi #1
    jmp ++
+   lit #0
++  st OP_IDX
    jmp display_op

op_dec:
    ld OP_IDX
    jz +
    addi #-1
    jmp ++
+   lit #2
++  st OP_IDX

display_op:
    ld OP_IDX
    jnz +
    writebuf LCD_BUFFER "+" ; 0: PLUS
    jmp ++
+   cmpi #1
    jnz +
    writebuf LCD_BUFFER "-" ; 1: MINUS
    jmp ++
+   cmpi #2
    jnz +
    writebuf LCD_BUFFER "*" ; 2: MULTIPLY
    jmp ++
+   jmp halt                ; invalid operation
++  lit #1
    calli lcd_write_buffer
    jmp end_checks

do_the_calc:
    ld INPUT_BUF_1
    st DIGITS_BUF
    ld INPUT_BUF_1+1
    st DIGITS_BUF+1
    ld INPUT_BUF_1+2
    st DIGITS_BUF+2
    ld INPUT_BUF_1+3
    st DIGITS_BUF+3

    call convert_input

    ld NUMBER_BUF
    st SUB_BUF_1
    ld NUMBER_BUF+1
    st SUB_BUF_1+1
    ld NUMBER_BUF+2
    st SUB_BUF_1+2
    ld NUMBER_BUF+3
    st SUB_BUF_1+3

    ld INPUT_BUF_2
    st DIGITS_BUF
    ld INPUT_BUF_2+1
    st DIGITS_BUF+1
    ld INPUT_BUF_2+2
    st DIGITS_BUF+2
    ld INPUT_BUF_2+3
    st DIGITS_BUF+3

    call convert_input

    ld NUMBER_BUF
    st SUB_BUF_2
    ld NUMBER_BUF+1
    st SUB_BUF_2+1
    ld NUMBER_BUF+2
    st SUB_BUF_2+2
    ld NUMBER_BUF+3
    st SUB_BUF_2+3

    ld OP_IDX
    jnz +
    jmp perform_plus
+   cmpi #1
    jnz +
    jmp perform_minus
+   cmpi #2
    jnz +
    jmp perform_multiply
+   jmp halt                ; invalid operation

perform_minus:
    call sub_buf

    ld SUB_CARRY
    st RESULT_CARRY
    jnz +
    call neg_buf

+   call convert_output

    ld RESULT_CARRY
    jnz +
    writebuf LCD_BUFFER+10 "-"
    jmp ++
+   writebuf LCD_BUFFER+10 " "

++  jmp print_result

perform_plus:
    call add_buf

    call convert_output
    writebuf LCD_BUFFER+10 " "

print_result:
    lit #LCD_REG_COMMAND
    st LCD_CONTROL_STATE

    writebuf LCD_BUFFER LCD_COMMAND_CURSOR_POS_LINE_2
    lit #1
    calli lcd_write_buffer

    ; prepare to send LCD character data
    lit #LCD_REG_DATA
    st LCD_CONTROL_STATE

    ; display result
    lit #3
    st LCD_BUFFER+9
    st LCD_BUFFER+7
    st LCD_BUFFER+5
    st LCD_BUFFER+3
    st LCD_BUFFER+1

    ld OUTPUT_BUF
    st LCD_BUFFER+8
    ld OUTPUT_BUF+1
    st LCD_BUFFER+6
    ld OUTPUT_BUF+2
    st LCD_BUFFER+4
    ld OUTPUT_BUF+3
    st LCD_BUFFER+2
    ld OUTPUT_BUF+4
    st LCD_BUFFER

    lit #11
    calli lcd_write_buffer
    jmp end_checks

perform_multiply:

end_checks:
    jmp main_loop

    jmp halt

convert_output:
    ; SUB_BUF_1 => OUTPUT_BUF
    lit #0
    st OUTPUT_BUF
    st OUTPUT_BUF+1
    st OUTPUT_BUF+2
    st OUTPUT_BUF+3
    st OUTPUT_BUF+4

    ; 10000
    lit #$0
    st SUB_BUF_2
    lit #$1
    st SUB_BUF_2+1
    lit #$7
    st SUB_BUF_2+2
    lit #$2
    st SUB_BUF_2+3

-   addi #0 ; NOP
    call cmp_buf
    ld SUB_CARRY
    jnz +
    call sub_buf
    ld OUTPUT_BUF
    addi #1
    st OUTPUT_BUF
    jmp -

    ; 1000
+   lit #$8
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
    ld OUTPUT_BUF+1
    addi #1
    st OUTPUT_BUF+1
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
    ld OUTPUT_BUF+2
    addi #1
    st OUTPUT_BUF+2
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
    ld OUTPUT_BUF+3
    addi #1
    st OUTPUT_BUF+3
    jmp -
    ; 1
+   ld SUB_BUF_1
    st OUTPUT_BUF+4
    ret

neg_buf:
    ld SUB_BUF_1
    nori #0 ; not
    st SUB_BUF_1
    ld SUB_BUF_1+1
    nori #0 ; not
    st SUB_BUF_1+1
    ld SUB_BUF_1+2
    nori #0 ; not
    st SUB_BUF_1+2
    ld SUB_BUF_1+3
    nori #0 ; not
    st SUB_BUF_1+3
    ld SUB_BUF_1
    addi #1
    st SUB_BUF_1
    jnc +
    ld SUB_BUF_1+1
    addi #1
    st SUB_BUF_1+1
    jnc +
    ld SUB_BUF_1+2
    addi #1
    st SUB_BUF_1+2
    jnc +
    ld SUB_BUF_1+3
    addi #1
    st SUB_BUF_1+3
    ; TODO: handle carry
+   ret

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
    jc +
    lit #0
    st SUB_CARRY
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
    jc +
    lit #0
    st SUB_CARRY
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
    jc +
    lit #0
    st SUB_CARRY
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

add_buf:
    ld SUB_BUF_2
    jz +
    addm SUB_BUF_1  ; buf_1 - buf_2
    st SUB_BUF_1
    jnc +
    ld SUB_BUF_1+1
    addi #1
    st SUB_BUF_1+1
    jnc +
    ld SUB_BUF_1+2
    addi #1
    st SUB_BUF_1+2
    jnc +
    ld SUB_BUF_1+3
    addi #1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+1
    jz +
    addm SUB_BUF_1+1
    st SUB_BUF_1+1
    jnc +
    ld SUB_BUF_1+2
    addi #1
    st SUB_BUF_1+2
    jnc +
    ld SUB_BUF_1+3
    addi #1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+2
    jz +
    addm SUB_BUF_1+2
    st SUB_BUF_1+2
    jnc +
    ld SUB_BUF_1+3
    addi #1
    st SUB_BUF_1+3
+   ld SUB_BUF_2+3
    jz +
    addm SUB_BUF_1+3
    st SUB_BUF_1+3
+   ret

convert_input:
    ; input[0]
    ld DIGITS_BUF
    ; input[0] * 10
    calli mul10
    ; store result
    ld MUL_RES+1
    st NUMBER_BUF+1
    ; input[0] * 10 + input[1]
    ld MUL_RES
    addm DIGITS_BUF+1
    ; store result
    st NUMBER_BUF
    jnc +
    ld NUMBER_BUF+1
    addi #1
    st NUMBER_BUF+1
+   ld NUMBER_BUF+1
    ; <((input[0] * 10 + input[1]) * 10)
    calli mul10
    ld MUL_RES
    st NUMBER_BUF+1
    ld MUL_RES+1
    st NUMBER_BUF+2
    ld NUMBER_BUF
    ; >((input[0] * 10 + input[1]) * 10)
    calli mul10
    ld MUL_RES+1
    addm NUMBER_BUF+1
    st NUMBER_BUF+1
    jnc +
    ld NUMBER_BUF+2
    addi #1
    st NUMBER_BUF+2
+   ld MUL_RES
    ; (input[0] * 10 + input[1]) * 10 + input[2]
    addm DIGITS_BUF+2
    st NUMBER_BUF
    jnc +
    ld NUMBER_BUF+1
    addi #1
    st NUMBER_BUF+1
    ; ((input[0] * 10 + input[1]) * 10 + input[2]) * 10
+   ld NUMBER_BUF+2
    calli mul10
    ld MUL_RES+1
    st NUMBER_BUF+3
    ld MUL_RES
    st NUMBER_BUF+2
    ld NUMBER_BUF+1
    calli mul10
    ld MUL_RES+1
    addm NUMBER_BUF+2
    st NUMBER_BUF+2
    jnc +
    ld NUMBER_BUF+3
    addi #1
    st NUMBER_BUF+3
+   ld MUL_RES
    st NUMBER_BUF+1
    ld NUMBER_BUF
    calli mul10
    ld MUL_RES+1
    addm NUMBER_BUF+1
    st NUMBER_BUF+1
    jnc +
    ld NUMBER_BUF+2
    addi #1
    st NUMBER_BUF+2
    jnc +
    ld NUMBER_BUF+3
    addi #1
    st NUMBER_BUF+3
+   ld MUL_RES
    st NUMBER_BUF
    ; ((input[0] * 10 + input[1]) * 10 + input[2]) * 10 + input[3]
    ld DIGITS_BUF+3
    addm NUMBER_BUF
    st NUMBER_BUF
    jnc +
    ld NUMBER_BUF+1
    addi #1
    st NUMBER_BUF+1
    jnc +
    ld NUMBER_BUF+2
    addi #1
    st NUMBER_BUF+2
    jnc +
    ld NUMBER_BUF+3
    addi #1
    st NUMBER_BUF+3
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

cursor_set_pos_line1:
    ; accumulator = cursor position at line 1
    st LCD_BUFFER
    lit #<LCD_COMMAND_CURSOR_POS_LINE_1
    st LCD_BUFFER+1

    ; prepare to send an LCD command
    lit #LCD_REG_COMMAND
    st LCD_CONTROL_STATE

    lit #1
    calli lcd_write_buffer
    ret

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

    ret

    ; The LCD is now in 4-bit mode, and we can send byte-wide commands as a pair of nibble, high nibble first.

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
