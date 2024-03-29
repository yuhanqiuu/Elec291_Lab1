; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet and datasheets.
$NOLIST
$MODN76E003
$LIST

org 0000H
    ljmp myprogram

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

; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

; When using a 16.6MHz oscillator in the N76E003
; one cycle takes 1.0/16.6MHz = 60.24 ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
    push AR0
    mov R0, #133
L0:
    nop
    djnz R0, L0 ; 1+4 cycles->5*60.24ns*133=40us
    pop AR0
    ret

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
WaitmilliSec:
    push AR0
    push AR1
L3: mov R1, #40
L2: mov R0, #104
L1: djnz R0, L1 ; 4 cycles->4*60.24ns*104=25.0us
    djnz R1, L2 ; 25us*40=1.0ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret

;---------------------------------;
; Toggles the LCD's 'E' pin       ;
;---------------------------------;
LCD_pulse:
    setb LCD_E
    lcall Wait40uSec
    clr LCD_E
    ret

;---------------------------------;
; Writes data to LCD              ;
;---------------------------------;
WriteData:
    setb LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes command to LCD           ;
;---------------------------------;
WriteCommand:
    clr LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
    ; Write high 4 bits first
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse

    ; Write low 4 bits next
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
    lcall LCD_pulse
    ret

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
    clr LCD_E   ; Resting state of LCD's enable is zero
    ; clr LCD_RW  ; Not used, pin tied to GND

    ; After power on, wait for the LCD start up time before initializing
    mov R2, #40
    lcall WaitmilliSec

    ; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x32 ; change to 4-bit mode
    lcall WriteCommand

    ; Configure the LCD
    mov a, #0x28
    lcall WriteCommand
    mov a, #0x0c
    lcall WriteCommand
    mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand

    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    lcall WaitmilliSec
    ret
    
;---------------------------------;
;Creates a custom character(s)    ;
;and stores it in CGRAM           ;
;---------------------------------;
 customchar:
 ;a funny face
 	mov a, #48H
 	lcall WriteCommand
 	mov a, #0x0
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0x0
 	lcall WriteData
 	mov a, #0x10
 	lcall WriteData
 	mov a, #0x10
 	lcall WriteData
 	mov a, #0xe
 	lcall WriteData
 	mov a, #0x0
 	lcall WriteData
 	mov a, #0x0
    lcall WriteData 
    
;top pillar
 	mov a, #50H
 	lcall WriteCommand
 	mov a, #0x1f
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
    lcall WriteData 
    
 ;bottom pillar
 	mov a, #58H
 	lcall WriteCommand
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xa
 	lcall WriteData
 	mov a, #0xe
 	lcall WriteData
 	mov a, #0x1f
 	lcall WriteData
 	mov a, #0x0
 	lcall WriteData
 	
 	ret
 ;custom character code derived from
 ;https://www.8051projects.net/lcd-interfacing/lcd-custom-character.php
 
 my_name: DB 'Huy Huynh' ,0 
 disappear: DB '             ',0  
 student_num: DB '50417435' ,0  
;---------------------------------;
; Prints the contents of a string ;
; onto a line    			      ;
;---------------------------------;
PrintString:
	lcall WaitmilliSec
    mov     a, r3
    movc    a, @a+dptr   ; Get character of the string
    jz      Done         ; Jumps if a==0
    lcall WriteData
    inc     r3
    sjmp    PrintString
  
Done:
    ret
;string code sample derived from 
;https://stackoverflow.com/questions/64343538/moving-strings-into-register-with-a-loop-8051-assembly  	

;---------------------------------;
; Makes characters in the 		  ;
; first line of the LCD disappear ;
; and reappear                    ;
;---------------------------------;
LCD_flash:
	;make name disappear
	mov r3, #0 ;reset r3
	mov a, #0x81 ; Move cursor to line 1 column 2
    lcall WriteCommand
    mov dptr, #disappear
    lcall PrintString
    
    lcall WaitmilliSec
    
    ;now make it reappear
    mov r3, #0 ;reset r3
    mov a, #0x81 ; Move cursor to line 1 column 2
    lcall WriteCommand
    mov dptr, #my_name
    lcall PrintString
    
    ret
    
;---------------------------------;
;Makes characters in the first    ;
;line of the LCD scroll left      ;
;until r4 is decremented to 0     ;
;---------------------------------;
LCD_scroll:
	lcall WaitmilliSec
	mov a, #0x18 ;set LCD to scroll left
	lcall WriteCommand
	dec r4
	cjne r4, #0, LCD_scroll
		
	scroll_complete:
	ret
	
;---------------------------------;
; Main loop.  Initialize stack,   ;
; ports, LCD, and displays        ;
; letters on the LCD              ; 
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
    
    mov r2, #255 ;set millisecond counter
    mov r3, #0 ;reset r3
    mov r4, #40 ;value of r4 determines how many times the LCD will scroll when LCD_scroll is called
    lcall LCD_4BIT
    
    ;print the special characters
    lcall customchar
    mov a, #0x80 ;Move cursor to line 1 column 1
    lcall WriteCommand
    mov a,#2H ; For pattern @50H
    lcall WriteData 
    
    mov a, #0xC0 ;Move cursor to line 1 column 0
    lcall WriteCommand
    mov a,#3H ; For pattern @58H
    lcall WriteData 
    
    mov a, #0xCF ;Move cursor to line 2 column 16
    lcall WriteCommand
    mov a,#3H ; For pattern @58H
    lcall WriteData 
    
    mov a, #0x8F ;Move cursor to line 1 column 16
    lcall WriteCommand
    mov a,#2H ; For pattern @50H
    lcall WriteData 
    
    mov a, #0x8B ;Move cursor to line 1 column 11
    lcall WriteCommand
    mov a,#1H ; For pattern @48H
    lcall WriteData 
    
    ;Print name and student number
    mov a, #0x81 ; Move cursor to line 1 column 2
    lcall WriteCommand
    mov dptr, #my_name
    lcall PrintString
    
    mov r3, #0 ;reset r3
    mov a, #0xC1 ; Move cursor to line 2 column 1
    lcall WriteCommand
    mov dptr, #student_num
    lcall PrintString
	
	lcall LCD_flash
	lcall LCD_scroll
	
forever:
    sjmp forever
  
END
