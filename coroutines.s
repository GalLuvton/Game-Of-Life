;;; This is a simplified co-routines implementation:
;;; CORS contains just stack tops, and we always work
;;; with co-routine indexes.
        global init_co, start_co, cor_run, end_co, resume
        extern get_cor_value, set_cor_value, fix_positions

BABY_AGE:       equ 31h                                         ; value of '1'- baby cell age
MAX_AGE:        equ 39h                                         ; value of '9'- max cell age
DEAD_CELL:      equ 20h                                         ; value of ' '- dead cell
maxcors:        equ 100*100+2                                   ; maximum number of co-routines
stacksz:        equ 128                                         ; per-co-routine stack size


section .bss

stacks: resb maxcors * stacksz                                  ; co-routine stacks
cors:   resd maxcors                                            ; simply an array with co-routine stack tops
curr:   resd 1                                                  ; current co-routine
origsp: resd 1                                                  ; original stack top
tmp:    resd 1                                                  ; temporary value


section .text

                                                                ;; ebx = co-routine index to initialize
                                                                ;; edx = co-routine start
                                                                ;; edi = i, esi = j
                                                                ;; other registers will be visible to co-routine after "start_co"
init_co:
        push    eax                                             ; save eax (on caller stack)
	push    edx
	mov     edx, 0
	mov     eax, stacksz
        imul    ebx			                        ; eax = co-routine stack offset in stacks
        pop     edx
	add     eax, stacks + stacksz                           ; eax = top of (empty) co-routine stack
        mov     [cors + ebx*4], eax                             ; store co-routine stack top
        pop     eax                                             ; restore eax (from caller stack)

        mov     [tmp], esp                                      ; save caller stack top
        mov     esp, [cors + ebx*4]                             ; esp = co-routine stack top

        push    edi                                             ; edi = i
        push    esi                                             ; esi = j
        push    edx                                             ; save return address to co-routine stack
        pushf                                                   ; save flags
        pusha                                                   ; save all registers
        mov     [cors + ebx*4], esp                             ; update co-routine stack top

        mov     esp, [tmp]                                      ; restore caller stack top
        ret                                                     ; return to caller

                                                                ;; ebx = co-routine index to start
start_co:
        pusha                                                   ; save all registers (restored in "end_co")
        mov     [origsp], esp                                   ; save caller stack top
        mov     [curr], ebx                                     ; store current co-routine index
        jmp     resume.cont                                     ; perform state-restoring part of "resume"


end_co:
        mov     esp, [origsp]                                   ; restore stack top of whoever called "start_co"
        popa                                                    ; restore all registers
        ret                                                     ; return to caller of "start_co"

                                                                ;; ebx = co-routine index to switch to
resume:                                                         ; "call resume" pushed return address
        pushf                                                   ; save flags to source co-routine stack
        pusha                                                   ; save all registers
        xchg    ebx, [curr]                                     ; ebx = current co-routine index
        mov     [cors + ebx*4], esp                             ; update current co-routine stack top
        mov     ebx, [curr]                                     ; ebx = destination co-routine index
.cont:
        mov     esp, [cors + ebx*4]                             ; get destination co-routine stack top
        popa                                                    ; restore all registers
        popf                                                    ; restore flags
        ret                                                     ; jump to saved return address

; Logic: calculate future age, give scheduler control, save future age, give scheduler control, repeat forever.
; Implementation: call cor_first_run, resume scheduler, call cor_second_run, resume scheduler. repeat forever.
cor_run:
        pop     esi                                             ; esi = j
        pop     edi                                             ; edi = i
cor_loop:
        call    cor_first_run                                   ; eax holds the future value
        push    eax
        xor     ebx, ebx
        call    resume                                          ; resume scheduler                                                          
        call    cor_second_run                                  ; eax holds the future value
        add     esp, 4
        xor     ebx, ebx
        call    resume                                          ; resume scheduler                                                  
        jmp     cor_loop

