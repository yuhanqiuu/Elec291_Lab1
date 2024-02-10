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
;!!!!!arbiturary value for now
START_STOP  equ p1.3 ; start/stop button
INCREMENT   equ p1.5 ; increment button
DECREMENT   equ p1.6 ; decrement button
SWITCH_MODE equ p1.7 ; switch stting mode: soak temp -> soak time -> reflow temp -> reflow time
SOUND_OUT   equ p3.0 ; speaker pin
;---------------------------------------------
ORG 0x0000
	ljmp main

;---------------------------------;
; Define any constant string here ;
;---------------------------------;
;                1234567890123456    <- This helps determine the location of the counter
To_Message:  db 'To=xxxC Tj= xxC', 0
Time_temp_display:db 'sxxx,xx rxxx,xx', 0 ; soak temp,time reflow temp,time
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
;---------------------------------------------

;---------------------------------;
; Define flags here               ;
;---------------------------------;
BSEG
mf: dbit 1
s_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
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
clr TF2 ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR. It is
bit addressable.
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
	
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
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
; Send a BCD number to PuTTY      ;
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

; We can display a number any way we want.  In this case with
; four decimal places.
Display_formated_BCD:
	Set_Cursor(2, 10)
	Display_BCD(bcd+2)
	Display_char(#'.')
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	Set_Cursor(2, 10)
	;Display_char(#'=')
	ret

Read_ADC:
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRL
    anl a, #0x0f
    mov R0, a
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, R0
    mov R0, A
	ret

;-------------------------------------------------;
; Display all values and temperatures to the LCD  ;
;-------------------------------------------------;
Display_Data:
	; Read the 2.08V LED voltage connected to AIN0 on pin 6
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0

	lcall Read_ADC
	; Save result for later use
	mov VLED_ADC+0, R0
	mov VLED_ADC+1, R1

	; Read the signal connected to AIN7
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	lcall Read_ADC
    
    ; Convert to voltage
	mov x+0, R0
	mov x+1, R1
	; Pad other bits with zero
	mov x+2, #0
	mov x+3, #0
	Load_y(20740) ; The MEASURED LED voltage: 2.074V, with 4 decimal places
	lcall mul32 ; Get ADC * V_ref
	; Retrive the ADC LED value
	mov y+0, VLED_ADC+0
	mov y+1, VLED_ADC+1
	; Pad other bits with zero
	mov y+2, #0
	mov y+3, #0
	lcall div32 ; Get V_out
	; Calculate Temp based on V_out
	Load_y(27300) ; The reference temp K
	lcall sub32 ; Get Temp*0.01
	; Change Temp*0.01 to Temp
	Load_y(100)
	lcall mul32

	; Convert to BCD and display
	lcall hex2bcd
	lcall Display_formated_BCD
	Send_BCD(bcd+4)
	Send_BCD(bcd+3)
	Send_BCD(bcd+2)
	mov a, #'.' ; I am guessing the decimal point is here...
	lcall putchar
	Send_BCD(bcd+1)
	Send_BCD(bcd+0)
	mov a, #'\r' ; Return character
	lcall putchar
	mov a, #'\n' ; New-line character
	lcall putchar
	
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
	
	mov Sec_counter, #0x00
	mov soak_temp, #0x140
	mov soak_time #0x60
	mov reflow_temp, #0x230
	mov reflow_time, #0x30
	setb TR2
    
Forever: ; states and main loop stuff

	ljmp Forever
END