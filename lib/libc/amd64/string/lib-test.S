.text
.globl	test_strrchr
.type	test_strrchr, @function

#define ALIGN_TEXT	.p2align 4,0x90	# 16-byte alignment, nop-filled

test_strrchr:

	/* handle c == 0 */
	test		%esi, %esi
	jz		.Lfind_nul

	/* align pointer to 32 bytes */
	mov		%edi, %ecx
	and		$~0x1f, %rdi
	vmovdqu		(%rdi), %ymm1

	/* offset within aligned block */
	and		$0x1f, %ecx

	/* zero vector (used for all NUL compares) */
	vpxor		%ymm2, %ymm2, %ymm2

	/* broadcast search character */
	mov		$-1, %edx
	movd		%esi, %xmm0
	vpbroadcastb	%xmm0, %ymm0

	/* mask out bytes before start */
	shl		%cl, %edx

	/* last match pointer */
	xor		%r8, %r8

	/* current block base */
	mov		%rdi, %r9
	add		$32, %rdi

	/* compare first block */
	vpcmpeqb	%ymm2, %ymm1, %ymm3	# NUL
	vpcmpeqb	%ymm0, %ymm1, %ymm4	# match

	vpmovmskb	%ymm3, %eax
	vpmovmskb	%ymm4, %ecx

	and		%edx, %eax
	and		%edx, %ecx

	/* NUL in first block */
	test		%eax, %eax
	jz		.Lhead_no_nul

	tzcnt		%eax, %edx		# first NUL
	mov		$-1, %r11d
	bzhi		%edx, %r11d, %r11d	# mask before NUL
	and		%r11d, %ecx

	test		%ecx, %ecx
	jz		.Lret_last

	bsr		%ecx, %edx		# last match
	lea		(%r9,%rdx,1), %r8
	jmp		.Lret_last

.Lhead_no_nul:
	/* match in first block */
	test		%ecx, %ecx
	jz		.Lloop

	bsr		%ecx, %edx
	lea		(%r9,%rdx,1), %r8

	/* main loop */
	ALIGN_TEXT
.Lloop:
	vmovdqu		(%rdi), %ymm1
	add		$32, %rdi		# advance to next block
	
	/* reuse zero vector (ymm2) instead of re-zeroing every iteration */
	vpcmpeqb	%ymm2, %ymm1, %ymm3	# NUL
	vpcmpeqb	%ymm0, %ymm1, %ymm4	# match

	vpmovmskb	%ymm3, %eax
	vpmovmskb	%ymm4, %ecx

	/* NUL found? */
	test		%eax, %eax
	jnz		.Lhandle_nul

	/* update last match */
	bsr		%ecx, %edx
	lea		-32(%rdi,%rdx,1), %rdx
	cmovnz		%rdx, %r8
	jmp		.Lloop

.Lhandle_nul:
	tzcnt		%eax, %edx
	mov		$-1, %r11d
	bzhi		%edx, %r11d, %r11d
	and		%r11d, %ecx

	bsr		%ecx, %edx
	lea		-32(%rdi,%rdx,1), %rdx
	cmovnz		%rdx, %r8
	mov		%r8, %rax
	vzeroupper
	ret

.Lret_last:
	/* return last match */
	mov		%r8, %rax
	vzeroupper
	ret

	/* scalar fallback */
.Lpeel:
	movzbl		(%rdi), %eax
	test		%al, %al
	je		.Lret_last

	cmp		%sil, %al
	jne		.Lpeel_next
	mov		%rdi, %r8

.Lpeel_next:
	inc		%rdi
	test		$4095, %edi
	jnz		.Lpeel
	jmp		.Lloop

	/* find NUL (c == 0) */
.Lfind_nul:
	mov		%rdi, %rax

.Lnul_loop:
	cmpb		$0, (%rax)
	je		.Lnul_done
	inc		%rax
	jmp		.Lnul_loop

.Lnul_done:
	ret

.size	test_strrchr, .-test_strrchr
