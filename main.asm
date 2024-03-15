
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
.def	waitcnt = r19
.def	ilcnt = r23
.def	olcnt = r24

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
		rcall	ChoiceSelect
		reti

.org	$0028
;		rcall	TimeOut
		reti

.org	$0032
		rcall	DataReceived
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
		ldi		mpr, 0b0000_0010	; initialize falling edge interrupts 
		sts		EICRA, mpr			; store in register
			; Set the Interrupt Sense Control to falling edge

		; Configure the External Interrupt Mask
		ldi		mpr, 0b0000_0000	; configure INT0, 1
		out		EIMSK, mpr			; send to register


	;TIMER/COUNTER1
		ldi		mpr, 0b0000_0000	
		sts		TCCR1A, mpr			; Normal Mode
		ldi		mpr, 0b0000_0101
		sts		TCCR1B, mpr			; Normal Mode, prescale 1024
		
	;Other
		ldi		XH, high(OP_READY)
		ldi		XL, low(OP_READY)
		ldi		mpr, $00
		st		X, mpr

		ldi		XH, high(PLAYCHOICE)
		ldi		XL, low(PLAYCHOICE)
		ldi		mpr, $00
		st		X, mpr

		clr		play
		ldi		waitcnt, $03

		call	LCDInit
		call	LCDBacklightOn

		sei

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
	rcall	WelcomePlayer
	rcall	GetReady
	rcall	StartGame
	rcall	SendChoice
	rcall	DisplayResults
	rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	WelcomePlayer
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
WelcomePlayer:
	WRITE_LINE_1		PROG_START
	WRITE_LINE_2		PROG_START2
	rcall	LCDWrite

Check:
	in		mpr, PIND
	sbrc	mpr, 7
	rjmp	Check

	ret
;-----------------------------------------------------------
; Func:	GetReady
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
GetReady:
	push	mpr
	push	XH
	push	XL
	push	state
	WRITE_LINE_1		READY
	WRITE_LINE_2		READY2
	rcall	LCDWrite 

RU:	lds		mpr, UCSR1A ; Check if Transmitter is ready
	sbrs	mpr, UDRE1 ; Data Register Empty flag
	rjmp	RU ; Loop until UDR1 is empty

	ldi		mpr, $FF
	sts		UDR1, mpr ; Move data to transmit data buffer

	ldi		XL, low(OP_READY)
	ldi		XH, high(OP_READY)
ORDY:
	ld		state, X
	cpi		state, $FF
	brne	ORDY

	pop		state
	pop		XL
	pop		XH
	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	StartGame
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
StartGame:
	push	mpr

	ldi		mpr, 0b0000_0001	; configure INT0, 1
	out		EIMSK, mpr			; send to register

	cli
	rcall LCDClr
	WRITE_LINE_1	GAME_START
	rcall	LCDInit
	rcall	LCDWrite
	sei

	ldi		mpr, $F0
	out		PORTB, mpr
	rcall	WaitCount
	cbi		PORTB, 7
	rcall	WaitCount
	cbi		PORTB, 6
	rcall	WaitCount
	cbi		PORTB, 5
	rcall	WaitCount
	cbi		PORTB, 4

	ldi		mpr, 0	; configure INT0, 1
	out		EIMSK, mpr			; send to register

	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	WaitCount
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
WaitCount:
	push	mpr

	sbi		TIFR1, TOV1
	ldi		mpr, high(53817)
	sts		TCNT1H, mpr
	ldi		mpr, low(53817)
	sts		TCNT1L, mpr 

DONE: 
	sbis	TIFR1, 0
	rjmp	DONE
	sbi		TIFR1, TOV1

	pop		mpr
	
	ret
;-----------------------------------------------------------
; Func:	LineWrite
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
LineWrite:
	push	mpr
LW:	lpm		mpr, Z+
	st		Y+, mpr

	mov		mpr, YL
	andi	mpr, $0F
	brne	LW
	pop		mpr

	ret
;-----------------------------------------------------------
; Func:	SendChoice
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
SendChoice:
	push	mpr
	push	XL
	push	XH
	push	YL
	push	YH

SC_Transmit:
	lds		mpr, UCSR1A ; Check if Transmitter is ready
	sbrs	mpr, UDRE1 ; Data Register Empty flag
	rjmp	SC_Transmit ; Loop until UDR1 is empty

	ldi		XL, low(PLAYCHOICE)
	ldi		XH, high(PLAYCHOICE)
	ld		mpr, X
	sts		UDR1, mpr ; Move data to transmit data buffer