; Logic: calculate future age, based on the rules of conways game of life.
; Implementation: count the living cells around the current co-routine. check current co-routine age. if current co-routine is alive, and has
;                 2 or 3 living co-routines around it, increase age (up to MAX_AGE). else, die (set to DEAD_CELL). if current co-routine is
;                 dead, and has 3 living co-routines around it, revive (set to BABY_AGE). else, stay dead. calculated future age is saved in eax.
cor_first_run:
        push    ebp                                             ; all cors hold position in edi, esi (corresponding i, j)
        mov     ebp, esp
        sub     esp, 4                                          ; leave room for local variable
        pusha

        mov     dword [ebp-4], 0                                ; counter of living cells around this one
        mov     ecx, -1
        mov     edx, -1                                         ; ecx, edx are loop variables
.inner_loop_i:
        cmp     ecx, 2
        je      .inner_loop_i_end
.inner_loop_j:
        cmp     edx, 2
        je      .inner_loop_j_end
        cmp     ecx, 0
        jne      .skip_check                                    ; check for ecx = 0, edx = 0
        cmp     edx, 0
        je      .cont                                           ; if ecx = 0, edx = 0, skip cell
.skip_check:
        mov     eax, edi
        mov     ebx, esi                                        ; eax, ebx will hold neighbor cell position
        add     eax, ecx
        add     ebx, edx                                        ; eax, ebx hold raw neighbor position. may be out of board bounds
        push    eax
        push    ebx
        call    fix_positions                                   ; eax, ebx hold fixed neighbor position
        add     esp, 8
        push    eax
        push    ebx
        call    get_cor_value                                   ; eax holds the value of cor[i-ecx, j-edx]
        add     esp, 8
        cmp     eax, DEAD_CELL
        je      .cont
        inc     dword [ebp-4]                                   ; increase the counter
.cont:
        inc     edx                                             ; continue inner_loop of j
        jmp     .inner_loop_j
.inner_loop_j_end:
        mov     edx, -1
        inc     ecx                                             ; continue inner_loop of i
        jmp     .inner_loop_i
.inner_loop_i_end:
        push    edi
        push    esi
        call    get_cor_value                                   ; eax holds the value of this cor
        add     esp, 8
        cmp     eax, DEAD_CELL                                  ; if dead
        je      .was_dead
        cmp     dword [ebp-4], 2
        je      .stay_alive
        cmp     dword [ebp-4], 3
        je      .stay_alive
        xor     eax, eax                                        ; set returned value to 'dead'
        mov     eax, DEAD_CELL
        mov     dword [ebp-4], eax
        jmp     .done_fucking_with_age
.stay_alive:
        cmp     eax, MAX_AGE                                    ; if max age, dont increase age
        je      .dont_age
        inc     eax                                             ; if not dead or max age
        mov     dword [ebp-4], eax                              ; set returned value to be current value + 1
        jmp     .done_fucking_with_age
.was_dead:
        cmp     dword [ebp-4], 3
        je      .revive
        mov     dword [ebp-4], DEAD_CELL
        jmp     .done_fucking_with_age
.dont_age:
        mov     dword [ebp-4], MAX_AGE                          ; set returned value to be current value
        jmp     .done_fucking_with_age
.revive:
        mov     dword [ebp-4], BABY_AGE                         ; set returned value to be a new baby cell
.done_fucking_with_age:
        popa
        mov     eax, dword [ebp-4]                              ; eax holds the future cell value
        mov     esp, ebp
        pop     ebp
        ret


; Logic: set current co-routine age to a given age.
; Implementation: get new age, call set_cor_value.
cor_second_run:
        push    ebp
        mov     ebp, esp
        pusha
        mov     eax, dword [ebp+8]                              ; get new age from arguemnt
        push    eax                                             ; first arg is new age
        push    edi                                             ; second arg is i
        push    esi                                             ; third arg is j
        call    set_cor_value
        add     esp, 12
        
        popa
        mov     esp, ebp
        pop     ebp
        ret
