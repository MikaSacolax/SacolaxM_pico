#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)


        @ function for timer

timer_func:
        ldr     r1, TIMER_BASE
        ldr     r5, #1
        mov     r2, r5
        str     r2, [r1, 14]

        ldr     r5, (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        ldr     r1, [r5]
        str     r2, [r1, 0]

        ldr     r5, (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        ldr     r1, [r5]
        str     r2, [r1, 0]

        ldr     r5, (TIMER_BASE + TIMER_TIMELR_OFFSET)
        ldr     r1, [r5]
        ldr     r2, [r1, 10]
        add     r2, r0
        str     r2, [r1, 4]

        bx lr

flip_led:
        ldr     r0, =0xd0000000
        ldr     r5, #1
        mov     r1, r5
        lsl     r1, r1, #25
        str     r1, [r0, 7]

        bx lr

timer_req_func:
        push    {lr}

        bl      flip_led

        ldr     r0, =0x40057000
        ldr     r5, #1
        mov     r1, r5
        str     r1, [r0, 13]

        ldr     r5, DFLT_ALARM_TIME
        mov     r0, r5
        bl      timer_func

        pop     {pc}


        
@ Entry point to the ASM portion of the program
main_asm:
        ldr     r0, =msg
        bl      printf



        @ Initialising all gpio 


        @ GPIO pin 20

        ldr     r0, GPIO_BTN_DN
        b       asm_gpio_init           @ Initalise GPIO
        b       asm_gpio_set_irq        @ Enable falling-edge interrupt
        ldr     r1, GPIO_DIR_IN         
        b       asm_gpio_set_dir        @ Set direction


        @ GPIO pin 21

        ldr     r0, GPIO_BTN_EN
        b       asm_gpio_init           @ Initalise GPIO
        b       asm_gpio_set_irq        @ Enable falling-edge interrupt
        ldr     r1,GPIO_DIR_IN
        b       asm_gpio_set_dir        @ Set direction


        @ GPIO pin 22

        ldr     r0, GPIO_BTN_UP
        b       asm_gpio_init           @ Initalise GPIO
        b       asm_gpio_set_irq        @ Enable falling-edge interrupt
        ldr     r1, GPIO_DIR_IN
        b       asm_gpio_set_dir        @ Set direction


        @ GPIO pin 25

        ldr     r0, GPIO_LED_PIN
        b       asm_gpio_init           @ Initalise GPIO
        ldr     r1, GPIO_DIR_OUT
        b       asm_gpio_set_dir        @ Set direction


        @ Reset timer
        ldr     r0, =0x4000f000
        ldr     r5, #1
        mov     r1, r5
        ldr     r5, #21
        lsl     r1, r1, r5
        str     r1, [r0, 0]
        ldr     r0, =0x4000c000
rst_timer:
        ldr     r2, [r0, 2]
        and     r2, r1
        beq     rst_timer

        @ Vector table
        ldr     r5, (PPB_BASE + M0PLUS_VTOR_OFFSET)
        ldr     r0, [r5]
        ldr     r1, =0x20040000
        str     r1, [r0, 0]

        adr     r0, timer_req_func
        add     r0, 1
        str     r0, [r1, 16]

        @ Set first state
        mov     r0, DFLT_ALARM_TIME
        bl      timer_func


main_loop:
        wfe
        b       main_loop

.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME