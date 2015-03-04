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
SETSTOR		sla a				; Set storage mode
SETMODE		ld	(MODE),a		; Set mode
BLSKIP		ld	a,'~'
		call	ECHO
		inc	c			; Skip character
NEXTITEM	ld	a,(bc)			; Get character
		cp	$0D			; CR?
		jr	z,NEWLINE		; Yes, done this line.
		ld	e,c
		ld	hl,$0000
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
HEXSHIFT	sla	a			; Hex digit left MSB to carry.
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
RUN		call	ACTRUN
		jp	SOFTRESET
ACTRUN		jp	(hl)
NOESCAPE	ld	a,'@'
		call	ECHO
		call 	DispHLhex
		jp	ESCAPE

;Display a 16- or 8-bit number in hex.
DispHLhex
; Input: HL
		ld  c,h
		call  OutHex8
		ld  c,l
OutHex8
; Input: C
		ld  a,c
		rra
		rra
		rra
		rra
		call  Conv
		ld  a,c
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