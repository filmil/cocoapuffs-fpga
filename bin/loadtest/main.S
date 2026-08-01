.section .text

.option norvc

.type asm_start, @function
.global asm_start
_start:
asm_start:
    .cfi_startproc

	ret
	ret
	jr ra

    .cfi_endproc
