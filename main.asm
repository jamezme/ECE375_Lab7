
;***********************************************************
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Murphy James and Owen Wheary
;*	   Date: 03/16/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	state = r17				; State of opponent 
.def	play = r18				; state of choice 
.def	waitcnt = r19
.def	ilcnt = r23
.def	olcnt = r24

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.macro	WRITE_LINE_1			; Macro for quick writing to LCD Display Line 1
	ldi		ZL, low(@0 << 1)	; Set Z to beginning of program memory address
	ldi		ZH, high(@0 << 1)
	ldi		YL, $00				; Set Y to the beginning of Data Memory of Line 1
	ldi		YH, $01

	call	LineWrite			; Call a helper function to copy data over 
.endm

.macro	WRITE_LINE_2			; Mecro for quick writing to LCD Display Line 2
	ldi		ZL, low(@0 << 1)	; Set Z to beginnning of program memory address
	ldi		ZH, high(@0 << 1)
	ldi		YL, $10				; Set Y to the beginning of Data Memory of Line 2 
	ldi		YH, $01

	call	LineWrite			; Call a helper function to copy over data
.endm

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt

.org	$0002					; INT0 
		rcall	ChoiceSelect 	; Function to change choice during Game Start
		reti

.org	$0032					; Receive Interrupt
		rcall	DataReceived	; Function to save received data 
		reti

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND
		
	;I/O Ports
	; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

	; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

	;USART1
		ldi		mpr, 0b0010_0010	; Enable double speed 
		sts		UCSR1A, mpr

		ldi		mpr, 0b1001_1000	; Enable 8 bits and receive interrupt
		sts		UCSR1B, mpr 

		ldi		mpr, 0b0000_1110	; Asynchronous, 2 stop bits, no parity 
		sts		UCSR1C, mpr 

		ldi		mpr, 0b0000_0001	; Set BAUD rate to 2400, registers set to 416
		sts		UBRR1H, mpr

		ldi		mpr, 0b10100000		; lower half of 416
		sts		UBRR1L, mpr
		;Set baudrate at 2400bps
		;Enable receiver and transmitter
		;Set frame format: 8 data bits, 2 stop bits

	; Initialize external interrupts
		ldi		mpr, 0b0000_0010	; initialize falling edge interrupts 
		sts		EICRA, mpr			; store in register
			; Set the Interrupt Sense Control to falling edge

		; Configure the External Interrupt Mask
		ldi		mpr, 0b0000_0000	; disable button until StartGame
		out		EIMSK, mpr			; send to register


	;TIMER/COUNTER1
		ldi		mpr, 0b0000_0000	
		sts		TCCR1A, mpr			; Normal Mode
		ldi		mpr, 0b0000_0101
		sts		TCCR1B, mpr			; Normal Mode, prescale 1024
		
	;Other
		ldi		XH, high(OP_READY)	; Clear out opponent status/play
		ldi		XL, low(OP_READY)
		ldi		mpr, $00
		st		X, mpr

		ldi		XH, high(PLAYCHOICE) ; Clear out user status/play 
		ldi		XL, low(PLAYCHOICE)
		ldi		mpr, $00
		st		X, mpr

		clr		play				; Clear play register 
		ldi		waitcnt, $03		; set debounce wait to 30ms

		call	LCDInit				; initialize LCDDisplay 
		call	LCDBacklightOn	

		sei							; Enable global interrupts

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
	rcall	WelcomePlayer	; Function call to welcome sequence
	rcall	GetReady		; Function call to handling readying up 
	rcall	StartGame		; Function call to handle choosing a move 
	rcall	SendChoice		; Function call to send and receive chosen move 
	rcall	DisplayResults	; Function call to display win, lose, draw
	rjmp	MAIN			; repeat forever 

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	WelcomePlayer
; Desc:	Displays the welcome message until the user clicks 
;	PD7 indicating readiness. 
;-----------------------------------------------------------
WelcomePlayer:
	WRITE_LINE_1		PROG_START	; Write Welcome message
	WRITE_LINE_2		PROG_START2	
	rcall	LCDWrite				; push to screen 

Check:
	in		mpr, PIND	; poll for PD7 button press 
	sbrc	mpr, 7
	rjmp	Check

	ret
;-----------------------------------------------------------
; Func:	GetReady
; Desc:	Writes ready message to display, sends ready message 
; 	to other board, and polls to receive opponent's ready 
; 	signal.
;-----------------------------------------------------------
GetReady:
	push	mpr		; push registers onto stack 
	push	XH
	push	XL
	push	state
	WRITE_LINE_1		READY	; Write ready message to data memory 
	WRITE_LINE_2		READY2
	rcall	LCDWrite 			; push to display 

