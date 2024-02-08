; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'CLEAR' push button connected to P1.5 is pressed.
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
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

;CLEAR_BUTTON  equ P1.5
;UPDOWN        equ P0.2 ;iniitally 1.6
HOUR_BUTTON          equ p1.6
MIN_BUTTON          equ p1.1
SECOND_BUTTON       equ p1.2
;SET_TIME_BUTTON     equ p1.1
SET_TIME_BUTTON  equ p1.7
AM_PM_BUTTON     equ p1.5

;CLEAR_BUTTON  equ P1.5
SOUND_OUT     equ P1.0


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
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed

;BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
Sec_counter: ds 1
Min_counter:  ds 1 ; The min counter incrememted in the ISR and displayed in the main loop
Hour_counter: ds 1

;for alarm
;ASec_counter: ds 1
AMin_counter:  ds 1 
AHour_counter: ds 1
;AtoP: ds 1 ;from am to pm

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
;half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
one_second_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
one_min_flag: dbit 1
one_hour_flag: dbit 1
AtoP_flag: dbit 1
alarm_flag: dbit 1
alarm_AtoP_flag: dbit 1
am_pm_flag: dbit 1

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
Initial_Message:  db 'Time:  ', 0
Sec_line_message: db 'Alarm:',0
AM_message: db 'Am',0
PM_message: db 'Pm',0
Alarm_on_message: db 'Y',0
Alarm_off_message: db 'N',0


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
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
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
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2 for +/-         ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if one second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb one_second_flag ; Let the main program know one second had passed
	;cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	;mov a, BCD_counter

	mov a, Sec_counter
	cjne a, #0x59, ltmin;if it reaches 1 min, continue code and clear/set to 0, else go to ltmin
	setb one_min_flag
	clr A
	mov Sec_counter,a 

	;now checking the mins 
	mov a, Min_counter
	cjne a, #0x59, lthour;if it reaches 1 hour, continue code and clear/set to 0, else go to lthour
	setb one_hour_flag
	clr A
	mov Min_counter, A

	;check hour
	mov a, Hour_counter
	cjne a, #0x11, lthalfday ;check if the hour is less than 12/limit
	clr A
	mov Hour_counter, A

	;need to sw am pm sign
	cpl AtoP_flag ;swtich from am to pm / pm to am using the complment 

	; need to set a flag for am to pm
	;seb one_hour_flag ;set the flag to show that 1 hour passed
	;jnb UPDOWN, Timer2_ISR_decrement
	;check if more than 60 sec
	
	;add a, #0x01
	sjmp Timer2_ISR_done

ltmin:
	; increment sec_counter
	mov a, Sec_counter
	add a, #0x01 
	da A
	mov Sec_counter,a
	sjmp Timer2_ISR_done

lthour:
	;increment Min_counter
	mov a, Min_counter
	add a, #0x01
	da A
	mov Min_counter,a
	sjmp Timer2_ISR_done

lthalfday:
	;increment Hour_counter
	mov a, Hour_counter
	add a, #0x01
	da A
	mov Hour_counter,a
	sjmp Timer2_ISR_done


Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov Sec_counter, a
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti


;for setting time
add_sec_time:
	; add one to hour counter when the hour button is pressed
	mov a, Sec_counter
	cjne a, #0x59, not_reset_sec
	clr A
	mov Sec_counter, a
	sjmp addtime_done
not_reset_sec:
	mov a, Sec_counter
	add a, #0x01
	da A
	mov Sec_counter, a
	sjmp addtime_done

add_min_time:
	; add one to min counter when the min button is pressed
	mov a, Min_counter
	cjne a, #0x59, not_reset_minute
	clr A
	mov Min_counter, a
	sjmp addtime_done
not_reset_minute:
	mov a, Min_counter
	add a, #0x01
	da A
	mov Min_counter, a
	sjmp addtime_done

add_hour_time:
	; add one to hour counter when the hour button is pressed
	mov a, Hour_counter
	cjne a, #0x11, not_reset_hour
	clr A
	mov Hour_counter, a
	sjmp addtime_done
not_reset_hour:
	mov a, Hour_counter
	add a, #0x01
	da A
	mov Hour_counter, a
	sjmp addtime_done
addtime_done:
	ret

;for setting alarm
add_min_alarm:
	; add one to min counter when the min button is pressed
	mov a, AMin_counter
	cjne a, #0x59, not_reset_minute_alarm
	sjmp addtime_done
not_reset_minute_alarm:
	mov a, AMin_counter
	add a, #0x01
	da A
	mov AMin_counter, a
	sjmp addtime_done

add_hour_alarm:
	; add one to hour counter when the min button is pressed
	mov a, AHour_counter
	cjne a, #0x59, not_reset_hour_alarm
	sjmp addtime_done
not_reset_hour_alarm:
	mov a, AHour_counter
	add a, #0x01
	da A
	mov AHour_counter, a
	sjmp addtime_done
