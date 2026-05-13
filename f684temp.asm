;**********************************************************************
;   This file is a basic code template for assembly code generation   *
;   on the PICmicro PIC16F684. This file contains the basic code      *
;   building blocks to build upon.                                    *  
;                                                                     *
;   If interrupts are not used all code presented between the ORG     *
;   0x004 directive and the label main can be removed. In addition    *
;   the variable assignments for 'w_temp' and 'status_temp' can       *
;   be removed.                                                       *                         
;                                                                     *
;   Refer to the MPASM User's Guide for additional information on     *
;   features of the assembler (Document DS33014).                     *
;                                                                     *
;   Refer to the respective PICmicro data sheet for additional        *
;   information on the instruction set.                               *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Filename:	    xxx.asm                                           *
;    Date:            7/16/05                                         *
;    File Version:                                                    *
;                                                                     *
;    Author:   Wayne Sankey                                           *
;    Company:                                                         *
;                                                                     * 
;                                                                     *
;**********************************************************************
;                                                                     *
;    Files required:                                                  *
;                                                                     *
;                                                                     *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Notes:                                                           *
;                                                                     *
;
; 4/12/06 changed the mappings for the displays since the boards were
; laid out wrong. What is with me and board output mappings on this
; project ????
;
;
;
; Things to do:   4/13/06
; 1) the board does not have the LEDs for the mute/select the same as
;    the relay connections !!!  (how did I manage to do that !?!?
;    Need to add a function to figure out one from the other.
;    Update: 7/2/06 Don't bother, the LED connections are all on the board
;    I will fix this by getting the wiring on the board to be the opposite
;    of the software mix-up and it will work OK.
;    Update: see item 11 below.  It's fixed.
;
; 2) debounce seems to not be working properly - maybe add more debounce
;    functionality.
;    5/8/06: IDEA - hey why not just use the interrupt as the timer. Then
;    just poll for the input value change.  Accept 3 values the same as an
;    input change. That should make things a lot simpler for coding too. 
;
;
;    Done 5/21/06 but not tested yet.
;    UPDATE 6/4/06: Fixed and tested.
; 3) the volume is not pegging at 63 and it doesn't go back to 0 if it
;    ever gets above 63 - so add theres a fix and an addition.
;    5/8/06: IDEA - is the 63 being used as an address instead of a literal
;    value ??? If so, that's wrong because the compare instruction takes the
;    value contained in register 63, not the number 63 !!!!!!
;    OH - this is it !!!! Look for a register called max_volume and it shows
;    up at address 0x3F.  Just need to figure out how to load 0x3F into that
;    register and I think the volume pegging will then work.
;
; 4) Comment out the shutdown code - it isn't used since the board does not
;    detect shutdown.
;    UPDATE 6/2/06: a shutdown isn't needed anyhow because the amp has so much
;    energy storage the amp is still running long after the controller has
;    disconnected everything, so it MAY be OK. The only thing left is that we
;    want the output relays to go inactive first otherwise we could get loud
;    sounds on shutdown.  Have to see what happens in the real amp. Maybe you'd
;    want to turn on MUTE and then turn off the amp.
;
;    
; 5) The amp takes half of forever to start up - so lengthen the time that the
;    outputs are muted and the output caps are in quick-drain configuration.
;    Done: 5/21/06
;
;
;
; 6) The relays are responding to input changes while the the unit is in power-up
;    mode. Need to shut down the input response while the timer is running !!!!!
;    Maybe this is why the debounce isn't working also !?!?!?!?!?!?! That would
;    be nice - to get two fixes with one.  The inputs are intended to be shut while
;    the timer is running if I remember correctly.
;    6/2/06 UPDATE followed the code thru and it's the call to delay_10m reopening
;    the PORT A interrupt at the end of its execution that is causing the inputs to
;    control the amp when it is not desired.
;    6/1/06
;    6/4/06 UPDATE: Fixed. The inputs are now polled for changes.
;
;
;
; 7) The MUTE LED control is inverted. When Mute is ON you want the relay to be not
;    energized = the relay control bit is "0" and the LED to be energized = the LED
;    bit = 1.  The relay is OK, it's the LED bit that needs to be inverted.
;    7/2/06 UPDATE: Fixed, but not tested. The LED/relay for the mute is the msb of the
;    select and select_leds registers, so just calc select, load into select_leds, then
;    invert the msb. This is done by XOR'ing with 0x80: A XOR 1 = A bar; A XOR 0 = A.
;
;
; 8) 6/4/06
;    The debounce is getting in the way.  If you turn the control quickly, it gets lost,
;    and doesn't accept input value changes. I suspect that if I set the debounce to a
;    lower amount of time it will work better.
;    UPDATE: 6/7/06: changed the debounce period from 10ms x2 to 3ms x2 and it is much
;    much better in feel - no apparent errors in detecting input changes and it no longer
;    gets lost with quick input changes.
;
;
;
; 9) There is a heck of a pop when the msb changes. Need to look into this....
;    Relay operate time is 4 ms, release time is 3 ms.
;    pop happens when going up and down in volume
;    pop is worst for the msb transition (again, both ways - what does that mean???)
;    If the pop was due to the msb transitioning first - meaning full volume for a second
;    before release of the 2nd msb and lower...... hmmmmm how could it be a pop both ways?
;    Ideas:
;    a) go to 0 volume for a short period then new volume - try this first.
;    6/6/06: There is a blanking of the relays and then they are loaded up from lsb
;    to msb one by one.  Gives a kind of blanking sound when changing volume that I don't
;    much like but the pop is completely gone.
;
;
; 10) The MUTE function is not yet coded.
;     Update 7/4/06: Done. Works except the mute is not evaluated when the startup proedure
;     is complete. See item 12 below.
;
;
; 11) The board connections to the select LEDs are not as they were supposed to be so I'm
;    going to fix it here. Cant really fix on board because the mute LED is involved also.
;     For the select LEDs, need to shift to most significant side one bit.
;     For the mute LED, need to get it from msb to third bit from lsb.
;     UPDATE: 7/4/06 Added a subroutine to figure the LED settings based on the relay
;     settings, it undoes all the mess from the board.
;
; 12) When the startup procedure is complete, the code should evaluate the setting of the
;     MUTE switch instead of just releasing the mute.
;     Update: 7/8/06. Done.
;
;
;
; program flow:

; initialize the internal clock to 1 MHz
; set the watchdog to 1s
; run the mute routine - wait 3s then release mute
; begin with volume at 0 ? or some low level ?
; loop on read of inputs forever

; if an input changes:
; first see if it was the volume input - if so, run the volume change
;  routine then update the outputs then return
; second see if it was the balance input - if so, run the balance change
;  routine then update the outputs then return
; third see if it was an input select input that changed and if so,
; run the input select routine, then update the outputs then return.

;                                                                     *
;                                                                     *
;                                                                     *
;**********************************************************************


	list		p=16f684		; list directive to define processor
	#include	<P16F684.inc>		; processor specific variable definitions
	
	__CONFIG    _CP_OFF & _CPD_OFF & _BOD_OFF & _PWRTE_ON & _WDT_OFF & _INTOSCIO & _MCLRE_OFF & _FCMEN_OFF & _IESO_OFF


