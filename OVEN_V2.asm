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
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
TIMER2_RATE   EQU 100     ; 100Hz, for a timer tick of 1s
TIMER2_RELOAD EQU ((65536-(CLK/(16*TIMER2_RATE))))

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
;---------------------------------;
; Define any buttons & pins here  ;
;---------------------------------;
SOUND_OUT   EQU P1.7 ; speaker pin
PWM_OUT    EQU P1.0 ; Logic 1 = oven on
;---------------------------------------------

ORG 0x0000
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
	
; Timer/Counter 2 overflow interrupt vector
;org 0x002B
;	ljmp Timer2_ISR

;---------------------------------;
; Define any constant string here ;
;---------------------------------;
;                	  1234567890123456    <- This helps determine the location of the counter
To_Message:  	  db 'To=xxxC Tj= 22C ', 0
Time_temp_display:db 'sxxx,xx rxxx,xx ', 0 ; soak temp,time reflow temp,time
Ramp_to_soak:	  db 'RampToSoak s=', 0 ; state 1 display
Soak_display: 	  db 'Soak       s=', 0 ; state 2 display
Ramp_to_peak: 	  db 'RampToPeak s=', 0 ; state 3 display
Reflow_display:   db 'Reflow     s=', 0 ; state 4 display
Cooling_display:  db 'Cooling    s=', 0 ; state 5 display
clear_screen:	  db '                ', 0
Hot_temp: db 'HOT',0
;---------------------------------------------
cseg

LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;---------------------------------;
; Define variables here           ;
;---------------------------------;
; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5   ;temperature variable for reading
Count1ms:     ds 2 ; Used to determine when one second has passed
seconds: ds 1
VLED_ADC: ds 2
reflow_time: ds 1 ; time parameter for reflow	
reflow_temp: ds 1 ; temp parameter for reflow
soak_time: ds 1 ; time parameter for soak
soak_temp: ds 1 ; temp parameter for soak
pwm_counter: ds 1 ; power counter
pwm: ds 1 ; variable to count the power percentage
temp: ds 3
FSM_state: ds 1
Melody_Reload: ds 2
;---------------------------------------------

;---------------------------------;
; Define flags here               ;
;---------------------------------;
BSEG
mf: dbit 1
s_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
PB0: dbit 1 	; start/stop
PB1: dbit 1 	; increment reflow time
PB2: dbit 1 	; increment reflow temp
PB3: dbit 1 	; increment soak time
PB4: dbit 1 	; increment soak temp
FSM_start_flag: dbit 1 ; once it starts the timer2 will start checking for stop pushbutton
start_stop_flag: dbit 1 ; Set to one if button is pressed to start, press again to stop
too_hot_flag: dbit 1 ; Check if the value is past 250
;---------------------------------------------

$NOLIST
$include(math32.inc)
$LIST

;---------------------------------;
; Define special chars here       ;
;---------------------------------;
fire:
	mov   A,#40H         ;Load the location where we want to store
    lcall ?WriteCommand    ;Send the command
    mov   A,#09H         ;Load row 1 data
    lcall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 2 data
    lcall ?WriteData   ;Send the data
    mov   A,#14H         ;Load row 3 data
    lcall ?WriteData   ;Send the data
    mov   A,#06H         ;Load row 4 data
    lcall ?WriteData   ;Send the data
    mov   A,#0FH         ;Load row 5 data
    lcall ?WriteData   ;Send the data
    mov   A,#1BH         ;Load row 6 data
    lcall ?WriteData   ;Send the data
    mov   A,#11H         ;Load row 7 data
    acall ?WriteData   ;Send the data
    mov   A,#0EH         ;Load row 8 data
    lcall ?WriteData   ;Send the data
    ret                  ;Return from routine

