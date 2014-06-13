        global scheduler
        extern resume, end_co
        extern WorldLength, WorldWidth, GenNum, PrintAfter

section .text

; Logic: call all co-routines twice- once for checking future value, and  once for setting the calculated value.
; Implementation: initializes global values. for GenNum times, resume all co-routines once, and then resume all co-routines again. after each GenNum
;                 iteration, check if GenNum modulo PrintAfter is 0, and print board if necessary. after GenNum iteration, calls end_co.
scheduler:
        xor 	edi, edi										; edi loops until t
loop_gens:
		cmp 	edi, dword [GenNum]
		je 		end_loop

		call 	loop_all_cors
		call 	loop_all_cors
		xor 	edx, edx
		mov 	ebx, dword [PrintAfter]
		mov 	eax, edi
		idiv 	ebx
		cmp 	edx, 0 											; check if (i mod k) == 0
		jne 	.after_printing
		mov		ebx, 1
		call 	resume 											; call the printer
.after_printing:
		inc 	edi
		jmp 	loop_gens
end_loop:
		call 	resume             								; resume printer
        call 	end_co             								; stop co-routines


; Logic: call all co-routines twice- once for checking future value, and  once for setting the calculated value.
; Implementation: initializes global values. for GenNum time, resume all co-routines once, and then resume all co-routines again. after each GenNum
;                 iteration, check if GenNum modulo PrintAfter is 0, and print board if necessary. after GenNum iteration, calls end_co.
loop_all_cors:
		push    ebp
    	mov     ebp, esp
    	pusha
    	
    	xor     eax, eax
    	xor     ebx, ebx
.loop_i:
    	cmp     eax, dword [WorldLength]
    	je      .loop_i_end
.loop_j:
        cmp     ebx, dword [WorldWidth]
        je      .loop_j_end
        mov     ecx, dword [WorldWidth]                         ; ecx holds the jsize value
        imul    ecx, eax                                        ; ecx holds the i*jsize value
        add     ecx, ebx                                        ; ecx holds the i*jsize + j
        add     ecx, 2                                          ; ecx needs to account for the scheduler and printer cors, so + 2
        push 	ebx 											; save ebx (ebx= j)
        mov 	ebx, ecx
        call 	resume 											; resume cor i,j
        pop 	ebx 											; restore ebx (ebx= j)
        inc     ebx
        jmp     .loop_j
.loop_j_end:
        xor     ebx, ebx
        inc     eax                                     		; continue loop of i
        jmp     .loop_i
.loop_i_end:
		
		popa
        mov     esp, ebp
        pop     ebp
        ret