toggle_am_pm:
	cpl AtoP_flag
	Set_Cursor(1, 15) ; change to where you are writing AM/PM
	jb AtoP_flag, write_pm
	Send_Constant_String(#Am_message)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	sjmp toggle_am_pm_done
write_pm:
	Send_Constant_String(#Pm_message)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	sjmp toggle_am_pm_done
toggle_am_pm_done:
	ret


;displaying the stuff on lcd
display:
    clr one_second_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
    clr one_hour_flag
	clr one_min_flag

	;displaying time
    Set_Cursor(1, 7)
    Display_BCD(Hour_counter) ; display hour
    Set_Cursor(1, 9)
    WriteData(#':')
    Set_Cursor(1, 10)
    Display_BCD(Min_counter) ; display min
    Set_Cursor(1, 12)
    WriteData(#':')
	Set_Cursor(1, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(Sec_counter) ; This macro is also in 'LCD_4bit.inc'
	Set_Cursor(1,15)
	jnb AtoP_flag, print_am ; if flag is 0, set to am, if 1 set to pm
	Send_Constant_String(#Pm_message)
print_am:
	Send_Constant_String(#Am_message)
	sjmp alarm_display

alarm_display:
	;display alarm
	Set_Cursor(2, 7)
    Display_BCD(AHour_counter) ; display hour
    Set_Cursor(2, 9)
    WriteData(#':')
    Set_Cursor(2, 10)
    Display_BCD(AMin_counter) ; display min
    Set_Cursor(2, 12)
    ;WriteData(#':')
	;Set_Cursor(2, 13)     ; the place in the LCD where we want the BCD counter value
	;Display_BCD(ASec_counter) ; 
	Set_Cursor(1,15)
	jnb AtoP_flag, print_am2 ; if flag is 0, set to am, if 1 set to pm
	Send_Constant_String(#Pm_message)
print_am2:
    Set_Cursor(2, 15)
	Send_Constant_String(#Am_message)
done_display:
	ret

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
          
    lcall Timer0_Init
    lcall Timer2_Init
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    Set_Cursor(2,1)
    Send_Constant_String(#Sec_line_message)
    
	Set_Cursor(1,15)
	Send_Constant_String(#Am_message) ; initalize to AM
	Set_Cursor(2,15)
	Send_Constant_String(#Am_message)
	setb one_second_flag
	setb one_min_flag
	setb one_hour_flag
	setb AtoP_flag
	;mov BCD_counter, #0x00
	mov Sec_counter, #0x00
	mov Min_counter, #0x00
	mov Hour_counter, #0x00

	;mov ASec_counter, #0x00
	mov AMin_counter, #0x00
	mov AHour_counter, #0x00
	
	; After initialization the program stays in this 'forever' loop
loop:
	;jb CLEAR_BUTTON, loop_a  ; if the 'CLEAR' button is not pressed skip
	;Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	;jb CLEAR_BUTTON, loop_a  ; if the 'CLEAR' button is not pressed skip
	;jnb CLEAR_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'CLEAR' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	;clr TR2                 ; Stop timer 2	
	;setting time, checking if botton pressed
	
	jb SET_TIME_BUTTON, set_time_mode
	Wait_Milli_Seconds(#50)
	jb SET_TIME_BUTTON, set_time_mode  
	jnb SET_TIME_BUTTON, $	
	cpl TR2    ; stop timer 2
	
set_time_mode:
	jb HOUR_BUTTON, no_hour_changed  ;changing hour
	Wait_Milli_Seconds(#50)	; 
	jb HOUR_BUTTON, no_hour_changed  ; 
	jnb HOUR_BUTTON, $
	lcall add_hour_time
	lcall display
no_hour_changed:
	jb MIN_BUTTON, no_minute_changed  
	Wait_Milli_Seconds(#50)	
	jb MIN_BUTTON, no_minute_changed  
	jnb MIN_BUTTON, $
	lcall add_min_time
	lcall display
no_minute_changed:
	jb SECOND_BUTTON, no_am_pm_changed
	Wait_Milli_Seconds(#50)	
	jb SECOND_BUTTON, no_am_pm_changed 
	jnb SECOND_BUTTON, $
	lcall add_sec_time
	lcall display
no_am_pm_changed:
	jb AM_PM_BUTTON, return_clock 
	Wait_Milli_Seconds(#50)	
	jb AM_PM_BUTTON, return_clock 
	jnb AM_PM_BUTTON, $
	lcall toggle_am_pm
	lcall display
return_clock:
	lcall display

;set_alarm_loop: ;check if button pressed
;	jb SET_ALARM_BUTTON, set_alarm
;	Wait_Milli_Seconds(#50)	 
;	jb ALARM_BUTTON, set_alarm  
;	jnb SET_ALARM_BUTTON, $
;	cpl alarm_flag
    ljmp loop

END
