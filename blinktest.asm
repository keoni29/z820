; Blinking LED test program
.org	$4000 - 4
.dw	START			; Bootloader parameters
.dw	DONE - START

START	ld a,$FF
	out (0),a
	ld a,7
	ld bc,0
	djnz $
	dec c
	jr nz,$-3
	dec a
	jr nz,$-6
	ld a,$00
	out (0),a
	ld a,7
	ld bc,0
	djnz $
	dec c
	jr nz,$-3
	dec a
	jr nz,$-6
	jr START
DONE
	.end