; '__CONFIG' directive is used to embed configuration data within .asm file.
; The labels following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.

; Look at section 12.1 of PIC16F684 manual....
; want Code Protection bit disabled  _CP_OFF
; want Data Code Protection bit disabled _CPD_OFF
; want Brown Out Detect disabled _BOD_OFF
; want Power-Up Timer Enable bit enabled  _PWRTE_ON
; want Watchdog Timer Enable bit disabled _WDT_OFF
; want Oscillator Selection bits to I/O on both pins _INTOSCIO
; want MCLR input to be I/O _MCLRE_OFF
; want Failsafe Clock Monitor Enabled bit disabled _FCMEN_OFF
; want Internal External Switchover bit disabled _FCMEN_OFF






;***** VARIABLE DEFINITIONS
w_temp		EQU	0x71			; variable used for context saving
status_temp	EQU	0x72			; variable used for context saving

; bank 1 register address definitions
temp_1_0    EQU 0xa0

; bank 0 register address definitions
temp8       EQU 0x20
loop_count  EQU 0x21
write_reg_c EQU 0x22

last_porta  EQU 0x23
current_porta EQU 0x24
bit_change  EQU 0x25
timer1_loop_test EQU 0x26
bin_old     EQU 0x28
bin_new     EQU 0x29
gray_value  EQU 0x2A
binary_value EQU 0x2B
temp1        EQU 0x2C
temp2        EQU 0x2D

left_vol    EQU 0x30       ; volume level currently used 0 to max_volume
right_vol   EQU 0x31
select      EQU 0x32
select_leds EQU 0x33

table_left_vol   EQU 0x34  ; volume level that is loaded into the relays (after lookup table)
table_right_vol  EQU 0x35
volume_setting   EQU 0x36  ; used to pass the volume for lookup

display_left_low  EQU 0x37
display_left_high EQU 0x38
display_right_low EQU 0x39
display_right_high EQU 0x3A
display_volume_flag EQU 0x3B  ; if 0 dont display volume - if 1 display volume

; constants used in the code - see the lookup table at the end of the program 
max_volume         EQU 0x3C             ; number of entries in the lookup table

porta_delay_1    EQU 0x40
porta_delay_2    EQU 0x41
porta_delay_3    EQU 0x42

portc_delay_1    EQU 0x43
portc_delay_2    EQU 0x44
portc_delay_3    EQU 0x45

right_volume_relays   EQU 0x46
left_volume_relays    EQU 0x47

temp_sel_leds     EQU  0x48
current_portc     EQU  0x49
eval_mute         EQU  0x4A
temp_mute         EQU  0x4B


; addresses of the data EEPROM that are used
eeprom_select_address      EQU 0x00
eeprom_left_vol_address    EQU 0x01
eeprom_right_vol_address   EQU 0x02

; values to read which tell how to light up the 7-segment displays
ee_display_0_add   EQU 0x03
ee_display_1_add   EQU 0x04
ee_display_2_add   EQU 0x05
ee_display_3_add   EQU 0x06
ee_display_4_add   EQU 0x07
ee_display_5_add   EQU 0x08
ee_display_6_add   EQU 0x09
ee_display_7_add   EQU 0x0a
ee_display_8_add   EQU 0x0b
ee_display_9_add   EQU 0x0c
ee_display_p_add   EQU 0x0d
ee_display_u_add   EQU 0x0e
ee_display_d_add   EQU 0x0f




; output definitions:


; 8-bit shift register first to be written at output port (farthest in daisy chain)
; bit 7: mute LED
; bit 6: input select 5 LED (single-ended)
; bit 5: input select 4 LED (single-ended)
; bit 4: input select 3 LED (balanced)
; bit 3: input select 2 LED (balanced)
; bit 2: input select 1 LED (balanced)
; bit 1: unused
; bit 0: unused;

; 8-bit shift register second to be written at output port
; bit 7: mute relay   (this bit is active = relay is energized = the relay is closed = MUTE is off)
; bit 6: input select 5 relay (single-ended)
; bit 5: input select 4 relay (single-ended)
; bit 4: input select 3 relay (balanced)
; bit 3: input select 2 relay (balanced)
; bit 2: input select 1 relay (balanced)
; bit 1: unused
; bit 0: unused


; 8-bit shift register third to be written at output port
; bits [7:0]: right volume relays (msb:lsb on volume board schematic)


; 8-bit shift register fourth to be written at output port
; bits [7:0]: left volume relays (msb:lsb on volume board schematic)

; 8-bit shift register fourth to be written at output port
; bits [7:0]: 

; 8-bit shift register fourth to be written at output port
; bits [7:0]: 

; 8-bit shift register fourth to be written at output port
; bits [7:0]: 

; 8-bit shift register fourth to be written at output port
; bits [7:0]: 



;**********************************************************************
	ORG		0x000		    	; processor reset vector
  	goto		main			; go to beginning of program


; here's the interrupt service routine - the only interrupt that is recognized
; is the timer.  The control input changes are polled.
	ORG 0x004
	movwf		w_temp			; save off current W register contents
	movf		STATUS,w		; move status register into W register
	movwf		status_temp		; save off contents of STATUS register

	bcf STATUS, RP0                      ; bank 0
	btfss PIR1, TMR1IF                   ; test to see if timer1 was the reason for the interrupt
	goto end_interrupt
	goto timer1_isr

end_interrupt

	movf		status_temp,w		; retrieve copy of STATUS register
	movwf		STATUS			; restore pre-isr STATUS register contents
	swapf		w_temp,f
	swapf		w_temp,w		; restore pre-isr W register contents
	retfie





; here's the entry of the program execution
	ORG 0x20
main
	call initialize_device                ; set the clock to 1 MHz, use internal clock, etc

	call initialize_outputs               ; the mute is on, set the other inputs as sppropriate		
	call update_outputs                   ; get the initial values into the relays

	call mute_delay                       ; wait some time to release mute
	call initialize_volume                ; set volume to last used, mute still on, select last input
	call update_outputs

	call delay_1s                         ; adjust this delay to achieve desired effect at startup

	call release_mute                     ; turn the mute off, display will have volume
	call update_outputs

	call open_interrupts
main_loop                                 ; do nothing now, the interrupt takes care of input changes at PORTA
	nop
	nop
	nop	
	call delay_3ms                        ; polling delay is 3 ms
	nop
	call update_porta_values
	call input_change_porta
	call update_portc_values
	call input_change_portc
	nop
	nop
	goto main_loop