double_eighth:
    mov   A,#48H         ;Load the location where we want to store
    lcall ?WriteCommand    ;Send the command
    mov   A,#00H         ;Load row 1 data
    lcall ?WriteData   ;Send the data
    mov   A,#0FH         ;Load row 2 data
    lcall ?WriteData   ;Send the data
    mov   A,#09H         ;Load row 3 data
    lcall ?WriteData   ;Send the data
    mov   A,#09H         ;Load row 4 data
    lcall ?WriteData   ;Send the data
    mov   A,#1BH         ;Load row 5 data
    lcall ?WriteData   ;Send the data
    mov   A,#1BH         ;Load row 6 data
    lcall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 7 data
    acall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 8 data
    lcall ?WriteData   ;Send the data
    ret                  ;Return from routine
    
eighth:
    mov   A,#50H         ;Load the location where we want to store
    lcall ?WriteCommand    ;Send the command
    mov   A,#04H         ;Load row 1 data
    lcall ?WriteData   ;Send the data
    mov   A,#06H         ;Load row 2 data
    lcall ?WriteData   ;Send the data
    mov   A,#05H         ;Load row 3 data
    lcall ?WriteData   ;Send the data
    mov   A,#04H         ;Load row 4 data
    lcall ?WriteData   ;Send the data
    mov   A,#0CH         ;Load row 5 data
    lcall ?WriteData   ;Send the data
    mov   A,#14H         ;Load row 6 data
    lcall ?WriteData   ;Send the data
    mov   A,#08H         ;Load row 7 data
    acall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 8 data
    lcall ?WriteData   ;Send the data
    ret                  ;Return from routine

heart:
    mov   A,#58H         ;Load the location where we want to store
    lcall ?WriteCommand    ;Send the command
    mov   A,#00H         ;Load row 1 data
    lcall ?WriteData   ;Send the data
    mov   A,#0AH         ;Load row 2 data
    lcall ?WriteData   ;Send the data
    mov   A,#15H         ;Load row 3 data
    lcall ?WriteData   ;Send the data
    mov   A,#11H         ;Load row 4 data
    lcall ?WriteData   ;Send the data
    mov   A,#11H         ;Load row 5 data
    lcall ?WriteData   ;Send the data
    mov   A,#0AH         ;Load row 6 data
    lcall ?WriteData   ;Send the data
    mov   A,#04H         ;Load row 7 data
    acall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 8 data
    lcall ?WriteData   ;Send the data
    ret                  ;Return from routine
bell:
    mov   A,#60H         ;Load the location where we want to store
    lcall ?WriteCommand    ;Send the command
    mov   A,#00H         ;Load row 1 data
    lcall ?WriteData   ;Send the data
    mov   A,#04H          ;Load row 2 data
    lcall ?WriteData   ;Send the data
    mov   A,#0eH          ;Load row 3 data
    lcall ?WriteData   ;Send the data
    mov   A,#0eH         ;Load row 4 data
    lcall ?WriteData   ;Send the data
    mov   A,#0eH         ;Load row 5 data
    lcall ?WriteData   ;Send the data
    mov   A,#1fH         ;Load row 6 data
    lcall ?WriteData   ;Send the data
    mov   A,#00H         ;Load row 7 data
    acall ?WriteData   ;Send the data
    mov   A,#04H         ;Load row 8 data
    lcall ?WriteData   ;Send the data
    ret                  ;Return from routine

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
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
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
	mov TH0, Melody_Reload+1
	mov TL0, Melody_Reload+0
	setb TR0
	cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov T2MOD, #0b1010_0000 ; Enable timer 2 autoreload, and clock divider is 16
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	mov pwm, #0
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2 ;
;---------------------------------;
Timer2_ISR:
	clr TF2 ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR. It is bit addressable.
	cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
		
	; The two registers used in the ISR must be saved in the stack
	push psw
	push acc
	inc pwm_counter
	clr c
	mov a, pwm
	subb a, pwm_counter ; If pwm_counter <= pwm then c=1
	cpl c
	mov PWM_OUT, c
	mov a, pwm_counter

	cjne a, #100, Timer2_ISR_done
	mov pwm_counter, #0
	inc seconds
	setb s_flag
	
Timer2_ISR_done:

	pop acc
	pop psw
	reti