RU:	lds		mpr, UCSR1A 	; Check if Transmitter is ready
	sbrs	mpr, UDRE1 		; Data Register Empty flag
	rjmp	RU 				; Loop until UDR1 is empty

	ldi		mpr, $FF	; determined ready signal
	sts		UDR1, mpr 	; Move data to transmit data buffer

	ldi		XL, low(OP_READY)	; Set X to data memory of OP_READY
	ldi		XH, high(OP_READY)
ORDY:
	ld		state, X	; Load opponent's status 
	cpi		state, $FF	; check if ready 
	brne	ORDY		; loop if not 

	pop		state		; pop registers in reverse order 
	pop		XL
	pop		XH
	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	StartGame
; Desc:	Writes Game start to the screen and handles the 
; 	countdown. Enables and then disables PD4 interrupt. 
;-----------------------------------------------------------
StartGame:
	push	mpr

	ldi		mpr, 0b0000_0001	; Enable PD4 button interrupt
	out		EIMSK, mpr			; send to register

	cli
	rcall LCDClr				; clear the screen 
	WRITE_LINE_1	GAME_START	; Move start message to line 1 DM 
	rcall	LCDInit
	rcall	LCDWrite			; Write it to screen 
	sei

	ldi		mpr, $F0		; Turn on PORTB LEDs
	out		PORTB, mpr		
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 7		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 6		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 5		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 4		; Turn off an LED

	ldi		mpr, 0		; disable PD4 interrupt
	out		EIMSK, mpr	; send to register

	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	WaitCount
; Desc:	Uses Timer/Counter1 to wait for 1.5s. 
;-----------------------------------------------------------
WaitCount:
	push	mpr

	sbi		TIFR1, TOV1		; reset the TOV flag
	ldi		mpr, high(53817)	; load in value for 1.5s
	sts		TCNT1H, mpr
	ldi		mpr, low(53817)
	sts		TCNT1L, mpr 

DONE: 
	sbis	TIFR1, 0	; Wait for timer 
	rjmp	DONE
	sbi		TIFR1, TOV1	; Reset the TOV flag 

	pop		mpr
	
	ret
;-----------------------------------------------------------
; Func:	LineWrite
; Desc:	Helper function to macros that copies prog memory 
;	to data memory. 
;-----------------------------------------------------------
LineWrite:
	push	mpr
LW:	lpm		mpr, Z+		; load ProgMem
	st		Y+, mpr		; store in DM

	mov		mpr, YL		; check if Y has reached F on lowest nibble 
	andi	mpr, $0F
	brne	LW			; loops until it has 
	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	SendChoice
; Desc:	Transmit the users choice and polls for opponent's
;	choice and then displays the choice. Additionally, handles
;	countdown for this section. 
;-----------------------------------------------------------
SendChoice:
	push	mpr
	push	XL
	push	XH
	push	YL
	push	YH

SC_Transmit:
	lds		mpr, UCSR1A 	; Check if Transmitter is ready
	sbrs	mpr, UDRE1 		; Data Register Empty flag
	rjmp	SC_Transmit 	; Loop until UDR1 is empty

	ldi		XL, low(PLAYCHOICE)	; Load in players choice 
	ldi		XH, high(PLAYCHOICE)
	ld		mpr, X			; Send to mpr 
	sts		UDR1, mpr 		; Move data to transmit data buffer

SC_DISPLAY:
	ldi		YL, low(OP_READY)	; Load in opponents choice/status 
	ldi		YH, high(OP_READY)
	ld		mpr, Y
	
	cpi		mpr, $FF		; If still the ready signal
	breq	SC_DISPLAY		; continue looping 
	
	cpi		mpr, $01		; If rock, display rock 
	breq	DISPLAY_ROCK

	cpi		mpr, $02		; If paper, display paper 
	breq	DISPLAY_PAPER

	cpi		mpr, $04		; If scissors, display scissors
	breq	DISPLAY_SCISSORS

DISPLAY_ROCK:
	WRITE_LINE_1	ROCK	; Write line 1 as rock
	rjmp	THE_END			; jump to wait 
DISPLAY_PAPER:
	WRITE_LINE_1	PAPER	; Write line 1 as paper
	rjmp	THE_END			; jump to wait 
DISPLAY_SCISSORS:
	WRITE_LINE_1	SCISSORS	; Write line 1 as scissors 
THE_END:
	
	cli
	rcall	LCDWrite		; Push to display 
	sei

	ldi		mpr, $F0		; Turn on PORTB LEDs
	out		PORTB, mpr		
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 7		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 6		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 5		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 4		; Turn off an LED

	pop		YH
	pop		YL
	pop		XH
	pop		XL
	pop		mpr
	ret

