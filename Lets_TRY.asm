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

CLK           EQU 16600000 ; Microcontroller system frequency in Hz
TIMER0_RATE   EQU 2048     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

;---------------------------------;
; Key board                       ;
;---------------------------------;
C3_RATE equ 262
C3_KEY EQU ((65536-(CLK/C3_RATE)))
D3_RATE equ 294
D3_KEY EQU ((65536-(CLK/D3_RATE)))
B3_RATE equ 494
B3_KEY EQU ((65536-(CLK/B3_RATE)))
Gs3_RATE equ 415
Gs3_KEY EQU ((65536-(CLK/Gs3_RATE)))
A3_RATE equ 440
A3_KEY EQU ((65536-(CLK/A3_RATE)))

C4_RATE equ 523
C4_KEY EQU ((65536-(CLK/C4_RATE)))
D4_RATE equ 587
D4_KEY EQU ((65536-(CLK/C4_RATE)))
E4_RATE equ 479
E4_KEY EQU ((65536-(CLK/E4_RATE)))
Gs4_RATE equ 831
Gs4_KEY EQU ((65536-(CLK/Gs4_RATE)))
A4_RATE equ 880
A4_KEY EQU ((65536-(CLK/A4_RATE)))
B4_RATE equ 988
B4_KEY EQU ((65536-(CLK/B4_RATE)))

C5_RATE equ 1047
C5_KEY EQU ((65536-(CLK/C5_RATE)))
D5_RATE equ 1175
D5_KEY EQU ((65536-(CLK/D5_RATE)))
Ds5_RATE equ 1245
Ds5_KEY EQU ((65536-(CLK/Ds5_RATE)))
E5_RATE equ 1319
E5_KEY EQU ((65536-(CLK/E5_RATE)))
F5_RATE equ 1397
F5_KEY EQU ((65536-(CLK/F5_RATE)))
Fs5_RATE equ 1480
Fs5_KEY EQU ((65536-(CLK/Fs5_RATE)))
G5_RATE equ 1568
G5_KEY EQU ((65536-(CLK/G5_RATE)))
Gs5_RATE equ 1661
Gs5_KEY EQU ((65536-(CLK/Gs5_RATE)))
A5_RATE equ 1760
A5_KEY EQU ((65536-(CLK/A5_RATE)))
B5_RATE equ 1976
B5_KEY EQU ((65536-(CLK/B5_RATE)))

C6_RATE equ 2093
C6_KEY EQU ((65536-(CLK/C6_RATE)))
E6_RATE equ 2637
E6_KEY EQU ((65536-(CLK/E6_RATE)))
MUTE_KEY EQU 0
;----------------------------------
SOUND_OUT     equ P1.7

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti


; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
Melody_Reload: ds 2
; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db '  >Music Test<  ', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, Melody_Reload+1
	mov TL0, Melody_Reload+0
	; Enable the timer and interrupts
    ;setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz wave at pin SOUND_OUT   ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 doesn't have 16-bit auto-reload, so
	clr TR0
	;mov TH0, #high(TIMER0_RELOAD)
	;mov TL0, #low(TIMER0_RELOAD)
	mov TH0, Melody_Reload+1
	mov TL0, Melody_Reload+0
	setb TR0
	cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!
	reti
	
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00
    
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    Send_Constant_String(#Initial_Message)

Turkish_March:
	lcall Timer0_Init
	setb ET0
    mov Melody_Reload+1, #high(B3_KEY)
	mov Melody_Reload+0, #low(B3_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(A3_KEY)
	mov Melody_Reload+0, #low(A3_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(Gs3_KEY)
	mov Melody_Reload+0, #low(Gs3_KEY)
	Wait_Milli_Seconds(#120)
	
	mov Melody_Reload+1, #high(A3_KEY)
	mov Melody_Reload+0, #low(A3_KEY)
	Wait_Milli_Seconds(#120)
;----------------------------------------
	mov Melody_Reload+1, #high(C4_KEY)
	mov Melody_Reload+0, #low(C4_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)
	
	mov Melody_Reload+1, #high(D4_KEY)
	mov Melody_Reload+0, #low(D4_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(C4_KEY)
	mov Melody_Reload+0, #low(C4_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(B4_KEY)
	mov Melody_Reload+0, #low(B4_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(C5_KEY)
	mov Melody_Reload+0, #low(C5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)
;-----------------------------------------
	mov Melody_Reload+1, #high(F5_KEY)
	mov Melody_Reload+0, #low(F5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(Ds5_KEY)
	mov Melody_Reload+0, #low(Ds5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#120)
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(Gs5_KEY)
	mov Melody_Reload+0, #low(Gs5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#120)
;--------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(Gs5_KEY)
	mov Melody_Reload+0, #low(Gs5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#120)

	mov Melody_Reload+1, #high(C6_KEY)
	mov Melody_Reload+0, #low(C6_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)
	
;----------------------------------------
	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(C6_KEY)
	mov Melody_Reload+0, #low(C6_KEY)
	Wait_Milli_Seconds(#240)
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)
	
	mov Melody_Reload+1, #high(Fs5_KEY)
	mov Melody_Reload+0, #low(Fs5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)

forever:
	clr TR0
	sjmp forever
END
