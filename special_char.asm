; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet and datasheets.
$NOLIST
$MODN76E003
$LIST
org 0000H
ljmp myprogram
; N76E003 pinout:
; -------
; PWM2/IC6/T0/AIN4/P0.5 -|1 20|- P0.4/AIN5/STADC/PWM3/IC3
; TXD/AIN3/P0.6 -|2 19|- P0.3/PWM5/IC5/AIN6
; RXD/AIN2/P0.7 -|3 18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
; RST/P2.0 -|4 17|- P0.1/PWM4/IC4/MISO
; INT0/OSCIN/AIN1/P3.0 -|5 16|- P0.0/PWM3/IC3/MOSI/T1
; INT1/AIN0/P1.7 -|6 15|- P1.0/PWM2/IC2/SPCLK
; GND -|7 14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8 13|- P1.2/PWM0/IC0
; VDD -|9 12|- P1.3/SCL/[STADC]
; PWM5/IC7/SS/P1.5 -|10 11|- P1.4/SDA/FB/PWM1
; -------
;
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

clear_screen:  db '                ', 0

;
;for special character 
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

clear_bit:
    lcall ?WriteCommand
    mov a, #' '
    lcall ?WriteData
;---------------------------------;
; Main loop. Initialize stack, ;
; ports, LCD, and displays ;
; letters on the LCD ;
;---------------------------------;
myprogram:
mov SP, #7FH
; Configure the pins as bi-directional so we can use them as input/output
mov P0M1, #0x00
mov P0M2, #0x00
mov P1M1, #0x00
mov P1M2, #0x00
mov P3M2, #0x00
mov P3M2, #0x00
lcall LCD_4BIT
; mov a, #0x80 ; Move cursor to line 1 column 1
; lcall WriteCommand
; mov dptr, #name
; lcall Display_String

; mov a, #0xC0 ; Move cursor to line 2 column 1
; lcall WriteCommand
; mov dptr, #student_number
; lcall Display_String


;lcall scroll

; scroll:
; mov a, #0x18
; lcall WriteCommand
; mov a, #0x10
; lcall WriteCommand
; lcall WaitmilliSec
; sjmp scroll

forever:
lcall heart
mov a, #0x81
lcall ?WriteCommand
mov a, #0x01
lcall ?WriteData

lcall eighth
mov a, #0xC5
lcall ?WriteCommand
mov a, #2H
lcall ?WriteData

lcall bell
mov a, #0x88
lcall ?WriteCommand
mov a, #3H
lcall ?WriteData

lcall double_eighth
mov a, #0xCB
lcall ?WriteCommand
mov a, #4H
lcall ?WriteData

lcall heart
mov a, #0x8E
lcall ?WriteCommand
mov a, #5H
lcall ?WriteData

Wait_Milli_Seconds(#250)

Set_Cursor(1,1)
Send_Constant_String(#clear_screen)
Set_Cursor(2,1)
Send_Constant_String(#clear_screen)

lcall heart
mov a, #0xC2
lcall ?WriteCommand
mov a, #0x01
lcall ?WriteData

lcall eighth
mov a, #0x85
lcall ?WriteCommand
mov a, #2H
lcall ?WriteData

lcall bell
mov a, #0xC8
lcall ?WriteCommand
mov a, #3H
lcall ?WriteData

lcall double_eighth
mov a, #0x8B
lcall ?WriteCommand
mov a, #4H
lcall ?WriteData

lcall heart
mov a, #0xCE
lcall ?WriteCommand
mov a, #5H
lcall ?WriteData

Wait_Milli_Seconds(#250)

Set_Cursor(1,1)
Send_Constant_String(#clear_screen)
Set_Cursor(2,1)
Send_Constant_String(#clear_screen)

ljmp forever
END