;-----------------------------------------------------------
; Func:	ChoiceSelect
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;	upon PD4 button press interrupt. 
;-----------------------------------------------------------
ChoiceSelect:	
	push	play
	push	mpr
	ldi		XH, high(PLAYCHOICE)	; Load in address to player's choice
	ldi		XL, low(PLAYCHOICE)

	ld		play, X		; load into play register 

	cpi		play, $00	; If first press, default to rock
	breq	CS_ROCK
	
	cpi		play, $04	; If at scissors, go back to rock 
	breq	CS_ROCK

	cpi		play, $01	; If at rock, go to paper
	breq	CS_PAPER

	cpi		play, $02	; If at paper, go to scissors 
	breq	CS_SCISSORS

CS_ROCK:
	ldi		play, $01	; Load in rock 
	WRITE_LINE_2	ROCK ; Write to data memory 
	rjmp	CS_END	; Jump to end 
CS_PAPER:
	ldi		play, $02	; Load in paper 
	WRITE_LINE_2	PAPER	; Write to data memory 
	rjmp	CS_END		; Jump to end 
CS_SCISSORS:	
	ldi		play, $04	; Load in scissors 
	WRITE_LINE_2	SCISSORS	; Write to data memory 

CS_END:
	st		X, play		; Store new choice into PLAYCHOICE 
	cli
	rcall	LCDWrite	; Display new choice 
	rcall	WaitClr		; Debouncing action 
	sei
	ldi		mpr, $FF	; reset interrupts 
	out		EIMSK, mpr
	pop		mpr
	pop		play
	
	ret

;----------------------------------------------------------------
; Sub:	WaitClr
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
WaitClr:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;-----------------------------------------------------------
; Func:	DataReceived
; Desc:	 Responds to USART receive interrupt. Loads in data 
; from UDR1 to OP_READY. 
;-----------------------------------------------------------
DataReceived:
	push	mpr
	push	XH
	push	XL

	lds		mpr, UDR1	; Load in received data 

	ldi		XH, high(OP_READY)	; Load DM address 
	ldi		XL, low(OP_READY)

	st		X, mpr		; Store received into OP_READY 
	
	pop		XL
	pop		XH
	pop		mpr

	ret

;-----------------------------------------------------------
; Func:	DisplayResults
; Desc:	 Handles determining and displaying win, lose or draw.
; 	Uses the 6 second WaitCount. 
;-----------------------------------------------------------
DisplayResults:
	cli	
	rcall LCDClr	; Clear the screen 
	sei
	ldi		XH, high(OP_READY)	; Load in opponents choice 
	ldi		XL, low(OP_READY)
	ld		r17, X

	ldi		XH, high(PLAYCHOICE)	; Load in user's choice 
	ldi		XL, low(PLAYCHOICE)
	ld		play, X

	cp		play, r17		; If they are the same choice 
	breq	R_DRAW			; Display draw 

	cpi		r17, 0			; If opponent never selected anything
	brne	Do_Operation
	ldi		r17, 1			; Assume rock 

	cpi		play, 0			; If user never selected anything
	brne	Do_Operation
	ldi		play, 1			; Assume rock

Do_Operation:

	sbrc	r17, 0		; If the first bit is set (played rock)...
	ori		r17, 0b1000	; Set a bit out
	lsr		r17			; and shift into position

	cp		play, r17	; If play loses to the opponent
	breq	R_LOSE		; Display lose 

	rjmp	R_WIN		; Display Win 

R_DRAW:
	WRITE_LINE_1	DRAW	; Write Line 1 with draw message 
	rjmp	GAME_END		; Jump to end 
R_WIN:
	WRITE_LINE_1	WIN		; Write line 1 with win message 
	rjmp	GAME_END		; Jump to end 
R_LOSE:
	WRITE_LINE_1	LOSE	; Write Line 1 with lose message 
GAME_END:
	cli	
	rcall LCDWrite			; Push to display 
	sei
	ldi		mpr, $F0		; Turn on PORTB LEDs
	out		PORTB, mpr		
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 7		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 6		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 5		; Turn off an LED
	rcall	WaitCount		; Wait 1.5s
	cbi		PORTB, 4		; Turn off an LED
	ret
;***********************************************************
;*	Stored Program Data
;***********************************************************

PROG_START:
    .DB		"Welcome!        "		; Declaring data in ProgMem
PROG_START2:
	.DB		"Please press PD7"

READY:
	.DB		"Ready. Waiting  "
READY2:
	.DB		"for the opponent"

GAME_START:
	.DB		"Game Start      "

ROCK:
	.DB		"Rock            "

PAPER:
	.DB		"Paper           "

SCISSORS:
	.DB		"Scissors        "

WIN:
	.DB		"You Win!        "

LOSE:
	.DB		"You Lose!       "

DRAW: 
	.DB		"Draw!           " 

;***********************************************************
;*	Data Memory
;***********************************************************
.dseg
.org	$0130				; data memory allocation for opponent
OP_READY:
		.byte 1		
PLAYCHOICE:					; data memory allocation for user 
		.byte 1

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
