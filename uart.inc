U1		.equ	$08
U1_RBR		.equ	U1 + 0	; Receiver buffer
U1_THR		.equ	U1 + 0	; Transmitter holding
U1_IER		.equ	U1 + 1	; Interrupt enable
U1_IIR		.equ	U1 + 2	; Interrupt Ident.
U1_FCR		.equ	U1 + 2	; FIFO control
U1_LCR		.equ	U1 + 3	; Line control
U1_MCR		.equ	U1 + 4	; Modem control 
U1_LSR		.equ	U1 + 5	; Line status
U1_MSR		.equ	U1 + 6	; Modem status
U1_SCR		.equ	U1 + 7	; Scratch

U1_DLL		.equ	U1 + 0	; Divisor latch (LS)
U1_DLM		.equ	U1 + 1	; Divisor latch (MS)
U1_AFR		.equ	U1 + 2	; Alternate function