; a power loss has been detected, shut down the amp.  If this runs by accident, the controller will
; be locked out, so you have to do a complete power cycle of the amp so that the CPU resets.
; The display will be loaded with "Pd" so that you have an indication the amp is shutting down.
;power_down
;	bcf STATUS, RP0                        ; bank 0
;	clrf INTCON                            ; disable all the interrupts
;
;	bcf STATUS, RP0                        ; bank 0
;	movf left_vol, W                       ; write to the data EEPROM the current left volume
;	bsf STATUS, RP0                        ; bank 1
;	movwf EEDAT                            ; the next time the amp is powered, it will have this volume
;	movlw eeprom_left_vol_address
;	movwf EEADR
;	clrf EECON1
;	bsf EECON1, WREN 
;	bcf INTCON, GIE
;	movlw 0x55
;	movwf EECON2
;	movlw 0xaa
;	movwf EECON2
;	bsf EECON1, WR
;	bcf EECON1, WREN
;	
;	bcf STATUS, RP0                        ; bank 0
;	movf right_vol, W                      ; write to the data EEPROM the current right volume
;	bsf STATUS, RP0                        ; bank 1
;	movwf EEDAT                            ; the next time the amp is powered, it will have this volume
;	movlw eeprom_right_vol_address
;	movwf EEADR
;	clrf EECON1
;	bsf EECON1, WREN 
;	bcf INTCON, GIE
;	movlw 0x55
;	movwf EECON2
;	movlw 0xaa
;	movwf EECON2
;	bsf EECON1, WR
;	bcf EECON1, WREN
;
;	movlw 0x00                             ; shut off all inputs and turn on mute (relay not energized, goes open)
;	movwf select
;	movwf select_leds
;	movwf left_vol
;	movwf right_vol
;
;	clrf display_volume_flag               ; set off flag so that display doesn't put volume
;	bsf STATUS, RP0          ; bank 1
;	movlw ee_display_p_add                 ; write Pd into the display registers
;	movwf EEADR              
;	clrf EECON1
;	bsf EECON1, RD
;	movf EEDAT, W
;	bcf STATUS, RP0          ; bank 0
;	movwf display_left_high
;	movwf display_right_high
;	bsf STATUS, RP0          ; bank 1
;	movlw ee_display_d_add
;	movwf EEADR              
;	clrf EECON1
;	bsf EECON1, RD
;	movf EEDAT, W
;	bcf STATUS, RP0          ; bank 0
;	movwf display_left_low
;	movwf display_right_low
;	call update_outputs
;
;power_down_loop
;	nop
;	nop
;	nop
;	goto power_down_loop


; This is the routine that handles input port A changing value and being stable.
; If there is a valid change to evaluate, bit_change is non-zero.
input_change_porta



