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
.equ    SET_VALUE_0, 0

.equ    SRAM_BANK, 0x20000000       @ Sram bank for vtor
.equ    INTERVAL_STORAGE, 0x20040000         @ Storage for interval
.equ    STATE_STORAGE, 0x20041000            @ Storgae for flashing state
.equ    IO_BANK_SUM, 0x2001
.equ    IO_BANK_SUM_NO_ALARM, 0x4440000

alarm_interrupt_handler:

        push    {lr}                    @ Push to stack since nested loops

        ldr     r0, =STATE_STORAGE
        ldr     r1, [r0]

        cmp     r1, #LED_VAL_ON         @ Check to see if led is in flashing state
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

        ldr     r0, =(TIMER_BASE + 0x34)                                @ clear raw interrupt - INTR for timer
        movs    r1, 1
        str     r1, [r0,0]

        ldr    r1, =IO_BANK_SUM                                        @ Clear interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        str     r1, [r0, 0]

        ldr    r1, =IO_BANK_SUM                                        @ Enables interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r0, 0]



        ldr     r0, =(TIMER_BASE + 0x28)                  @ Set desired delay time - TIMERAWL, Used because no side effect unlike TIMELW
        ldr     r1, [r0]
        ldr     r3, =(TIMER_BASE + 0x10)                  @ ALARM0 configureation address
        ldr     r4, =INTERVAL_STORAGE
        ldr     r2, [r4]
        add     r1, r1, r2
        str     r1, [r3, 0]

        pop     {pc}



gpio_interrupt:

        push    {lr}

        ldr     r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)      @ Get which interrupt is triggered
        ldr     r1, [r0]
        
        @ Check interrupt pin 20

        ldr     r0, =GPIO_BTN_DN_MSK                                    @ Check if pin 20 triggered
        tst     r1, r0
        bne     gpio_20_hanlder

        ldr     r0, =GPIO_BTN_EN_MSK                                    @ Check if pin 21 triggered
        tst     r1, r0
        bne     gpio_21_hanlder

        ldr     r0, =GPIO_BTN_UP_MSK                                    @ Check if pin 22 triggered
        tst     r1, r0
        bne     gpio_22_hanlder

        bl      clear

gpio_20_hanlder:

        ldr     r0, =STATE_STORAGE
        ldr     r1, [r0]

        cmp     r1, #LED_VAL_OFF                                        @ If not blinking then reset to inital blink interval
        beq     reset_interval

        ldr     r0, =INTERVAL_STORAGE

        ldr     r1, [r0]

        lsrs    r1, r1, #1                     	                @ Bit shift to half the value

        str     r1, [r0, 0]
        
        bl      clear


gpio_21_hanlder:

        ldr     r0, =STATE_STORAGE
        ldr     r1, [r0]

        cmp     r1, #LED_VAL_ON                                         @ If value is high set low other wise set high
        beq     flip_21
        
        ldr     r2, =LED_VAL_ON
        str     r2, [r0, 0]

        bl      clear

flip_21:

        ldr     r0, =STATE_STORAGE

        ldr     r2, =LED_VAL_OFF
        str     r2, [r0, 0]

        bl      clear

gpio_22_hanlder:

        ldr     r0, =STATE_STORAGE
        ldr     r1, [r0]

        cmp     r1, #LED_VAL_OFF                                        @ If not blinking then reset to inital blink interval
        beq     reset_interval

        ldr     r0, =INTERVAL_STORAGE
        ldr     r1, [r0]

        lsls     r1, r1, #1                                             @ Bit shift left to double the value

        str     r1, [r0, 0]

        bl      clear


reset_interval:

        ldr     r0, =INTERVAL_STORAGE
        ldr     r1, =DFLT_ALARM_TIME
        str     r1, [r0, 0]                                        @ Reset to inital blink interval


