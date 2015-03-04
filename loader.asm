; Z820 bootloader version 0.1

#include "uart.inc"

SYSFREQ	.equ	20000000
U1_BAUD	.equ	19200
U1_DIV	.equ	SYSFREQ / (16 * U1_BAUD)

RAM	.equ	$2000
STL	.equ	RAM + 0
STH	.equ	RAM + 1
SZL	.equ	RAM + 2
SZH	.equ	RAM + 3
RL	.equ	RAM + 4
RH	.equ	RAM + 5
STACK	.equ	RAM + 256 + 128			; 128 byte stack

	.org $0

		jp	MAIN			; System jumptable
		jp	ECHO
		jp	SHWMSG

MAIN		ld	sp,STACK		; Initialize stack pointer
		ld 	a,$87			; 8b 2s no parity, DLAB=1
		out 	(U1_LCR),a
		ld 	a,U1_DIV & $FF		; LSB of clock divider
		out 	(U1_DLL),a
		ld 	a,(U1_DIV >> 8) & $FF	; MSB of clock divider
		out 	(U1_DLM),a
		ld 	a,($02)			; /MF1 function is /BAUDOUT
		out 	(U1_AFR),a
		ld 	a,$07			; DLAB=0
		out 	(U1_LCR),a
		ld	hl,MSG1			; Show bootloader version
		call	SHWMSG

		ld	hl,MSG2			; Show "Waiting" message
		call	SHWMSG

		ld	hl,STL			; Start loading parameters
		ld	b,4			; Repeat 4 times
PARAMETERS	in	a,(U1_LSR)
		and	1			; Received character?
		jp	z, PARAMETERS		; Nope, go back
		in	a,(U1_RBR)		; Get character
		ld	(hl),a			; Write to ram
		inc	hl
		djnz	PARAMETERS		; Repeat for all parameters

		ld	a,'.'			; Print a dot to indicate that
		out 	(U1_THR),a		; the parameters have been loaded

		ld	hl,STL			; Set up registers for data transfer
		ld	c,(hl)
		inc	hl
		ld	b,(hl)
		inc	hl
		ld	e,(hl)
		inc	hl
		ld	d,(hl)

LOAD		in	a,(U1_LSR)
		and	1			; Received byte?
		jp	z, LOAD			; Nope, go back
		in	a,(U1_RBR)		; Get byte
		ld	(bc),a			; Write to ram
		inc	bc			; Next byte
		dec	de			;
		ld 	a,$FF			; Done yet?
		and	e
		jr	nz,LOAD			; No, next byte
		ld	a,'.'			; Print a dot to indicate activity
		out 	(U1_THR),a
		ld 	a,$FF			; Done yet?
		and	d
		jr	nz,LOAD			; No, next byte

		ld	hl,MSG3			; Print "Done" message
		call	SHWMSG

		ld	hl,(STL)		; Get load address in HL
		call	RUN			; Run program
		jp	MAIN			; Restart

RUN		jp	(hl)			; Jump to load address


; Subroutines for handling serial communication
SHWMSG		ld 	a,(hl)			; Get character
		and	a
		jr	z, DONE
		call	ECHO
		inc	hl			; Advance to next character
		jr	SHWMSG
DONE		ret

ECHO		out 	(U1_THR),a		; Echo character
WAIT		in 	a,(U1_LSR)		; Get line status
		and 	1<<5			; Transmitter empty?
		jr	z,WAIT			; No, wait until ready
		ret				; Return from subroutine

MSG1	.db $1B,"[2J",$1B,"[H"			; Clear screen and return to home
	.db "Bootloader v1.0", $0D, $0A, $00
MSG2	.db "Transfer progress: ", $00
MSG3	.db $0D, $0A, "OK! Now running...", $0D, $0A, $00
	
	.end
