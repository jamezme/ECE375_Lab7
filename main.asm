
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

	;TIMER/COUNTER1
		ldi		mpr, 0b0000_0000	
		sts		TCCR1A, mpr			; Normal Mode
		ldi		mpr, 0b0000_0001
		sts		TCCR1B, mpr			; Normal Mode 
		
	;Other
	sei

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

	;TODO: ???

		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_START:
    .DB		"Welcome!"		; Declaring data in ProgMem
STRING_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver

