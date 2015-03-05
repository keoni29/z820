; Monitor program for the Z820 computer
ROM	.equ	$0000
ECHO	.equ	ROM + 3
SHWMSG	.equ	ROM + 6

RAM	.equ 	$2000
RX	.equ	RAM + 0				; 256 byte input buffer
STACK	.equ	RX + 256 + 127			; 128 byte stack
VAR	.equ	STACK + 1
MODE	.equ	VAR + 0

#include "uart.inc"

	.org	RAM + $1000 - 4
	.dw	RESET				; Bootloader parameters
	.dw	END - RESET

RESET		ld	sp,STACK		; Initialize stack	
		ld	hl,MSG1			; Print boot message
		call	SHWMSG
SOFTRESET	ld	a,$1B			; Auto escape
		ld	bc,RX			; Init text buffer
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
		ld	c,1			; Reset text index
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
RUN		call	ACTRUN			; Call program like subroutine, so it returns to the monitor
		jp	SOFTRESET
ACTRUN		jp	(hl)			; Run user program
NOESCAPE	ld	a,(MODE)
		cp	$74
		jr	nz,NOTSTOR
		ld	a,l			; LSD's of hex data
		exx				; Swap hl and hl'
		ld	(hl),a			; Store at current store index
		inc	hl			; Increment store index
		exx				; Swap hl' and hl back
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

MSG1	.db "Z820 System configuration:",$0D,$0A
	.db "    Total memory size:     128 KBytes",$0D,$0A
	.db "    Terminal mode:         VT100",$0D,$0A
	.db "    BIOS version:          0.1",$0D,$0A,$0A
	.db "COPYRIGHT (C) by Koen van Vliet, 2015, all rights reserved",$0D,$0A,$0
END