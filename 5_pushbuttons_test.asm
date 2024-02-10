; N76E003 LCD_Pushbuttons.asm: Reads muxed push buttons using one input

$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))

ORG 0x0000
	ljmp main

;              1234567890123456    <- This helps determine the location of the counter
title:     db 'LCD PUSH BUTTONS', 0
blank:     db '                ', 0

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$LIST

BSEG
; These five bit variables store the value of the pushbuttons after calling 'LCD_PB' below
PB0: dbit 1
PB1: dbit 1
PB2: dbit 1
PB3: dbit 1
PB4: dbit 1
mf: dbit 1
start_stop_flag: dbit 1

dseg at 0x30
soak_temp: ds 1
soak_time: ds 1
reflow_temp: ds 1
reflow_time: ds 1
x:   ds 4
y:   ds 4
bcd: ds 5

CSEG
Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	ret
	
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

LCD_PB:
	; Set variables to 1: 'no push button pressed'
	setb PB0
	setb PB1
	setb PB2
	setb PB3
	setb PB4
	; The input pin used to check set to '1'
	setb P1.5
	
	; Check if any push button is pressed
	clr P0.0
	clr P0.1
	clr P0.2
	clr P0.3
	clr P1.3
	jb P1.5, LCD_PB_Done

	; Debounce
	mov R2, #50
	lcall waitms
	jb P1.5, LCD_PB_Done

	; Set the LCD data pins to logic 1
	setb P0.0
	setb P0.1
	setb P0.2
	setb P0.3
	setb P1.3
	
	; Check the push buttons one by one
	clr P1.3
	mov c, P1.5
	mov PB4, c
	setb P1.3
	jnb PB4,increment_soak_temp

	clr P0.0
	mov c, P1.5
	mov PB3, c
	setb P0.0
	jnb PB3, increment_soak_time
	
	clr P0.1
	mov c, P1.5
	mov PB2, c
	setb P0.1
	jnb PB2, increment_reflow_temp
	
	clr P0.2
	mov c, P1.5
	mov PB1, c
	setb P0.2
	jnb PB1, increment_reflow_time
	
	clr P0.3
	mov c, P1.5
	mov PB0, c
	setb P0.3
	jnb PB0, start_stop


LCD_PB_Done:		
	ret

increment_soak_temp:
	inc soak_temp
	mov a, soak_temp
	cjne a, #240, LCD_PB_Done
	mov soak_temp, #0x00
	sjmp LCD_PB_Done
increment_soak_time:
	inc soak_time
	mov a, soak_time
	cjne a, #120, LCD_PB_Done
	mov soak_time, #0x00
	sjmp LCD_PB_Done
increment_reflow_temp: 
	inc reflow_temp
	mov a, reflow_temp
	cjne a, #240, LCD_PB_Done
	mov reflow_temp, #0x00
	sjmp LCD_PB_Done
increment_reflow_time:
	inc reflow_time
	mov a, reflow_time
	cjne a, #240, LCD_PB_Done
	mov reflow_time, #0x00
	sjmp LCD_PB_Done


start_stop:
	cpl start_stop_flag
	sjmp LCD_PB_Done
	
SendToLCD:
mov b, #100
div ab
orl a, #0x30 ; Convert hundreds to ASCII
lcall ?WriteData ; Send to LCD
mov a, b ; Remainder is in register b
mov b, #10
div ab
orl a, #0x30 ; Convert tens to ASCII
lcall ?WriteData; Send to LCD
mov a, b
orl a, #0x30 ; Convert units to ASCII
lcall ?WriteData; Send to LCD
ret

Display_PushButtons_LCD:
	Set_Cursor(2, 2)
	mov a, soak_temp
	lcall SendToLCD
	
	Set_Cursor(2, 6)
	mov a, soak_time
	lcall SendToLCD
    
    Set_Cursor(2, 10)
    mov a, reflow_temp
	lcall SendToLCD
    
    Set_Cursor(2, 14)
    mov a, reflow_time
	lcall SendToLCD
	
		
	ret
	
main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)
	Set_Cursor(2, 1)
    Send_Constant_String(#blank)
    
    mov soak_temp, #0
    mov soak_time, #0
    mov reflow_time, #0
    mov reflow_temp, #0
	clr start_stop_flag
	
Forever:
	lcall LCD_PB
	lcall Display_PushButtons_LCD
	
	; Wait 50 ms between readings
	mov R2, #50
	lcall waitms
	
	ljmp Forever
	
END
	