clear:
        

        ldr    r1, =IO_BANK_SUM                                        @ Clear interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        str     r1, [r0, 0]

        ldr    r1, =IO_BANK_SUM                                       @ Enables interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r0, 0]


        ldr     r0, =(IO_BANK0_BASE + 0x0f8)                            @ Clear GPIO interrupt - INTR2 Registry
        ldr     r1, =IO_BANK_SUM_NO_ALARM
        str     r1, [r0, 0]


        pop     {pc}

@ Entry point to the ASM portion of the program
main_asm:

        ldr     r0, =INTERVAL_STORAGE
        ldr     r1, =DFLT_ALARM_TIME    @Variable for flashing time
        str     r1, [r0, 0]

        ldr     r0, =STATE_STORAGE
        movs    r1, #LED_VAL_ON          @ Storaging flashing value
        str     r1, [r0, 0]



        @Initialise pins
        movs    r0, #GPIO_LED_PIN       @ Led pin
        bl      asm_gpio_init
        movs    r0, #GPIO_LED_PIN
        movs    r1, #GPIO_DIR_OUT
        bl      asm_gpio_set_dir

        movs    r0, #GPIO_LED_PIN       @ Set a default state for the led pin
        movs    r1, #LED_VAL_ON
        bl      asm_gpio_put


        movs    r0, #GPIO_BTN_DN        @ Pin 20
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_DN
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir
        movs    r0, #GPIO_BTN_DN
        bl      asm_gpio_set_irq

        movs    r0, #GPIO_BTN_EN        @ Pin 21
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_EN
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir
        movs    r0, #GPIO_BTN_EN
        bl      asm_gpio_set_irq

        movs    r0, #GPIO_BTN_UP        @ Pin 22
        bl      asm_gpio_init
        movs    r0, #GPIO_BTN_UP
        movs    r1, #GPIO_DIR_IN
        bl      asm_gpio_set_dir
        movs    r0, #GPIO_BTN_UP
        bl      asm_gpio_set_irq

        
        @ Create VTOR 

        ldr     r0, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
        ldr     r1, =SRAM_BANK
        str     r1, [r0]

        @ Set timer interrupt service handler location into RAM vector table

        ldr     r0, =(SRAM_BANK + ALRM_ISR_OFFSET)                      @ Ram vector table address
        ldr     r1, =alarm_interrupt_handler                            @ alarm_interrupt_handler address
        adds    r1, r1, 1
        str     r1, [r0, 0]                                             @ Add alarm iterrupt handler to vtor


        ldr     r0, =(SRAM_BANK + GPIO_ISR_OFFSET)                      @ Ram vector table address
        ldr     r1, =gpio_interrupt                                     @ gpio_interrupt address
        adds    r1, r1, 1
        str     r1, [r0, 0]                                             @ Add gpio iterrupt handler to vtor


        ldr     r1, =IO_BANK_SUM                                        @ Clear interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        str     r1, [r0, 0]

        ldr     r1, =IO_BANK_SUM                                        @ Enables interrupts
        ldr     r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r0, 0]


        movs    r1, 1                                        @ Enable alarm interrupt
        ldr     r0, =(TIMER_BASE + 0x38)                     @ TIMER INTE
        str     r1, [r0, 0]

        ldr     r0, =(TIMER_BASE + 0x28)                  @ Read time - TIMERAWL
        ldr     r1, [r0]

        ldr     r0, =(TIMER_BASE + 0x10)                  @ Set desired alarm time - ALARM0
        ldr     r3, =INTERVAL_STORAGE
        ldr     r2, [r3]
        add     r1, r1, r2
        str     r1, [r0, 0]

        ldr     r0, =(IO_BANK0_BASE + 0x108)              @ Enable interrupt for GPIO - PROC0_INTE2
        ldr     r1, =IO_BANK_SUM_NO_ALARM
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
msg20:  .asciz "20"
msg21:  .asciz "21"
msg22:  .asciz "22"


.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME