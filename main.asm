
;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Murphy James and Owen Wheary
;*	   Date: 03/07/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	state = r17				; State of game 
.def	play = r18				; state of choice 

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.macro	WRITE_LINE_1
	ldi		ZL, low(@0 << 1)
	ldi		ZH, high(@0 << 1)
	ldi		YL, $00
	ldi		YH, $01

	call	LineWrite
.endm

.macro	WRITE_LINE_2
	ldi		ZL, low(@0 << 1)
	ldi		ZH, high(@0 << 1)
	ldi		YL, $10
	ldi		YH, $01

	call	LineWrite
.endm

; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt

.org	$0002
;		rcall	ChoiceSelect
		reti

.org	$0008
;		rcall	ReadyUp
		reti

.org	$0028
;		rcall	TimeOut
		reti

.org	$0032
;		rcall	DataReceived
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
		ldi		mpr, 0b0010_0010
		sts		UCSR1A, mpr

		ldi		mpr, 0b1001_1000
		sts		UCSR1B, mpr 

		ldi		mpr, 0b0000_1110
		sts		UCSR1C, mpr 

		ldi		mpr, 0b0000_0001
		sts		UBRR1H, mpr

		ldi		mpr, 0b10100000
		sts		UBRR1L, mpr
		;Set baudrate at 2400bps
		;Enable receiver and transmitter
		;Set frame format: 8 data bits, 2 stop bits

	; Initialize external interrupts
		ldi		mpr, 0b1000_0010	; initialize falling edge interrupts 
		sts		EICRA, mpr			; store in register
			; Set the Interrupt Sense Control to falling edge

		; Configure the External Interrupt Mask
		ldi		mpr, 0b0000_1001	; conigure INT0, 3
		out		EIMSK, mpr			; send to register


	;TIMER/COUNTER1
		ldi		mpr, 0b0000_0000	
		sts		TCCR1A, mpr			; Normal Mode
		ldi		mpr, 0b0000_0101
		sts		TCCR1B, mpr			; Normal Mode, prescale 1024
		
	;Other
		clr		state
		clr		play

		call	LCDInit
		call	LCDBacklightOn

		sei

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
	cpi		state, $00
	breq	M_WELCOME

	cpi		state, $01
	breq	M_WAIT

	cpi		state, $02
	breq	M_START

M_WELCOME:
	WRITE_LINE_1	PROG_START
	WRITE_LINE_2	PROG_START2
	rjmp	M_END

M_WAIT:
	WRITE_LINE_1	READY
	WRITE_LINE_2	READY2
	rjmp	M_END

M_START:
	call	LCDClr


	WRITE_LINE_1	GAME_START

M_END:
	call	LCDWrite

	rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

LineWrite:
	lpm		mpr, Z+
	st		Y+, mpr

	mov		mpr, YL
	andi	mpr, $0F
	brne	LineWrite

	ret

;-----------------------------------------------------------
; Func:	ChoiceSelect
; Desc:	ur mom 
;-----------------------------------------------------------
ChoiceSelect:	

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
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
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver

