; Monitor program for the Z820 computer
ROM	.equ	$0000

RAM	.equ 	$2000
RX	.equ	RAM + 0				; 256 byte input buffer
STACK	.equ	RX + 256 + 127			; 128 byte stack
VAR	.equ	STACK + 1
MODE	.equ	VAR + 0

LDADDRL	.equ	VAR + 1
LDADDRH .equ	VAR + 2
LDSIZEL .equ	VAR + 3
LDSIZEH .equ	VAR + 4

#include "uart.inc"

SYSFREQ	.equ	20000000
U1_BAUD	.equ	19200
U1_DIV	.equ	SYSFREQ / (16 * U1_BAUD)

	.org	RAM + $1000 - 4
	.dw	RESET				; Bootloader parameters
	.dw	END - RESET

RESET		ld	sp,STACK		; Initialize stack	
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
		ld	hl,MSG1			; Print boot message
		call	SHWMSG
SOFTRESET	ld	a,$1B			; Auto escape
NOTCR		cp	$08			; Backspace?
		jr	z,BACKSPACE		; Yes, backspace
		cp	$1B
		jr	z,ESCAPE
		inc	c			; Increment text index
		jp	p,NEXTCHAR		; Next char
ESCAPE		ld	a,$5C			; Print '\'
		call	ECHO
NEWLINE		ld	a,$0A			; CRNL
		call	ECHO
CR		ld	a,$0D
		call	ECHO
		ld	bc,RX+1			; Reset text index
		ld	a,'>'
		call	ECHO
BACKSPACE	xor	a
		cp	c			; Text index 0?
		jr	z,CR			; No, re-init line
		dec	c			; Decrement text index
		ld	a,' '			; Space overwites backspaced char
		call	ECHO
		ld	a,$08			; Backspace again to move cursor
		call	ECHO
NEXTCHAR	in	a,(U1_LSR)
		and	1			; Received byte?
		jp	z, NEXTCHAR		; Nope, go back
		in	a,(U1_RBR)		; Get byte

		cp	$7F			; DEL?
		jr	z,ESCAPE		; Yes, reset
		cp	$60			; Check if lowercase
		jr	c,LOWERCASE		; Nope, don't convert
		and	$5F			; Convert to uppercase
LOWERCASE	push	AF
			call	ECHO			; Echo character
		pop	AF
		ld	(bc),a			; Write to buffer
		cp	$0D			; Is CR?
		jr	nz,NOTCR		; No, go back
		ld	a,$0A
		call	ECHO
		ld	c,$FF			; Reset text index
		ld	a,$00			; For XAM mode
SETSTOR		sla	a			; Leaves 3
SETMODE		ld	(MODE),a		; $00 = XAM, $74 = STOR, $2E = BLOK XAM.
BLSKIP		inc	c			; Skip character
NEXTITEM	ld	a,(bc)			; Get character
		cp	$0D			; CR?
		jr	z,NEWLINE		; Yes, done this line.
		cp	'.'			; '.'?
		jr	c,BLSKIP		; Skip delimiter
		jr	z,SETMODE		; Set BLOCK XAM mode.
		cp	':'			; ':'?
		jr	z,SETSTOR		; Yes, set STOR mode
		cp	'R'			; 'R'?
		jr	z,RUN			; Yes, run user program
		cp	'L'			; 'L'?
		jp	z,LOADER		; Yes, load file
		cp	'X'			; 'X'?
		jp	z,DEBUG			; Yes, debug info
		ld	e,c			; Save c for comparison
		ld	hl,$0000		; $0000 -> HL
NEXTHEX		ld	a,(bc)			; Get character
		xor	$30			; Map digits to $0-9
		cp	$0A			; Digit?
		jr	c,DIG			; Yes
		add	a,$89			; Map letter "A"-"F" to $FA-$FF
		cp	$FA			; Hex letter?
		jr	c, NOTHEX		; No, character not hex
DIG		sla	a
		sla	a			; Hex digit MSD of A.
		sla	a
		sla	a
		push	bc
			ld	b,$4			; Shift count
HEXSHIFT		sla	a			; Hex digit left MSB to carry.
			rl	l			; Rotate into LSD
			rl	h			; Rotate into MSD's
			djnz	HEXSHIFT		; Repeat 4 times
		pop bc
		inc	c			; Advance text index
		jr	NEXTHEX			; Check next
NOTHEX		ld	a,e
		cp	c			; Check if L, H empty (no hex digits)
		jr	nz,NOESCAPE		; Branch out of range, so bit of a hack here.
		jp	ESCAPE