SC_DISPLAY:
	ldi		YL, low(OP_READY)
	ldi		YH, high(OP_READY)
	ld		mpr, Y
	
	cpi		mpr, $FF
	breq	SC_DISPLAY
	
	cpi		mpr, $01
	breq	DISPLAY_ROCK

	cpi		mpr, $02
	breq	DISPLAY_PAPER

	cpi		mpr, $04
	breq	DISPLAY_SCISSORS

DISPLAY_ROCK:
	WRITE_LINE_1	ROCK
	rjmp	THE_END
DISPLAY_PAPER:
	WRITE_LINE_1	PAPER
	rjmp	THE_END
DISPLAY_SCISSORS:
	WRITE_LINE_1	SCISSORS
THE_END:
	
	cli
	rcall	LCDWrite
	sei

	ldi		mpr, $F0
	out		PORTB, mpr
	rcall	WaitCount
	cbi		PORTB, 7
	rcall	WaitCount
	cbi		PORTB, 6
	rcall	WaitCount
	cbi		PORTB, 5
	rcall	WaitCount
	cbi		PORTB, 4

	pop		YH
	pop		YL
	pop		XH
	pop		XL
	pop		mpr
	ret

;-----------------------------------------------------------
; Func:	ChoiceSelect
; Desc:	Changes play choice from Rock, Paper, or Scissors 
;-----------------------------------------------------------
ChoiceSelect:	
	push	play
	push	mpr
	ldi		XH, high(PLAYCHOICE)
	ldi		XL, low(PLAYCHOICE)

	ld		play, X

	cpi		play, $00
	breq	CS_ROCK
	
	cpi		play, $04
	breq	CS_ROCK

	cpi		play, $01
	breq	CS_PAPER

	cpi		play, $02
	breq	CS_SCISSORS

CS_ROCK:
	ldi		play, $01
	WRITE_LINE_2	ROCK
	rjmp	CS_END
CS_PAPER:
	ldi		play, $02
	WRITE_LINE_2	PAPER
	rjmp	CS_END
CS_SCISSORS:
	ldi		play, $04
	WRITE_LINE_2	SCISSORS

CS_END:
	st		X, play
	cli
	rcall	LCDWrite
	rcall	WaitClr
	sei
	ldi		mpr, $FF
	out		EIMSK, mpr
	pop		mpr
	pop		play
	
	ret

;----------------------------------------------------------------
; Sub:	Wait
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
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;-----------------------------------------------------------
; Func:	DataReceived
; Desc:	 
;-----------------------------------------------------------
DataReceived:
	push	mpr
	push	XH
	push	XL

	lds		mpr, UDR1

	ldi		XH, high(OP_READY)
	ldi		XL, low(OP_READY)

	st		X, mpr
	
	pop		XL
	pop		XH
	pop		mpr

	ret

;-----------------------------------------------------------
; Func:	DisplayResults
; Desc:	 
;-----------------------------------------------------------
DisplayResults:
	cli	
	rcall LCDClr
	sei
	ldi		XH, high(OP_READY)
	ldi		XL, low(OP_READY)
	ld		r17, X

	ldi		XH, high(PLAYCHOICE)
	ldi		XL, low(PLAYCHOICE)
	ld		play, X

	cp		play, r17
	breq	R_DRAW

	cpi		r17, 0
	brne	Do_Operation
	ldi		r17, 1

	cpi		play, 0
	brne	Do_Operation
	ldi		play, 1

Do_Operation:

	sbrc	r17, 0	; if the first bit is set (played rock)...
	ori		r17, 0b1000	; set a bit out
	lsr		r17		; and shift into position

	cp		play, r17	; if play beats the opponent
	breq	R_LOSE

	rjmp	R_WIN

R_DRAW:
	WRITE_LINE_1	DRAW
	rjmp	GAME_END
R_WIN:
	WRITE_LINE_1	WIN
	rjmp	GAME_END
R_LOSE:
	WRITE_LINE_1	LOSE
GAME_END:
	cli	
	rcall LCDWrite
	sei
	ldi		mpr, $F0
	out		PORTB, mpr
	rcall	WaitCount
	cbi		PORTB, 7
	rcall	WaitCount
	cbi		PORTB, 6
	rcall	WaitCount
	cbi		PORTB, 5
	rcall	WaitCount
	cbi		PORTB, 4
	ret
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
;*	Data Memory
;***********************************************************
.dseg
.org	$0130				; data memory allocation for opponent
OP_READY:
		.byte 1		
PLAYCHOICE:
		.byte 1

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
