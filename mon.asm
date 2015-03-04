; Monitor program for the Z820 computer
ROM	.equ	$0000
ECHO	.equ	ROM + 3
SHWMSG	.equ	ROM + 6

RAM	.equ 	$2000
RX	.equ	RAM + 0				; 256 byte input buffer
STACK	.equ	RAM + 256 + 128			; 128 byte stack
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
		inc	bc			; Increment text index
		jr	NEXTCHAR		; Next char
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
		jp	ESCAPE

MSG1	.db "Z820 System configuration:",$0D,$0A
	.db "    Total memory size:     128 KBytes",$0D,$0A
	.db "    Terminal mode:         VT100",$0D,$0A
	.db "    BIOS version:          0.1",$0D,$0A,$0A
	.db "COPYRIGHT (C) by Koen van Vliet, 2015, all rights reserved",$0D,$0A,$0
END