;---------------------------------;
; Temperature senseor function    ;
;---------------------------------;
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
	;clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize the pins used by the ADC (P1.1, P1.7) as input.
	;orl	P1M1, #0b10000010
	;anl	P1M2, #0b01111101
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10000001 ; Activate AIN0 and AIN7 analog inputs
	orl ADCCON1, #0x01 ; Enable ADC
	
	ret



Display_special_char1:
	lcall heart
	mov a, #0x81
	lcall ?WriteCommand
	mov a, #3H
	lcall ?WriteData

	lcall eighth
	mov a, #0xC4
	lcall ?WriteCommand
	mov a, #2H
	lcall ?WriteData

	lcall bell
	mov a, #0x87
	lcall ?WriteCommand
	mov a, #4H
	lcall ?WriteData

	lcall double_eighth
	mov a, #0xCA
	lcall ?WriteCommand
	mov a, #1H
	lcall ?WriteData

	lcall heart
	mov a, #0x8D
	lcall ?WriteCommand
	mov a, #3H
	lcall ?WriteData
	reti
	
Display_special_char2:
	lcall heart
	mov a, #0xC0
	lcall ?WriteCommand
	mov a, #3H
	lcall ?WriteData

	lcall eighth
	mov a, #0x83
	lcall ?WriteCommand
	mov a, #2H
	lcall ?WriteData

	lcall bell
	mov a, #0xC7
	lcall ?WriteCommand
	mov a, #4H
	lcall ?WriteData

	lcall double_eighth
	mov a, #0x8B
	lcall ?WriteCommand
	mov a, #1H
	lcall ?WriteData

	lcall heart
	mov a, #0xCE
	lcall ?WriteCommand
	mov a, #3H
	lcall ?WriteData
	reti

clear_screen_func:
    
    Set_Cursor(1,1)
	Send_Constant_String(#clear_screen)
	Set_Cursor(2,1)
	Send_Constant_String(#clear_screen)
    reti
    
main:
	mov sp, #0x7f
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00
    
	lcall Init_All
    lcall LCD_4BIT
	lcall Timer0_Init
    lcall Timer2_Init
	
    setb EA   ; Enable Global interrupts
    mov FSM_state,#0
	mov seconds, #0x00
	mov soak_temp, #0x8C ;140
	mov soak_time, #0x3C ; 60
	mov reflow_temp, #0xE6 ; 230
	mov reflow_time, #0x1E ; 30
	mov bcd,#0
    clr TR2
	setb ET0

    lcall Display_special_char1
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

	lcall clear_screen_func
;----------------------------------------
	lcall Display_special_char2

	mov Melody_Reload+1, #high(C4_KEY)
	mov Melody_Reload+0, #low(C4_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)
	
    lcall clear_screen_func
    lcall Display_special_char1
    
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

	lcall clear_screen_func
    lcall Display_special_char2
	
	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char1
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

	lcall clear_screen_func
    lcall Display_special_char2
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

	lcall clear_screen_func
    lcall Display_special_char1
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

	lcall clear_screen_func
    lcall Display_special_char2

	mov Melody_Reload+1, #high(C6_KEY)
	mov Melody_Reload+0, #low(C6_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)
	
	lcall clear_screen_func
    lcall Display_special_char1
;----------------------------------------
	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(C6_KEY)
	mov Melody_Reload+0, #low(C6_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char2
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char1

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char2
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char1

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char2
;-----------------------------------------
	mov Melody_Reload+1, #high(B5_KEY)
	mov Melody_Reload+0, #low(B5_KEY)
	Wait_Milli_Seconds(#240)

	mov Melody_Reload+1, #high(A5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char1

	mov Melody_Reload+1, #high(G5_KEY)
	mov Melody_Reload+0, #low(A5_KEY)
	Wait_Milli_Seconds(#240)
	
	mov Melody_Reload+1, #high(Fs5_KEY)
	mov Melody_Reload+0, #low(Fs5_KEY)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char2

	mov Melody_Reload+1, #high(E5_KEY)
	mov Melody_Reload+0, #low(E5_KEY)
	Wait_Milli_Seconds(#240)
	Wait_Milli_Seconds(#240)

	lcall clear_screen_func
    lcall Display_special_char1

END