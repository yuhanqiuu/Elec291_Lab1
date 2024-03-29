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
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

;---------------------------------;
; Define any buttons & pins here  ;
;---------------------------------;
SOUND_OUT   equ p1.7 ; speaker pin
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
org 0x002B
	ljmp Timer2_ISR

;---------------------------------;
; Define any constant string here ;
;---------------------------------;
;                	  1234567890123456    <- This helps determine the location of the counter
To_Message:  	  db 'To=xxxC Tj= 22C ', 0
Time_temp_display:db 'sxxx,xx rxxx,xx ', 0 ; soak temp,time reflow temp,time
Ramp_to_soak:	  db 'RampToSoak s=xxx', 0 ; state 1 display
Soak_display: 	  db 'Soak 		 s=xxx', 0 ; state 2 display
Ramp_to_peak: 	  db 'RampToPeak s=xxx', 0 ; state 3 display
Reflow_display:   db 'Reflow 	 s=xxx', 0 ; state 4 display
Cooling_display:  db 'Cooling 	 s=xxx', 0 ; state 5 display
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
start_stop_flag: dbit 1 ; Set to one if button is pressed to start, press again to stop
;---------------------------------------------

$NOLIST
$include(math32.inc)
$LIST

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
	inc seconds ; It is super easy to keep a seconds count here
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
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize the pins used by the ADC (P1.1, P1.7) as input.
	orl	P1M1, #0b10000010
	anl	P1M2, #0b01111101
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10000001 ; Activate AIN0 and AIN7 analog inputs
	orl ADCCON1, #0x01 ; Enable ADC
	
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

;---------------------------------;
; 	 5_pushbuttons function	      ;
;---------------------------------;
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
	cjne a, #0xF0, LCD_PB_Done
	mov soak_temp, #0x00
	sjmp LCD_PB_Done
increment_soak_time:
	inc soak_time
	mov a, soak_time
	cjne a, #0x78, LCD_PB_Done
	mov soak_time, #0x00
	sjmp LCD_PB_Done
increment_reflow_temp: 
	inc reflow_temp
	mov a, reflow_temp
	cjne a, #0xF0, LCD_PB_Done
	mov reflow_temp, #0x00
	sjmp LCD_PB_Done
increment_reflow_time:
	inc reflow_time
	mov a, reflow_time
	cjne a, #0x4B, LCD_PB_Done
	mov reflow_time, #0x00
	sjmp LCD_PB_Done

start_stop:
	cpl start_stop_flag
	sjmp LCD_PB_Done

;---------------------------------;
; Send a BCD number to PuTTY ;
;---------------------------------;
Send_BCD mac
push ar0
mov r0, %0
lcall ?Send_BCD
pop ar0
endmac
?Send_BCD:
push acc
; Write most significant digit
mov a, r0
swap a
anl a, #0fh
orl a, #30h
lcall putchar
; write least significant digit
mov a, r0
anl a, #0fh
orl a, #30h
lcall putchar
pop acc
ret

putchar:
jnb TI, putchar
clr TI
mov SBUF, a
ret