RUN		exx				; Get XAM index in HL
		push	hl
		exx
		pop	hl
		call	ACTRUN			; Call program like subroutine, so it returns to the monitor
		jp	SOFTRESET
ACTRUN		jp	(hl)			; Run user program
NOESCAPE	ld	a,(MODE)
		cp	$74
		jr	nz,NOTSTOR
		ld	a,l			; LSD's of hex data
		exx				; Swap bc and bc'
		ld	(bc),a			; Store at current store index
		inc	bc			; Increment store index
		exx				; Swap bc' and bc back
		jp	NEXTITEM
NOTSTOR		ld	a,(MODE)
		cp	$2E			; Mode block XAM?
		jr	z,FXAMNEXT		; Yes, process next
SETADR		push	hl
		exx
		pop	hl			; Get hl in hl' and bc'
		ld	b,h
		ld	c,l
		xor	a			; set zero flag
NXTPRNT		jr	nz,PRDATA		; nz means no address to print
		ld	a,$0A			; CRNL
		call	ECHO
		ld	a,$0D
		call	ECHO
		call	DispHLhex
		ld	a,':'			; ':'
		call	ECHO
PRDATA		ld	a,' '			; Blank
		call	ECHO
		ld	a,(hl)			; Get byte at XAM index
		ld	d,a
		call	OutHex8
XAMNEXT		ld	a,0			; 0->MODE (XAM mode)
		ld	(MODE),a
		; Compare hl with hl'
		push	hl			; Get hl' in de
		exx
		pop	de
		ld	a,h			; Are hl and hl' equal?
		cp	d
		jr	nz,NOTHI
		ld	a,l
		cp	e
		jp	z,NEXTITEM		; Yes, so no more data to print
NOTHI		exx
		inc	hl			; Increment XAM index
MOD8CHK		ld	a,l			; Check low order XAM index byte
		and	$0F			; Get 16 bytes per line
		jr	NXTPRNT	
FXAMNEXT	ld	a,h
		exx
		jr	XAMNEXT

LOADER		ld	hl,MSG2
		call	SHWMSG

		ld	b,4			; Repeat 4 times
PARAMETERS	in	a,(U1_LSR)
		and	1			; Received character?
		jp	z, PARAMETERS		; Nope, go back
		in	a,(U1_RBR)		; Get character
		push	af			; Push it on the stack
		djnz	PARAMETERS		; Repeat for all parameters
		exx				; Swap registers
		pop	af			; Pop Size high
		ld	d,a			; Save to size counter
		pop	af			; Pop Size low
		ld	e,a			; Save to size counter
		pop	af			; Pop Address high
		ld	h,a			; Save to XAM index
		ld	b,a			; Save to STOR index
		pop	af			; Pop Address low
		ld	l,a			; Save to XAM index
		ld	c,a			; Save to STOR index
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
		push	bc
			push	hl
				ld	hl,MSG3
				call	SHWMSG
			pop	hl
			call	DispHLhex		; Print start address
			ld	a,'.'
			call	ECHO			; Print '.'
			exx				; Swap back registers
		pop	hl			; Get STOR index in HL
		call	DispHLhex		; Print end address
		jp	NEWLINE
DEBUG		ld	a,'S'
		call	ECHO
		ld	a,':'
		call	ECHO
		exx
		push	hl
		push	bc
		exx
		pop	hl
		call	DispHLhex
		pop	hl
		call	ECHO
		ld	a,' '
		ld	a,'X'
		call	ECHO
		ld	a,':'
		call	ECHO
		call	DispHLhex
		jp	NEWLINE

;Display a 16- or 8-bit number in hex.
DispHLhex
; Input: HL
		ld  d,h
		call  OutHex8
		ld  d,l
OutHex8
; Input: D
		ld  a,d
		rra
		rra
		rra
		rra
		call  Conv
		ld  a,d
Conv
		and  $0F
		add  a,$90
		daa
		adc  a,$40
		daa
		call ECHO
		ret
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

MSG1	.db $1B,"[2J",$1B,"[H"			; Clear screen and return 
	.db "Z820 System configuration:",$0D,$0A
	.db "    Total memory size:     128 KBytes",$0D,$0A
	.db "    Terminal mode:         VT100",$0D,$0A
	.db "    BIOS version:          0.1",$0D,$0A,$0A
	.db "COPYRIGHT (C) by Koen van Vliet, 2015, all rights reserved",$0D,$0A,$0
MSG2	.db "Transfer progress: ", $00
MSG3	.db "Done!",$0A,$0D,$00
END