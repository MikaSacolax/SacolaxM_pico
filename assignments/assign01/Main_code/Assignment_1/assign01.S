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

.equ    SET_VALUE_1, 0x1
.equ    SET_VALUE_0, 0x0

.equ    SRAM_BANK, 0x20000000       @ Sram bank for vtor

alarm_interrupt_handler:

        push    {lr}                    @ Push to stack since nested loops

        ldr     r0, =msg
        bl      printf
        
        ldr     r0, =msg
        bl      printf

        cmp     r5, #LED_VAL_ON         @ Check to see if led is in flashing state
        bne     led_flash_off           @ Branch if led should not be flashed

        movs    r0, #GPIO_LED_PIN       
        bl      asm_gpio_get                @ Check pin value
        cmp     r0, #LED_VAL_OFF          @ Check if the LED GPIO pin value is "off"
        beq     led_set_on                  @ If it is "off" then then jump code to to turn it on

led_set_off:
        movs    r1, #LED_VAL_OFF          @ The LED is currently "on" so we want to turn it "off"
        b       led_set_state               @ Jump to portion of code where we set the state of the LED

led_set_on:
        movs    r1, #LED_VAL_ON           @ The LED is currently "off" so we want to turn it "on"

led_set_state:
        movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
        bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)

led_flash_off:                          @ branch location for if not in flashing state

        ldr     r0, =(TIMER_BASE + 0x34)
        movs    r1, 1
        str     r1, [r0,0]

        movs    r1, #SET_VALUE_1                                        @ Clear interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        str     r1, [r0, 0]

        movs    r1, #SET_VALUE_1                                        @ Enables interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r0, 0]



        ldr     r0, =(TIMER_BASE + 0x28)                  @ Set desired delay time
        ldr     r1, [r0]
        ldr     r3, =(TIMER_BASE + 0x10)
        add     r1, r1, r6
        str     r1, [r3, 0]

        pop     {pc}

@ Entry point to the ASM portion of the program
main_asm:

        ldr    r6, =DFLT_ALARM_TIME    @ Make r6 the variable for flashing time
        
        @Initialise pins
        movs    r0, #GPIO_LED_PIN       @ Led pin
        bl      asm_gpio_init
        movs    r0, #GPIO_LED_PIN
        movs    r1, #GPIO_DIR_OUT
        bl      asm_gpio_set_dir

        movs    r0, #GPIO_LED_PIN       @ Set a default state for the led pin
        movs    r1, #LED_VAL_ON
        movs    r5, #LED_VAL_ON          @ r5 will be the check registry for if the led should flash
        bl      asm_gpio_put


        movs    r0, #GPIO_BTN_DN        @ Pin 20
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_DN
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir

        movs    r0, #GPIO_BTN_EN        @ Pin 21
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_EN
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir

        movs    r0, #GPIO_BTN_UP        @ Pin 22
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_UP
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir

        
        @ Create VTOR 

        ldr     r0, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
        ldr     r1, =SRAM_BANK
        str     r1, [r0]

        @ Set timer interrupt service handler location into RAM vector table

        ldr     r0, =(SRAM_BANK + ALRM_ISR_OFFSET)                      @ Ram vector table address
        ldr     r1, =alarm_interrupt_handler                            @ alarm_interrupt_handler address
        adds     r1, r1, 1
        str     r1, [r0, 0]

        movs    r1, #SET_VALUE_1                                        @ Clear interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        str     r1, [r0, 0]

        movs    r1, #SET_VALUE_1                                        @ Enables interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r0, 0]
        

        movs    r1, 1                                        @ Enable alarm interrupt
        ldr     r0, =(TIMER_BASE + 0x38)
        str     r1, [r0, 0]

        ldr     r0, =(TIMER_BASE + 0x28)                  @ Set desired delay time
        ldr     r1, [r0]

        ldr     r0, =(TIMER_BASE + 0x10)
        add     r1, r1, r6
        str     r1, [r0, 0]

        movs    r0, #GPIO_LED_PIN       @ Set a default state for the led pin
        movs    r1, #LED_VAL_OFF
        bl      asm_gpio_put


main_loop:

        b       main_loop

.align 4
msg:    .asciz "Hello World!\n"

.align 4
msg2:   .asciz "Test\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME