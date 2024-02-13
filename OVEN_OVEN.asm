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

;---------------------------------;
; Define any constant string here ;
;---------------------------------;
;                	  1234567890123456    <- This helps determine the location of the counter
To_Message:  	  db 'To=xxxC Tj=xxxC ', 0
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
main:

    Set_Cursor(1, 1)
    Send_Constant_String(#To_Message)
	Set_Cursor(2, 1)
    Send_Constant_String(#Time_temp_display)

END