; We can display a number any way we want.  In this case with
; four decimal places.
Display_formated_BCD:
	Set_Cursor(1, 4) ; display To
	Display_BCD(bcd+3)
	Display_BCD(bcd+2) ;this is just in case temperatures exceed 100C and we're in deg F
	Set_Cursor(2,14)
	Display_BCD(seconds)

	;send the BCD value to the MATLAB script
	Send_BCD(bcd+3)
	Send_BCD(bcd+2)
	Send_BCD(bcd+1)
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	;Set_Cursor(1, 13)
	;Send_Constant_String(#22) ; display Tj=22
	ret

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

;-------------------------------------------------;
; Display values from the pushbutton to the LCD   ;
;-------------------------------------------------;

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


;-------------------------------------------------;
; Display all values and temperatures to the LCD  ;
;-------------------------------------------------;
Display_Data:
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
    
    ; Convert to voltage
	mov x+0, R0
	mov x+1, R1
	; Pad other bits with zero
	mov x+2, #0
	mov x+3, #0
	
	;lcall div32 ; Get V_out
	; ; Calculate Temp based on V_out
	; Load_y(27300) ; The reference temp K
	; lcall sub32 ; Get Temp*0.01
	; ; Change Temp*0.01 to Temp
	; Load_y(100)
	; lcall mul32

	Load_y(50300) ; VCC voltage measured (equals 4.99V)
	lcall mul32 ;multiplying ADC * Vref
	Load_y(4095) ; 2^12-1
	lcall div32 ;now doing (ADC*Vref)/(4095)
	
	Load_y(1000) ; for converting volt to microvolt
	lcall mul32 ;multiplying volts
	
	Load_y(10)
	lcall mul32
	
	;convert to temperature
	Load_y(23500) ;divide by the gain 
	lcall div32 
	Load_Y(41);load y = 41
	lcall div32 ;divide by 41
	
	Load_y(10000)
	lcall mul32
	
	Load_Y(220000) ;cold junction 19 deg C
	lcall add32

; Convert to BCD and display
	lcall hex2bcd
	lcall Display_formated_BCD

	reti

;-----------------------------------------------------------------------------;
;Grabs the value in register a and then compares it to the current temperature;
;-----------------------------------------------------------------------------;

Compare_temp:
	mov temp+0, bcd+2
	mov temp+1, bcd+3
	mov bcd+0, temp+0
	mov bcd+1, temp+1
	mov bcd+2,#0
	mov bcd+3,#0
	mov bcd+4,#0
	
	lcall bcd2hex
	
	mov y+0,x+0
	mov y+1,x+1
	mov y+2,x+2
	mov y+3,x+3
	
	mov x+0,a
	mov x+1,#0
	mov x+2,#0
	mov x+3,#0
	
	lcall hex2bcd
	lcall x_lteq_y

	reti

Wait_1sec:
	; Wait 500 ms between conversions
	mov R2, #250
	lcall waitms
	mov R2, #250
	lcall waitms
	; Wait 500 ms between conversions
	mov R2, #250
	lcall waitms
	mov R2, #250
	lcall waitms
	reti

main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT
    lcall Timer0_Init
    lcall Timer2_Init
    setb EA   ; Enable Global interrupts
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#To_Message)
	Set_Cursor(2, 1)
    Send_Constant_String(#Time_temp_display)
	
	mov seconds, #0
	mov soak_temp, #0x8C ;140
	mov soak_time, #0x3C ; 60
	mov reflow_temp, #0xE6 ; 230
	mov reflow_time, #0x1E ; 30
	mov FSM_state,#0
	setb TR2
    
;---------------------------------;
; 		FSM	funtion			      ;
;---------------------------------;
FSM:
    mov a, FSM_state
FSM_state0:
    cjne a, #0, FSM_state1
    mov pwm, #0 ; power variable
	lcall LCD_PB ; calls and checks the pushbuttons
	lcall Display_PushButtons_LCD ;Displays values in pushbuttons
    jnb start_stop_flag, FSM_state0_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #1   ; set FSM_state to 1, next state is state1
FSM_state0_done:
    ljmp FSM    ;jump back to FSM and reload FSM_state to a

FSM_state1:
    cjne a, #1, FSM_state2
    mov pwm, #100
    Set_Cursor(2, 1)
    Send_Constant_String(#Ramp_to_soak)
    clr c
    jnb start_stop_flag, stop_state ; checks the flag if 0, then means stop was pressed, if 1 keep on going
    mov a, #60
    subb a, seconds
    jc abort
continue:
    clr c   ; ! i don't know what is c
	lcall Display_Data
	mov a, soak_temp    ; set a to soak temp
	lcall Compare_temp
    jnb mf, FSM_state1_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #2
FSM_state1_done:
	lcall Wait_1sec
    ljmp FSM
abort:
    mov a, #0x32  ; set a to 50 degree
	lcall Display_Data
	lcall Compare_temp
	jb mf, continue ; if temp is larger then 50 degree, go back to continue
    mov FSM_state, #0   ; abort the FSM

stop_state:
    clr TR2
    jnb start_stop_flag, stop
	setb TR2
	ljmp FSM

stop:
    sjmp stop_state

FSM_state2:
    cjne a, #2, FSM_state3
    mov pwm, #20
    mov a, soak_time    ; set a to soak time
    Set_Cursor(2, 1)
    Send_Constant_String(#Soak_display)
    clr c   ; ! i don't know what is c 
	lcall Display_Data
    jnb start_stop_flag, stop_state ; checks the flag if 0, then means stop was pressed, if 1 keep on going
    subb a, seconds    ; temp is our currect sec
    jnc FSM_state2_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #3
FSM_state2_done:
	lcall Wait_1sec
    ljmp FSM

FSM_state3:
    cjne a, #3, FSM_state4
    mov pwm, #100
    Set_Cursor(2, 1)
    Send_Constant_String(#Ramp_to_peak)
    clr c   ; ! i don't know what is c 
    jnb start_stop_flag, stop_state ; checks the flag if 0, then means stop was pressed, if 1 keep on going
	lcall Display_Data
	mov a, reflow_temp    ; set a to reflow temp
	lcall Compare_temp
	
    jnb mf, FSM_state3_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #4
FSM_state3_done:
	lcall Wait_1sec
    ljmp FSM
	
intermediate_state_0:
	ljmp FSM_state0

intermediate_stop_jump:
	ljmp stop_state

FSM_state4:
    cjne a, #4, FSM_state5
    mov pwm, #20
    mov a, reflow_time    ; set a to reflow time
    Set_Cursor(2, 1)
    Send_Constant_String(#Reflow_display)
    clr c   ; ! i don't know what is c 
	lcall Display_Data
    jnb start_stop_flag, intermediate_stop_jump; checks the flag if 0, then means stop was pressed, if 1 keep on going
    subb a, seconds    ; temp is our currect sec
    jnc FSM_state4_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #5
FSM_state4_done:
	lcall Wait_1sec
    ljmp FSM

FSM_state5:
    cjne a, #5, intermediate_state_0
    mov pwm, #0
    
    Set_Cursor(2, 1)
    Send_Constant_String(#Cooling_display)
    clr c   ; ! i don't know what is c
    jnb start_stop_flag, intermediate_stop_jump ; checks the flag if 0, then means stop was pressed, if 1 keep on going 
	lcall Display_Data
	mov a, #0x3C    ; set a to 60
	lcall Compare_temp

    jb mf, FSM_state5_done
    mov seconds, #0     ; set time to 0
    mov FSM_state, #0
FSM_state5_done:
	lcall Wait_1sec
    ljmp FSM
END