; IDEA: 4/10/06:  There seems to be some trouble with debouncing... because in operation when turning
; the encoders quickly (doesn't matter which one) there is a tendency to sometimes get lost. So try
; something in here where you check what the new state is, then wait 10 ms more, then check again and
; if the two values are the same, go thru the routine.  Another thing to look for is that the interrupts
; are turned off correctly when servicing the routine.
; I think that since there is cross-control effects, maybe there is a problem here.

; first see that there was a valid change to evaluate and if not just escape out.
	bcf STATUS, RP0                      ; bank 0
	movlw 0x00
	iorwf bit_change, W                  ; update the Z flag, skip to end if bit_change is 0.
	btfsc STATUS, Z
	goto escape1

; from here to label "escape" is a case statement - the branches all recombine for the
; retrun from this function call

	rrf bit_change, F	                 ; if one of the 2 lsbs of bit_change is 1, that's a volume control change
	btfsc STATUS, C
	goto calculate_volume
	rrf bit_change, F	
	btfsc STATUS, C
	goto calculate_volume

	rrf bit_change, F	                 ; if one of the next 2 bits is 1, that's a balance control change
	btfsc STATUS, C
	goto calculate_balance
	rrf bit_change, F	
	btfsc STATUS, C
	goto calculate_balance

	goto calculate_selector              ; otherwise it's a selector change

escape                                   ; all the branches above have to recombine here - so use goto's at the end
	nop
	bcf STATUS, RP0
	movf current_porta, W
	movwf last_porta

escape1
	nop
	return



; This is the subroutine that evaluates the setting of the mute switch, if flag
; eval_mute is set to 1. Otherwise it does nothing.
input_change_portc

	btfss eval_mute, 0   ; skip this if the debounce had changes being made
	goto recombine_mute

	movf select, W
	movwf temp_mute      ; get the current select register setting - mute is msb
	rlf temp_mute, F     ; rotate left twice to get mute bit into lsb
	rlf temp_mute, F
	movlw 0x01           ; and now blank out the rest of the register
	andwf temp_mute, F
	movf temp_mute, W       ; XOR the current mute setting with the saved mute setting from select variable 
	xorwf portc_delay_1, W
	btfsc STATUS, Z         ; if the XOR is 0 then there is no change
	goto recombine_mute

    movf portc_delay_1, W  	; got to here so there was a change. Make change to select variable
	movwf temp_mute         ; get temp_mute msb to have current mute input setting
	rrf temp_mute, F
	rrf temp_mute, F
	movlw 0x80
	andwf temp_mute, F
	movlw 0x7F              ; blank the msb of select = mute bit
	andwf select, F
	movf temp_mute, W
	iorwf select, F         ; OK, the select variable msb is now updated !!!   
    
	call load_select_leds   ; update the LED variable, load the new value into the relays and LEDs...
	call update_outputs

recombine_mute
	return


; this is the ISR for timer1.
; there is only one way initially that this interrupt can happen - but its coded so that other
; uses for timer1 could be added quite easily here also.
timer1_isr
	bcf STATUS, RP0                     ; bank 0
	bcf timer1_loop_test, 0             ; clear the flag to end infinite loop in wait subroutine
	clrf PIR1                           ; clear all the interrupt flags
	clrf PIE1                           ; clear all the interrupt enables
	goto end_interrupt


; set the clock to 1 MHz, internal
; First wait until the HFOSC is stable, (OSCCON register, HTS bit = 1) then set to 1 MHz.
; Note that the FOSC bits in the config register are set to INTOSCIO which means internal oscillator
initialize_device
	bsf STATUS, RP0         ; select bank 1
;wait_here                   ; loop until the high speed oscillator is stable
;	btfss OSCCON, HTS
;	goto wait_here

	bsf OSCCON, SCS         ; use internal oscillator
	bcf OSCCON, IRCF0       ; oscillator now 1 MHz
	bcf OSCCON, IRCF1
	bsf OSCCON, IRCF2

; shut down the interrupts so that we don't go there while booting the device
	bcf STATUS, RP0         ; bank 0
	clrf INTCON


; initialize PORTA
	bsf STATUS, RP0         ; bank 1
	movlw 0x3F
	movwf TRISA             ; make PORTA all inputs
;	movwf IOCA              ; enable interrupt-on-change
	clrf WPUA               ; disable the weak pullups, there are pullups on the board
	bcf STATUS, RP0         ; bank 0
    clrf PORTA

; initialize PORTC
	bsf STATUS, RP0         ; bank 1
	movlw 0xF0
	movwf TRISC
	clrf ANSEL
	bcf STATUS, RP0         ; bank 0
	movlw 0xFF
	movwf CMCON0
	clrf PORTC
	movlw 0x08
	movwf PORTC

; get the starting value for the PORT A inputs because it's needed the first time an input
; is changed otherwise you get garbage results for the first input change.
	bcf STATUS, RP0                      ; bank 0
	movf PORTA, W                        ; save off the new state of PORTA
	movwf last_porta
	movwf current_porta
	movwf porta_delay_1
	movwf porta_delay_2
	movwf porta_delay_3


; get the maximum volume allowed into the max_volume register, the max allowed is
; 63 decimal, gives 64 volume levels that are encoded in the lookup table.
	bcf STATUS, RP0         ; bank 0
	movlw 0x3F              ; 63 decimal is the max volume
	movwf max_volume

	return


; here is the code that sets the intial positions for the LEDs and the relays
; mute relay set to "Mute ON" (NO position - ie. the relay is not energized, output is disconnected from the amp)
; volume relays set to drain output coupling caps   11111110 binary   (lsb relay to msb relay)
; input select has all relays disconnected so that the amp is isolated.
; Write "Pu" (power-up) to the display registers and clear flag so that values are not overwritten by
; volume level.
initialize_outputs
	bcf STATUS, RP0          ; bank 0
	movlw 0x7f               ; set the initial volumes to drain off the output coupling caps
	movwf left_vol         
	movwf right_vol
	movlw 0x00               ; there is no input selected and the mute is active (relay is OFF = NO)
	movwf select             
	call load_select_leds
	clrf display_volume_flag ; take flag to 0 so that custom display can be made.
	bsf STATUS, RP0          ; bank 1
	movlw ee_display_p_add
	movwf EEADR              
	clrf EECON1
	bsf EECON1, RD
	movf EEDAT, W
	bcf STATUS, RP0          ; bank 0
	movwf display_left_high
	movwf display_right_high
	bsf STATUS, RP0          ; bank 1
	movlw ee_display_u_add
	movwf EEADR              
	clrf EECON1
	bsf EECON1, RD
	movf EEDAT, W
	bcf STATUS, RP0          ; bank 0
	movwf display_left_low
	movwf display_right_low
	return



; delay for 20 seconds (the caps in the amp take a long time to charge up)
mute_delay
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s        ; 5
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s        ; 10
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s       ; 15
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s
	call delay_1s       ; 20
	return



; make the volume setting to saved value and set to the last selected input, this in preparation for the inputs
; to be made "live". The info is read from the data EEPROM
initialize_volume
	bsf STATUS, RP0          ; bank 1
	movlw eeprom_left_vol_address
	movwf EEADR              ; get the saved left volume from the data EEPROM
	clrf EECON1
	bsf EECON1, RD
	movf EEDAT, W
	bcf STATUS, RP0          ; bank 0
	movwf left_vol

	bsf STATUS, RP0          ; bank 1
	movlw eeprom_right_vol_address
	movwf EEADR              ; get the saved left volume from the data EEPROM
	clrf EECON1
	bsf EECON1, RD
	movf EEDAT, W
	bcf STATUS, RP0          ; bank 0
	movwf right_vol

	bsf STATUS, RP0          ; bank 1
	movlw eeprom_select_address
	movwf EEADR              ; get the last select from the data EEPROM
	clrf EECON1
	bsf EECON1, RD
	movf EEDAT, W
	bcf STATUS, RP0          ; bank 0
	movwf select
	bcf select, 7            ; ensure the mute remains on (relay is not energized, bit value is 0)
	movf select, W           ; copy to the LED shift register also
	call load_select_leds
	return


; OK the volume relays are set and the input is selected, so now release the mute (ie energize the mute relay)
; Also turn on the flag that allows the display to be updated with the volume value.
release_mute
	bcf STATUS, RP0          ; bank 0
	movlw 0x01
	movwf display_volume_flag

; This is the original code that would turn off the mute no matter what.....
; Which is wrong since the mute switch may be active when the timeout ends.
; So get the switch setting (no debounce requred) as the timeout ends and load
; this into the mute bit of select instead of just turning off mute.
;	bsf select, 7
;	movf select, W

	movf PORTC, W             ; the mute input is RC5
	movwf portc_delay_1
	rrf portc_delay_1, F      ; get the input to the lsb
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	movlw 0x01                ; and blank out the rest of the register
	andwf portc_delay_1, F
	movlw 0x01                ; invert the setting because the switch is upside down
	xorwf portc_delay_1, F
	movf portc_delay_1, W
	movwf portc_delay_2
	movwf portc_delay_3
	movwf temp_mute
	rrf temp_mute, F          ; rotate twice to get into msb
	rrf temp_mute, F
	movlw 0x7f                ; clear current select msb
	andwf select, F
	movlw 0x80                ; clear all of temp reg execept the msb
	andwf temp_mute, F
	movf temp_mute, W
	iorwf select, F           ; OR the two values to combine.
	

	call load_select_leds
	return


; open the interrupts so that changes on the inputs will run the ISR - also do anything else that is
; needed before the code drops into the infinite loop of nothingness.
open_interrupts

	return



; WS 6/2/06 Added this new method of debounce that does not use the interrupts
; If there are 3 same inputs in a row, different from the current setting, evaluate
; the new inputs. Otherwise just loop around and wait for a change.
; If the criteria are met, "bit_change" contains a non-zero value.

update_porta_values

; First do the following:
;   porta_delay_2 -> porta_delay_3
;   porta_delay_1 -> porta_delay_2
;   PORT A        -> porta_delay_1

	bcf STATUS, RP0           ; bank 0
	movf porta_delay_2, W
	movwf porta_delay_3
	movf porta_delay_1, W
	movwf porta_delay_2
	movf PORTA, W
	movwf porta_delay_1
	movwf current_porta       ; used by older code for calcs.

; now check to see that the 3 last are equal, if not escape
	movf porta_delay_1, W
	xorwf porta_delay_2, W
	btfss STATUS, Z
	goto escape_no_eval_a     ; values not same leave without evaluating
	
	movf porta_delay_2, W
	xorwf porta_delay_3, W
	btfss STATUS, Z
	goto escape_no_eval_a     ; values not same leave without evaluating

; if you get to here, the 3 last registers are the same value. Now have to see if
; that value is different from the value in last_porta. If different, then evaluate.
; If all 4 are the same then there is no input change.
	movf porta_delay_3, W
	xorwf last_porta, W
	movwf bit_change          ; store the changed bit(s) in this register for use later
	btfss STATUS, Z           ; values are all same => no input change, just escape
	                          ; last_porta is different from the 3 last input values and
	return                    ; the input values are all the same so evaluate the input setting


; you escape if either the 3 delay values are not equal which means the input is not
; stable and you have to wait longer for them to all be equal again - OR - the three
; delay values are all the same but the last_porta is the same as the delay values
; which means there is no valid input change
escape_no_eval_a
	movlw 0x00
	movwf bit_change
	return




; WS 7/4/06 Added this subroutine that looks for changes on port C. The only input
; on port C is the mute input, which is pin RC5.
update_portc_values

; First do the following:
;   portc_delay_2 -> portc_delay_3
;   portc_delay_1 -> portc_delay_2
;   PORT C        -> portc_delay_1

	bcf STATUS, RP0           ; bank 0
	movf portc_delay_2, W
	movwf portc_delay_3
	movf portc_delay_1, W
	movwf portc_delay_2
	movf PORTC, W             ; the mute input is RC5
	movwf portc_delay_1
	rrf portc_delay_1, F      ; get the input to the lsb
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	rrf portc_delay_1, F
	movlw 0x01                ; and blank out the rest of the register
	andwf portc_delay_1, F
	movlw 0x01                ; invert the setting because the switch is upside down
	xorwf portc_delay_1, F
	movwf current_portc       ; used by older code for calcs.

; now check to see that the 3 last are equal, if not escape
	movf portc_delay_1, W
	xorwf portc_delay_2, W
	btfss STATUS, Z
	goto escape_no_eval_c     ; values not same leave without evaluating
	
	movf portc_delay_2, W
	xorwf portc_delay_3, W
	btfss STATUS, Z
	goto escape_no_eval_c     ; values not same leave without evaluating

; if you get to here, the 3 last registers are the same value, so set the flag
; that tells the next function called to evaluate the mute setting
	movlw 0x01
	movwf eval_mute
	return


; you escape if either the 3 delay values are not equal which means the input is not
; stable and you have to wait longer for them to all be equal again - OR - the three
; delay values are all the same but the last_porta is the same as the delay values
; which means there is no valid input change
escape_no_eval_c
	movlw 0x00
	movwf eval_mute
	return








; Here's where the code goes when the polling routine has determined that the input volume
; decoder has changed state. Use the variables stored off in the register files to make the calculations.
calculate_volume
	bcf STATUS, RP0                      ; bank 0
	movf last_porta, W
	xorwf current_porta, W               ; W has XOR of last_porta and current_porta
	andlw 0x03                           ; only interested in volume changes so blank out other bits
	sublw 0x03                           ; escape if both bits were set
	btfsc STATUS, Z
	goto recombine_calculate_volume

	movf last_porta, W                   ; get binary value for last porta
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_old

	movf current_porta, W                ; get binary value for current porta
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_new
	
	incf bin_old, F                      ; add 1 to bin_old then XOR with bin_new - if 0 then it was an increase
	bcf bin_old, 0x02                    ; otherwise it's a decrease
	movf bin_old, W
	xorwf bin_new, F
	btfsc STATUS, Z
	goto up_vol
	goto down_vol
	
up_vol
	call increase_volume_left
	call increase_volume_right
	goto execute_volume_change

down_vol
	call decrease_volume_left
	call decrease_volume_right

; go here to actually change the volume
execute_volume_change
	nop
	call update_relays_volume

; go here if there's problem and you just want to get out
recombine_calculate_volume
	nop
	goto escape



; need a 2-bit gray to binary calculator because we do this calc a lot and it's
; kinda a pesky thing to do.
; Function is defined as:
; bin[1] = gray[1]
; bin[0] = gray[1] XOR gray[0]
; input is in variable gray_value
; output is in variable binary_value
gray_to_bin2
	bcf STATUS, RP0                      ; bank 0
	movf gray_value, W                   ; copy value to W
	movwf binary_value                   ; and copy value to binary_value
	rlf gray_value, W                      
	xorwf gray_value, W
	movwf gray_value
	rrf gray_value, F                    ; now gray_value bit 0 has the 2 lsbs XOR'ed together
	movlw 0x01
	andwf gray_value, F                  ; zero out all the other bits
	movlw 0x02
	andwf binary_value, F                ; bit 1 is active as it was initially, zero out all the other bits
	movf gray_value, W                   ; now just OR the 2 registers together
	iorwf binary_value, F                ; answer is in binary_value
	return



; Here's where the code goes when the infinite loop has determined that the input balance
; decoder has changed state. The balance is going to work in a kinda weird way - this may
; be different from what most people are used to.  Rotating the balance to the right which
; is a numerical increase in the balance code will correspond to the left channel volume
; decreasing and the right channel volume will remain the same.
calculate_balance
	bcf STATUS, RP0                      ; bank 0
	movf last_porta, W                   ; get last_porta and shift right 2 bits
	movwf temp1
	rrf temp1, F
	rrf temp1, F
	movf current_porta, W                ; get current_porta and shift right 2 bits
	movwf temp2
	rrf temp2, F
	rrf temp2, F
	movf temp1, W
	xorwf temp2, W                       ; W has XOR of last_porta shifted 2 and current_porta shifted 2
	andlw 0x03                           ; only interested in balance changes so blank out other bits
	sublw 0x03                           ; escape if both bits were set
	btfsc STATUS, Z
	goto recombine_calculate_balance

	movf temp1, W                        ; get binary value for last porta shifted by 2 bits
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_old

	movf temp2, W                        ; get binary value for current porta shifted by 2 bits
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_new
	
	incf bin_old, F                      ; add 1 to bin_old then XOR with bin_new - if 0 then it was an increase
	bcf bin_old, 0x02                    ; otherwise it's a decrease
	movf bin_old, W
	xorwf bin_new, F
	btfsc STATUS, Z
	goto bal_right
	goto bal_left
	
bal_right
	call decrease_volume_left
	goto execute_balance_change

bal_left
	call decrease_volume_right

; go here to actually change the balance
execute_balance_change
	nop
	call update_relays_volume

; go here if there's problem and you just want to get out
recombine_calculate_balance
	nop
	goto escape


; for now the function will be a simple incrementer, but could become more complex later
increase_volume_left
	bcf STATUS, RP0                      ; bank 0
	movf left_vol, W                     ; subtract left_vol from max_volume
	subwf max_volume, W
	btfsc STATUS, Z                      ; if 0, then it's pegged at the top, don't change
	goto recombine_increase_volume_left
	incf left_vol, F                     ; add 1 to the volume level
recombine_increase_volume_left
	nop
	return

increase_volume_right
	bcf STATUS, RP0                      ; bank 0
	movf right_vol, W                    ; subtract right_vol from max_volume
	subwf max_volume, W
	btfsc STATUS, Z                      ; if 0, then it's pegged at the top, don't change
	goto recombine_increase_volume_right
	incf right_vol, F                     ; add 1 to the volume level
recombine_increase_volume_right
	nop
	return


; for now the function will be a simple decrementer, make more complex later if desired
decrease_volume_left
	bcf STATUS, RP0                      ; bank 0
	movf left_vol, F                     ; get status of Z because if the vol = 0, we leave it.
	btfsc STATUS, Z
	goto recombine_decrease_volume_left
	decf left_vol, F
recombine_decrease_volume_left
	nop
	return

decrease_volume_right
	bcf STATUS, RP0                      ; bank 0
	movf right_vol, F                     ; get status of Z because if the vol = 0, we leave it.
	btfsc STATUS, Z
	goto recombine_decrease_volume_right
	decf right_vol, F
recombine_decrease_volume_right
	nop
	return


; Here's where the code goes when the infinite loop has determined that the input selector
; decoder has changed state.
calculate_selector
	bcf STATUS, RP0                      ; bank 0
	movf last_porta, W                   ; get last_porta and shift right 4 bits
	movwf temp1
	rrf temp1, F
	rrf temp1, F
	rrf temp1, F
	rrf temp1, F
	movf current_porta, W                ; get current_porta and shift right 4 bits
	movwf temp2
	rrf temp2, F
	rrf temp2, F
	rrf temp2, F
	rrf temp2, F
	movf temp1, W
	xorwf temp2, W                       ; W has XOR of last_porta shifted 4 and current_porta shifted 4
	andlw 0x03                           ; only interested in selector changes so blank out other bits
	sublw 0x03                           ; escape if both bits were set
	btfsc STATUS, Z
	goto recombine_calculate_selector

	movf temp1, W                        ; get binary value for last porta shifted by 4 bits
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_old

	movf temp2, W                        ; get binary value for current porta shifted by 4 bits
	andlw 0x03
	movwf gray_value
	call gray_to_bin2
	movf binary_value, W
	movwf bin_new
	
	incf bin_old, F                      ; add 1 to bin_old then XOR with bin_new - if 0 then it was an increase
	bcf bin_old, 0x02                    ; otherwise it's a decrease
	movf bin_old, W
	xorwf bin_new, F
	btfsc STATUS, Z
	goto inc_sel
	goto dec_sel
	
inc_sel
	call increase_selector
	goto execute_selector_change

dec_sel
	call decrease_selector

; go here to actually change the selector
execute_selector_change
	call update_outputs
	nop

; this stuff is for storing the selector change in EEPROM but that's not needed because the
; amp will not be turned off
;	movf select, W                        ; write to the data EEPROM the current selector choice
;	bsf STATUS, RP0                       ; bank 1
;	movwf EEDAT                           ; the next time the amp is powered, it will have this input selected
;	movlw eeprom_select_address
;	movwf EEADR
;	clrf EECON1
;	bsf EECON1, WREN 
;	bcf INTCON, GIE
;	movlw 0x55
;	movwf EECON2
;	movlw 0xaa
;	movwf EECON2
;	bsf EECON1, WR
;	bcf EECON1, WREN

; go here if there's problem and you just want to get out
recombine_calculate_selector
	nop
	goto escape




; this function will figure out what the current selector input is and increase it by 1
; unless it is already at the top selection, in which case it will do nothing.
; If there is no input selected, it will activate input # 1.
; Note the following bit definitions of the registers that are to be evaluated.
; bit 6: input select 5 relay (single-ended)
; bit 5: input select 4 relay (single-ended)
; bit 4: input select 3 relay (balanced)
; bit 3: input select 2 relay (balanced)
; bit 2: input select 1 relay (balanced)
; select
; select_leds
increase_selector;
	bcf STATUS, RP0                       ; bank 0
	btfsc select, 2                       ; case on the currently selected input
	goto select_2_up                      ; current is bit 2 (input 1), activate bit 3 (input 2)
	btfsc select, 3
	goto select_3_up
	btfsc select, 4
	goto select_4_up
	btfsc select, 5
	goto select_5_up
	goto recombine_increase_selector      ; if bit 6 is already set, just escape.

select_2_up
	movlw 0x83
	andwf select, F
	bsf select, 3
	goto recombine_increase_selector

select_3_up
	movlw 0x83
	andwf select, F
	bsf select, 4
	goto recombine_increase_selector

select_4_up
	movlw 0x83
	andwf select, F
	bsf select, 5
	goto recombine_increase_selector

select_5_up
	movlw 0x83
	andwf select, F
	bsf select, 6

recombine_increase_selector
; do an error check - if no input selected, select input 1.
	movf select, W                          ; copy select to W
	movwf temp1                             ;  use temp1 for the calcs
	rrf temp1, F                            ; rotate right twice, AND with hex 1F, if result is 0 then no input is active
	rrf temp1, F
	movlw 0x1F
	andwf temp1, F
	btfss STATUS, Z
	goto no_prob_inc_sel
	bsf select, 2                            ; wow - no input was active, select input #1
no_prob_inc_sel
	movf select, W
	call load_select_leds
	return



; this function will figure out what the current selector input is and decrease it by 1
; unless it is already at the bottom selection, in which case it will do nothing.
decrease_selector;
	bcf STATUS, RP0                       ; bank 0
	btfsc select, 6                       ; case on the currently selected input
	goto select_6_down                    ; current is bit 6 (input 5), activate bit 5 (input 4)
	btfsc select, 5
	goto select_5_down
	btfsc select, 4
	goto select_4_down
	btfsc select, 3
	goto select_3_down
	goto recombine_decrease_selector      ; if bit 2 is already set, just escape.

select_6_down
	movlw 0x83
	andwf select, F
	bsf select, 5
	goto recombine_decrease_selector

select_5_down
	movlw 0x83
	andwf select, F
	bsf select, 4
	goto recombine_decrease_selector

select_4_down
	movlw 0x83
	andwf select, F
	bsf select, 3
	goto recombine_decrease_selector

select_3_down
	movlw 0x83
	andwf select, F
	bsf select, 2

recombine_decrease_selector
; do an error check - if no input selected, select input 1.
	movf select, W                          ; copy select to W
	movwf temp1                             ;  use temp1 for the calcs
	rrf temp1, F                            ; rotate right twice, AND with hex 1F, if result is 0 then no input is active
	rrf temp1, F
	movlw 0x1F
	andwf temp1, F
	btfss STATUS, Z
	goto no_prob_dec_sel
	bsf select, 2                            ; wow - no input was active, select input #1
no_prob_dec_sel
	movf select, W                           ; copy select into select_leds
	call load_select_leds
	return


; get the newly calculated internal settings and write them all to the shift register
; bit by bit, then at the end do a parallel shift to update everything at once.
; First have to get the volume levels to figure out the values to load into shift register.
update_outputs
	call update_volume_levels
	call update_displays
	bcf STATUS, RP0         ; work in bank 0
	movf display_right_low, W   ; farthest SR in daisy chain
	call serial_shift_8	
	movf display_right_high, W
	call serial_shift_8
	movf display_left_low, W
	call serial_shift_8	
	movf display_left_high, W
	call serial_shift_8
	movf select_leds, W
	call serial_shift_8
	movf select, W
	call serial_shift_8
	movf table_right_vol, W
	call serial_shift_8
	movf table_left_vol, W        ; closest SR in daisy chain
	call serial_shift_8
	call parallel_shift     ; update all the outputs to the relays at one time
	return



update_relays_volume
	call update_volume_levels
	call update_displays
	bcf STATUS, RP0         ; work in bank 0

	movlw 0x00                  ; blank out the volume relays
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x00
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_1ms

	movlw 0x01                  ; allow bit 0 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x01
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x03                  ; allow bit 1 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x03
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x07                  ; allow bit 2 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x07
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x0F                  ; allow bit 3 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x0F
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x1F                  ; allow bit 4 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x1F
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x3F                  ; allow bit 5 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x3F
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0x7F                  ; allow bit 6 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0x7F
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers
	;call delay_500us

	movlw 0xFF                  ; allow bit 7 to go active
	andwf table_right_vol, W
	movwf right_volume_relays
	movlw 0xFF
	andwf table_left_vol, W
	movwf left_volume_relays
	call load_shift_registers

	return




; this task will load the registers from registers that will have the bits
; activated one by one.
load_shift_registers
	bcf STATUS, RP0         ; work in bank 0
	movf display_right_low, W   ; farthest SR in daisy chain
	call serial_shift_8	
	movf display_right_high, W
	call serial_shift_8
	movf display_left_low, W
	call serial_shift_8	
	movf display_left_high, W
	call serial_shift_8
	movf select_leds, W
	call serial_shift_8
	movf select, W
	call serial_shift_8
	movf right_volume_relays, W
	call serial_shift_8
	movf left_volume_relays, W        ; closest SR in daisy chain
	call serial_shift_8
	call parallel_shift     ; update all the outputs to the relays at one time
	return


; this function writes to the outputs 8 bits serially in order from msb to lsb, the
; W register contains the value to be shifted when the function is called.
serial_shift_8
	movwf temp8
	movlw 0x08
	movwf loop_count
loop_point
	rlf temp8, F
	movf STATUS, W
	movwf write_reg_c
	movlw 0x01
	andwf write_reg_c, F
	bsf write_reg_c, 3
	movf write_reg_c, W
	movwf PORTC
	bsf write_reg_c, 1
	movf write_reg_c, W
	movwf PORTC
	decfsz loop_count, F
	goto loop_point
	return


; this function wiggles the parallel shift output so that the serially shifted data
; in the SR daisy chain can be presented to the relays at one time. IF it turns out
; that we need to do something fancy with the reloading of registers because of loud
; glitches when the volume relays change values, it'll probably have to go into this
; area.
parallel_shift
	movlw 0x08
	movwf PORTC
	movlw 0x0C
	movwf PORTC
	movlw 0x08
	movwf PORTC
	return




; this function loads the select_leds variable using select as the input.
; needed because there are a couple logic errors on the board.
; the MUTE LED setting is inverted
; the MUTE LED was supposed to be the msb but is connected on the board as bit 2 (0 justified)
; the select LEDs were supposed to be [6:2] but are [7:3] on board (0 justified)
load_select_leds
	movf select, W
	movwf select_leds
	movlw 0x80                     ; need to invert the MUTE LED logic level
	xorwf select_leds, F

	rlf select_leds, F             ; get the MUTE LED from bit 7 into the bit 2 position
	rlf select_leds, F
	rlf select_leds, F
	rlf select_leds, F
	movlw 0x04
	andwf select_leds, W
	movwf temp_sel_leds

	rrf select_leds, F             ; rotate the select LEDS back into position
	rrf select_leds, F
	rrf select_leds, F
	movlw 0xF8
	andwf select_leds, F
	movf temp_sel_leds, W
	iorwf select_leds, F           ; OR the two variables to get result
	return



; use the internal clock to make a 10 ms delay used for debouncing and other such
; things that require a delay. The clock is 1 MHz, so 10 ms is 2,500 timer tics.
; Since the timer counts once per instruction, each instruction is 4 clock ticks.
; The timer counts UP and we get an interrupt when it rolls over.  So set the clock
; to 2^16 - 2500 decimal = 65536 - 2500 = 63,036 = F63C.
delay_10ms
	bcf STATUS, RP0                    ; bank 0
	bsf timer1_loop_test, 0            ; set a flag to end loop if ISR has returned
	clrf T1CON                         ; clear out the timer

	movlw 0x3C                         ; wait for 2500 decimal
	movwf TMR1L
	movlw 0xF6
	movwf TMR1H

;	movlw 0xEB                         ; wait for 20 - short for debug
;	movwf TMR1L
;	movlw 0xFF
;	movwf TMR1H


	bcf PIR1, TMR1IF                   ; clear the interrupt for timer 1 before enabling
	bsf STATUS, RP0                    ; bank 1
	bsf PIE1, TMR1IE                   ; enable the timer1 interrupt
	bcf STATUS, RP0                    ; bank 0
;	bcf INTCON, RAIE                   ; disable the port A interrupt while waiting
	bsf INTCON, PEIE                   ; enable the peripheral interrupt
	bsf INTCON, GIE                    ; enable the global interrupt
	movlw 0x05                         ; turn on timer1
	movwf T1CON   

wait_delay_10_ms                       ; drop into loop to wait until interrupt hits
	nop                                ; you return here when the timer ISR is finished execution
	btfsc timer1_loop_test, 0
	goto wait_delay_10_ms

	bcf STATUS, RP0
	bcf T1CON, TMR1ON                  ; disable timer1
;	bcf INTCON, RAIF                   ; re-enable the port A interrupt
;	bsf INTCON, RAIE
	return





; use the internal clock to make a 10 ms delay used for debouncing and other such
; things that require a delay. The clock is 1 MHz, so 3 ms is about 700 timer tics.
; Since the timer counts once per instruction, each instruction is 4 clock ticks.
; The timer counts UP and we get an interrupt when it rolls over.  So set the clock
; to 2^16 - 700 decimal = 65536 - 700 = 64,836 = FD44.
delay_3ms
	bcf STATUS, RP0                    ; bank 0
	bsf timer1_loop_test, 0            ; set a flag to end loop if ISR has returned
	clrf T1CON                         ; clear out the timer

	movlw 0x44                         ; wait for 700 decimal
	movwf TMR1L
	movlw 0xFD
	movwf TMR1H

;	movlw 0xEB                         ; wait for 20 - short for debug
;	movwf TMR1L
;	movlw 0xFF
;	movwf TMR1H


	bcf PIR1, TMR1IF                   ; clear the interrupt for timer 1 before enabling
	bsf STATUS, RP0                    ; bank 1
	bsf PIE1, TMR1IE                   ; enable the timer1 interrupt
	bcf STATUS, RP0                    ; bank 0
;	bcf INTCON, RAIE                   ; disable the port A interrupt while waiting
	bsf INTCON, PEIE                   ; enable the peripheral interrupt
	bsf INTCON, GIE                    ; enable the global interrupt
	movlw 0x05                         ; turn on timer1
	movwf T1CON   

wait_delay_3_ms                       ; drop into loop to wait until interrupt hits
	nop                                ; you return here when the timer ISR is finished execution
	btfsc timer1_loop_test, 0
	goto wait_delay_3_ms

	bcf STATUS, RP0
	bcf T1CON, TMR1ON                  ; disable timer1
;	bcf INTCON, RAIF                   ; re-enable the port A interrupt
;	bsf INTCON, RAIE
	return




; use the internal clock to make a 1 ms delay used for debouncing and other such
; things that require a delay. The clock is 1 MHz, so 1 ms is about 250 timer tics.
; Since the timer counts once per instruction, each instruction is 4 clock ticks.
; The timer counts UP and we get an interrupt when it rolls over.  So set the clock
; to 2^16 - 250 decimal = 65536 - 250 = 65,286 = FF06.
delay_1ms
	bcf STATUS, RP0                    ; bank 0
	bsf timer1_loop_test, 0            ; set a flag to end loop if ISR has returned
	clrf T1CON                         ; clear out the timer

	movlw 0x06                         ; wait for 700 decimal
	movwf TMR1L
	movlw 0xFF
	movwf TMR1H

	bcf PIR1, TMR1IF                   ; clear the interrupt for timer 1 before enabling
	bsf STATUS, RP0                    ; bank 1
	bsf PIE1, TMR1IE                   ; enable the timer1 interrupt
	bcf STATUS, RP0                    ; bank 0
	bsf INTCON, PEIE                   ; enable the peripheral interrupt
	bsf INTCON, GIE                    ; enable the global interrupt
	movlw 0x05                         ; turn on timer1
	movwf T1CON   

wait_delay_1_ms                       ; drop into loop to wait until interrupt hits
	nop                                ; you return here when the timer ISR is finished execution
	btfsc timer1_loop_test, 0
	goto wait_delay_1_ms

	bcf STATUS, RP0
	bcf T1CON, TMR1ON                  ; disable timer1
	return





; use the internal clock to make a 10 ms delay used for debouncing and other such
; things that require a delay. The clock is 1 MHz, so 500 us is about 125 timer tics.
; Since the timer counts once per instruction, each instruction is 4 clock ticks.
; The timer counts UP and we get an interrupt when it rolls over.  So set the clock
; to 2^16 - 125 decimal = 65536 - 125 = 65,411 = FF83.
delay_500us
	bcf STATUS, RP0                    ; bank 0
	bsf timer1_loop_test, 0            ; set a flag to end loop if ISR has returned
	clrf T1CON                         ; clear out the timer

	movlw 0x83                         ; wait for 125 decimal
	movwf TMR1L
	movlw 0xFF
	movwf TMR1H

;	movlw 0xEB                         ; wait for 20 - short for debug
;	movwf TMR1L
;	movlw 0xFF
;	movwf TMR1H


	bcf PIR1, TMR1IF                   ; clear the interrupt for timer 1 before enabling
	bsf STATUS, RP0                    ; bank 1
	bsf PIE1, TMR1IE                   ; enable the timer1 interrupt
	bcf STATUS, RP0                    ; bank 0
;	bcf INTCON, RAIE                   ; disable the port A interrupt while waiting
	bsf INTCON, PEIE                   ; enable the peripheral interrupt
	bsf INTCON, GIE                    ; enable the global interrupt
	movlw 0x05                         ; turn on timer1
	movwf T1CON   

wait_delay_500_us                       ; drop into loop to wait until interrupt hits
	nop                                ; you return here when the timer ISR is finished execution
	btfsc timer1_loop_test, 0
	goto wait_delay_500_us

	bcf STATUS, RP0
	bcf T1CON, TMR1ON                  ; disable timer1
;	bcf INTCON, RAIF                   ; re-enable the port A interrupt
;	bsf INTCON, RAIE
	return





delay_100ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	call delay_10ms
	return

delay_1s
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	call delay_100ms
	return



; the volume levels for the SR are calculated from the current volume
; settings here.
update_volume_levels
	bcf STATUS, RP0                  ; bank 0
	movf left_vol, W
	movwf volume_setting
	call lookup_volume_table
	movwf table_left_vol
	movf right_vol, W
	movwf volume_setting
	call lookup_volume_table
	movwf table_right_vol
	return



; get the proper values into the variables to shift into display shift registers.
update_displays
	bcf STATUS, RP0                  ; bank 0
	btfss display_volume_flag, 0
	goto end_update_displays
	
	movf left_vol, W
	movwf volume_setting
	call lookup_display_table_low
	movwf display_left_low

	movf left_vol, W
	movwf volume_setting
	call lookup_display_table_high
	movwf display_left_high

	movf right_vol, W
	movwf volume_setting
	call lookup_display_table_low
	movwf display_right_low

	movf right_vol, W
	movwf volume_setting
	call lookup_display_table_high
	movwf display_right_high

end_update_displays
	nop
	return


; keep this at the end I guess....
; here is the lookup table for the volume control eccentric
; I guess I'll just have to listen and see what sounds good
; Take a swag at a function that is logarithmic in nature with
; more precision at lower levels.
; There are 64 volume levels coded - that can easily be changed also.
lookup_volume_table
	movlw high volume_table
	movwf PCLATH
	movlw low volume_table
	addwf volume_setting, W
	btfsc STATUS, C
	incf PCLATH, F
	movwf PCL

volume_table
	retlw 00h    ; 0
	retlw 01h
	retlw 02h
	retlw 03h
	retlw 04h
	retlw 05h
	retlw 06h
	retlw 07h
	retlw 08h
	retlw 09h

	retlw 0Ah    ; 10
 	retlw 0Bh
	retlw 0Ch
	retlw 0Eh
	retlw 10h
	retlw 12h
	retlw 14h
	retlw 16h
	retlw 18h
	retlw 1Ah

	retlw 1Ch    ; 20
 	retlw 1Eh
	retlw 20h
	retlw 23h
	retlw 26h
	retlw 29h
	retlw 2Ch
	retlw 2Fh
	retlw 32h
	retlw 35h

	retlw 38h    ; 30
 	retlw 3Bh
	retlw 3Eh
	retlw 41h
	retlw 45h
	retlw 49h
	retlw 4Dh
	retlw 51h
	retlw 55h
	retlw 59h

	retlw 5Dh    ; 40
 	retlw 61h
	retlw 65h
	retlw 69h
	retlw 6Eh
	retlw 73h
	retlw 78h
	retlw 7Dh
	retlw 82h
	retlw 87h

	retlw 8Fh    ; 50
 	retlw 97h
	retlw 9Fh
	retlw 0xA7
	retlw 0xAF
	retlw 0xB7
	retlw 0xBF
	retlw 0xC8
	retlw 0xD1
	retlw 0xDA

	retlw 0xE3    ; 60
 	retlw 0xEC
	retlw 0xF5
	retlw 0xFF


; Use a lookup table to figure out how to generate the display
; This table generates the low-order output digit for 7-segment display
lookup_display_table_low
	movlw high display_table_low
	movwf PCLATH
	movlw low display_table_low
	addwf volume_setting, W
	btfsc STATUS, C
	incf PCLATH, F
	movwf PCL

display_table_low
	retlw 0xF9    ; 0
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 10
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 20
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 30
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 40
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 50
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5
	retlw 0xCC
	retlw 0x6D
	retlw 0x7D
	retlw 0xC1
	retlw 0xFD
	retlw 0xED

	retlw 0xF9    ; 60
	retlw 0xC0
	retlw 0xB5
	retlw 0xE5


; Use a lookup table to figure out how to generate the display
; This table generates the high-order output digit for 7-segment display
lookup_display_table_high
	movlw high display_table_high
	movwf PCLATH
	movlw low display_table_high
	addwf volume_setting, W
	btfsc STATUS, C
	incf PCLATH, F
	movwf PCL

display_table_high
	retlw 0xF9    ; 0
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00
	retlw 0x00

	retlw 0xC0   ; 10
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0
	retlw 0xC0

	retlw 0xB5   ; 20
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5
	retlw 0xB5

	retlw 0xE5   ; 30
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5
	retlw 0xE5

	retlw 0xCC   ; 40
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC
	retlw 0xCC

	retlw 0x6D   ; 50
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D
	retlw 0x6D

	retlw 0x7D   ; 60
	retlw 0x7D
	retlw 0x7D
	retlw 0x7D



	ORG	0x2100				; data EEPROM location
	DE 0x04	                ; the input 1 is selected first time the device is programmed
	DE 0x23                  ; volume left   (initially set to 35 decimal)
	DE 0x23                  ; volume right

    ;HEX code for 7 segment display digits Lite-On part LTD-5523AB Blue LED, 2 digits
	; the circuit connections are:
	; DP  G  F  E  D  C  B  A  SEGMENT
	;  7  6  5  4  3  2  1  0  bit in register
	DE 0xF9  ; 0             
	DE 0xC0  ; 1
	DE 0xB5  ; 2
	DE 0xE5  ; 3
	DE 0xCC  ; 4
	DE 0x6D  ; 5
	DE 0x7D  ; 6
	DE 0xC1  ; 7
	DE 0xFD  ; 8
	DE 0xED  ; 9
	DE 0x9D  ; P  (display during power-down and power-up)
	DE 0x70  ; u
	DE 0xF4  ; d


	END                       ; directive 'end of program'

