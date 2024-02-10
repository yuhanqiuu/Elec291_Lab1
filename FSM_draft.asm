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

reflow_time: ds 1 ; time parameter for reflow	
reflow_temp: ds 1 ; temp parameter for reflow
soak_time: ds 1 ; time parameter for soak
soak_temp: ds 1 ; temp parameter for soak
FSM_state: ds 1 ; state variable
pwm: ds 1
pwm_counter: ds 1

START_STOP: dbit 1
SWTICH_MODE: dbit 1
INCRE: dbit 1
DECRE: dbit 1

state0: "state 0",0
state1: "state 1",0
state2: "state 2",0
state3: "state 3",0
state4: "state 4",0
state5: "state 5",0

FSM:
    mov a, FSM_state
FSM_state0:
    cjne a, #0, FSM_state1
    mov pwm, #0 ; power variable
    Send_Constant_String(#state0)

    jb INCRE, increase ; if the if INCREMENT button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.
	jb INCRE, increase  ; if the 'CLEAR' button is not pressed skip
	jnb INCRE, $
increase:

    jb START_STOP, FSM_state0_done
    jnb START_STOP, $   ; wait for key release
    mov FSM_state, #1   ; set FSM_state to 1, next state is state1
FSM_state0_done:
    ljmp FSM    ;jump back to FSM and reload FSM_state to a

FSM_state1:
    cjne a, #1, FSM_state2
    mov pwm, #100
    mov sec, #0     ; set time to 0
    Send_Constant_String(#state1)
    clr c
    
    mov a, #0x60
    subb a, seconds
    jc abort
continue:
    clr c   ; ! i don't know what is c
    mov a, soak_temp    ; set a to soak temp
    subb a, temp    ; temp is our currect temp
    jnc FSM_state1_done
    mov FSM_state, #2
FSM_state1_done:
    ljmp FSM
abort:
    mov a, #50  ; set a to 50 degree
    subb a, temp
    jc continue     ; if temp is larger then 50 degree, go back to continue
    mov FSM_state, #0   ; abort the FSM
    
FSM_state2:
    cjne a, #2, FSM_state3
    mov pwm, #20
    mov a, soak_time    ; set a to soak time
    Send_Constant_String(#state2)
    clr c   ; ! i don't know what is c 
    subb a, sec    ; temp is our currect sec
    jnc FSM_state2_done
    mov FSM_state, #3
FSM_state2_done:
    ljmp FSM

FSM_state3:
    cjne a, #3, FSM_state4
    mov pwm, #100
    mov sec, #0     ; set time to 0
    mov a, reflow_temp    ; set a to reflow temp
    Send_Constant_String(#state3)
    clr c   ; ! i don't know what is c 
    subb a, temp    ; temp is our currect temp
    jnc FSM_state3_done
    mov FSM_state, #4
FSM_state3_done:
    ljmp FSM

FSM_state4:
    cjne a, #4, FSM_state5
    mov pwm, #20
    mov a, reflow_time    ; set a to reflow time
    Send_Constant_String(#state4)
    clr c   ; ! i don't know what is c 
    subb a, sec    ; temp is our currect sec
    jnc FSM_state4_done
    mov FSM_state, #5
FSM_state4_done:
    ljmp FSM

FSM_state5:
    cjne a, #5, FSM_state0
    mov pwm, #0
    mov sec, #0     ; set time to 0
    mov a, #60    ; set a to 60
    Send_Constant_String(#state5)
    clr c   ; ! i don't know what is c 
    subb temp, a    ; temp is our currect temp
    jnc FSM_state5_done
    mov FSM_state, #0
FSM_state5_done:
    ljmp FSM