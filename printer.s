        global printer
        extern resume, get_cor_value
        extern WorldLength, WorldWidth

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MACROS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro  syscall3 4
        mov     edx, %4
        mov     ecx, %3
        mov     ebx, %2
        mov     eax, %1
        int     0x80
%endmacro

%macro  write 3
        syscall3 4, %1, %2, %3
%endmacro
stdout:         equ   1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MACROS END;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data
        Buffer:
                db 0                                            ; temp buffer for printing
        newline:  
                db 10                                           ; newline after each matrix line
        newgen:
                db "*"                                          ; newline after each generation
        wall:
                db "|"                                          ; char before and after each line

section .text

; Logic: print the board once, and resume the scheduler.
; Implementation: initializes global values. loop over all cells, and get cell value (value is in char format). print given value.
;                 also prints a box around the board, for better board visability.
printer:
        %ifdef _print
		call    newgen_loop                                     ; print the board upper wall
        %endif
		xor     eax, eax
        xor     ebx, ebx
.loop_i:
        cmp     eax, dword [WorldLength]
        je      .loop_i_end
.loop_j:
        cmp     ebx, dword [WorldWidth]
        je      .loop_j_end
        cmp     ebx, 0                                          ; prints the board left wall
        je      .line_start
.ret_from_output_format:
        push    eax                                             ; save eax (eax= i)
        push    eax
        push    ebx
        call    get_cor_value                                   ; get cell value
        add     esp, 8
        mov     byte [Buffer], al
        pusha
        write   stdout, Buffer, 1                               ; print cell value
        popa
        pop     eax                                             ; restore eax  (eax= i)
        inc     ebx
        jmp     .loop_j
.loop_j_end:
        xor     ebx, ebx
        inc     eax                                             ; continue loop of i
        %ifdef _print
		pusha
        write   stdout, wall, 1                                 ; prints the board right wall
        popa
        %endif
		cmp     eax, dword [WorldLength]                        ; check that this is not the last line
        je      .skip_newline
        pusha                                                   ; if it is, dont print a newline
        write   stdout, newline, 1
        popa
.skip_newline:
        jmp     .loop_i
.loop_i_end:
		%ifdef _print
        call    newgen_loop                                     ; print the board lower wall
		%endif
        xor     ebx, ebx
        call    resume                                          ; resume scheduler
        jmp     printer
.line_start:
		%ifdef _print
        pusha
        write   stdout, wall, 1                                 ; part of output formatting
        popa
		%endif
        jmp     .ret_from_output_format


%ifdef _print
; Logic: print the board upper/lower bound char ('*'), .
; Implementation: prints the board upper/lower bound char WorldWidth+2 times
newgen_loop:
        push    ebp
        mov     ebp, esp
        pusha

        write   stdout, newline, 1
        xor     eax, eax
        mov     ebx, dword [WorldWidth]
        add     ebx, 2
.loop:
        cmp     eax, ebx
        je      .loop_end
        pusha
        write   stdout, newgen, 1                               ; part of output formatting
        popa
        inc     eax
        jmp     .loop
.loop_end:
        write   stdout, newline, 1

        popa
        mov     esp, ebp
        pop     ebp
        ret
%endif

