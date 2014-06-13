        global _start
        global get_cor_value, set_cor_value, fix_positions
        global WorldLength, WorldWidth, GenNum, PrintAfter
        extern init_co, start_co, cor_run, resume
        extern scheduler, printer


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MACROS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro  syscall1 2
        mov     ebx, %2
        mov     eax, %1
        int     0x80
%endmacro

%macro  syscall3 4
        mov     edx, %4
        mov     ecx, %3
        mov     ebx, %2
        mov     eax, %1
        int     0x80
%endmacro

%macro  exit 1
        syscall1 1, %1
%endmacro

%macro  read 3
        syscall3 3, %1, %2, %3
%endmacro

%macro  write 3
        syscall3 4, %1, %2, %3
%endmacro

%macro  open 3
        push    ebx
        push    ecx
        push    edx
        syscall3 5, %1, %2, %3
        pop     edx
        pop     ecx
        pop     ebx
%endmacro

%macro  close 1
        syscall1 6, %1
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MACROS END;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STD_OUT:        equ 1
MAX_COR_NUM:    equ 100*100                                     ; maximum number of co-routines
ARG_NUM:        equ 6

section .data
        FD:
                dd 0                                            ; number of cols
        WorldLength:
                dd 0                                            ; number of cols
        WorldWidth:
                dd 0                                            ; number of rows
        GenNum:
                dd 0                                            ; number of generations the game will run
        PrintAfter:
                dd 0                                            ; after how many loops there will be a print call
        Buffer:
                db 0                                            ; temp buffer for reading
        DataArr: 
                times MAX_COR_NUM db 0                          ; char array of the board

section .rodata
        ArgError:
                db "Incorrect input. Please use as: ass3 <init file> <length> <width> <t> <k>", 10
        FileError:
                db "Incorrect input. init file was not found", 10
        FileContantsError:
                db "Incorrect input. init file contained invalid chars, or did not fit the given WorldLength WorldWidth given", 10
        NotANumber:
                db "Incorrect input. one or more of the arguments given (WorldLength, WorldLength, t or k) is not a number", 10

section .text

_start:
        enter   0, 0

        mov     edi, ebp                                        ; needed argument for init_from_args
        call    init_from_args
        call    init_array

        xor     ebx, ebx                                        ; scheduler is co-routine 0
        mov     edx, scheduler
        call    init_co                                         ; initialize scheduler state

        inc     ebx                                             ; printer is co-routine 1
        mov     edx, printer
        call    init_co                                         ; initialize printer state

        xor     ebx, ebx                                        ; starting co-routine = scheduler
        call    start_co                                        ; start co-routines
exiting:
        exit    0

; in case of incorrect argument number, will print an error and exit
argument_error:
        write   STD_OUT, ArgError, 74
        jmp     exiting

; in case of error while opening the file, will print an error and exit
no_file_error:
        write   STD_OUT, FileError, 41
        jmp     exiting

; in case of error while reading the numbers given (WorldLength, WorldLength, t and k), will print an error and exit
invalid_number:
        write   STD_OUT, NotANumber, 103
        jmp     exiting

; in case of error while pharsing the file, will print an error and exit
bad_file_contant:
        write   STD_OUT, FileContantsError, 106
        close   dword [FD]                                      ; close the file
        jmp     exiting

; initializes all global variables from arguments given. writes out error and exits if something was not right
init_from_args:
        push    ebp                                             ; edi points to original ebp. returns fd into eax
        mov     ebp, esp
        pusha
                                                                ; 12- first arg, 16- second arg, and so on
        mov     eax, dword [edi+4]                              ; compare argc to the expected number of arguments
        cmp     eax, ARG_NUM
        jne     argument_error                                  ; not enough args
        mov     eax, dword [edi+12]                             ; read file into eax
        open    eax, 0, 0                                       ; open file   
        cmp     eax, 0
        jl      no_file_error                                   ; display error with file
        mov     dword [FD], eax                                 ; save fd
        mov     eax, dword [edi+16]                             ; read length and parse it
        push    eax
        call    my_atoi
        add     esp, 4
        cmp     eax, 0                                          ; check for valid input
        jle     invalid_number
        mov     dword [WorldLength], eax
        mov     eax, dword [edi+20]                             ; read width and parse it
        push    eax
        call    my_atoi
        cmp     eax, 0                                          ; check for valid input
        jle     invalid_number
        add     esp, 4
        mov     dword [WorldWidth], eax
        mov     eax, dword [edi+24]                             ; read t and parse it
        push    eax
        call    my_atoi
        add     esp, 4
        cmp     eax, 0                                          ; check for valid input
        jle     invalid_number
        mov     dword [GenNum], eax
        mov     eax, dword [edi+28]                             ; read k and parse it
        push    eax
        call    my_atoi
        add     esp, 4
        cmp     eax, 0                                          ; check for valid input
        jle     invalid_number
        mov     dword [PrintAfter], eax

        popa
        mov     esp, ebp
        pop     ebp
        ret


; Logic: initializes an array of size WorldLength*WorldWidth, and initializes i*j cors.
; Implementation: the data array is DataArr. FD holds the fd. calculates the offset needed to reach a cell (i*jsize+j), and sets the cell value
;                 to be the value of the char read from the init file (for easier printing). inits cor[i,j] by adding 2 to the given offset (to 
;                 compensate for cor 0- scheduler, and cor 1- printer). drops the newline char from the file, and calls init_co.
init_array:
        push    ebp
        mov     ebp, esp
        pusha

        mov     esi, dword [FD]                                  ; esi is the file descriptor
        xor     eax, eax
        xor     ebx, ebx
        xor     edx, edx
.loop_i:
        cmp     eax, dword [WorldLength]
        je      .loop_i_end
.loop_j:
        cmp     ebx, dword [WorldWidth]
        je      .loop_j_end
        xor     ecx, ecx
        pusha
        read    esi, Buffer, 1                                  ; read char from file
        call    check_valid_input                               ; checks for valid input. returns from this call only if the input is valid
        popa
        mov     cl, byte [Buffer]                               ; each array cell holds the char value
        mov     edi, dword [WorldWidth]                         ; edi holds the jsize value
        imul    edi, eax                                        ; edi holds the i*jsize value
        add     edi, ebx                                        ; edi holds the i*jsize + j
        add     edi, 2                                          ; edi needs to account for the scheduler and printer cors, so + 2
        mov     edx, cor_run                                    ; cor_run is the function cor[i,j] does
        push    ebx                                             ; save ebx (ebx= j)
        push    ecx                                             ; save ecx (cor value)
        mov     ecx, ebx                                        ; ecx holds ebx
        mov     ebx, edi                                        ; ebx holds the cor number
        push    esi
        push    edi                                             ; save registers, they are needed for cor init
        mov     edi, eax
        mov     esi, ecx                                        ; edi = i, esi = j
        call    init_co                                         ; init cor i,j
        pop     edi
        pop     esi                                             ; restore registers saved
        sub     edi, 2                                          ; back to normal i,j notation for the number array
        pop     ecx                                             ; restore ecx (cor value)
        pop     ebx                                             ; restore ebx (ebx= j)
        mov     edx, DataArr                                    ; edx points to arr start
        add     edx, edi                                        ; edx points to arr[i,j]
        mov     byte [edx], cl                                  ; set arr[i,j] value
        inc     ebx                                             ; continue loop of j
        jmp     .loop_j
.loop_j_end:
        xor     ebx, ebx
        inc     eax                                             ; continue loop of i
        cmp     eax, dword [WorldLength]
        je      .loop_i_end
        pusha
        read    esi, Buffer, 1                                  ; drop the '\n' from the file
        cmp     byte [Buffer], 13                               ; in case the file was written in Windows (13 is '\r')
        popa
        jne     .after_stupid_windows
.stupid_windows:
        pusha
        read    esi, Buffer, 1                                  ; drop the '\n' from the file
        popa
.after_stupid_windows:
        cmp     byte [Buffer], 10                               ; in case the file contains invalid errors (10 is '\n')
        jne     bad_file_contant
        jmp     .loop_i
.loop_i_end:

        popa
        mov     esp, ebp
        pop     ebp
        ret

; Logic: checks that characters was read, and the character read was valid. if not, exits
; Implementation: checks that 1 character was read, and that it is either 1 or space. exits if one of those is not right
check_valid_input:
        push    ebp
        mov     ebp, esp
        
        pusha
        cmp     eax, 1
        jne     bad_file_contant
        cmp     byte [Buffer], ' '
        je      .valid
        cmp     byte [Buffer], '1'
        je      .valid
        jmp     bad_file_contant
.valid:
        popa
         
        mov     esp, ebp
        pop     ebp
        ret


; Logic: returns the value of array cell i,j. i and j (in that order) are arguments given in c calling convention.
; Implementation: the data array is DataArr. calculates the offset needed to reach a cell (i*jsize+j). returns the value of that cell in eax.
get_cor_value:
        push    ebp
        mov     ebp, esp
        
        sub     esp, 4                                          ; leave room for local variable
        pusha
        mov     ebx, dword [ebp+8]                              ; ebx holds j
        mov     eax, dword [ebp+12]                             ; eax holds i
        mov     ecx, dword [WorldWidth]                         ; ecx holds the jsize value
        imul    ecx, eax                                        ; ecx holds the i*jsize value
        add     ecx, ebx                                        ; ecx holds the i*jsize + j
        add     ecx, DataArr                                    ; ecx almost holds arr[i,j]
        xor     eax, eax
        mov     al, byte [ecx]                                  ; eax holds the cell value
        mov     dword [ebp-4], eax
        popa
        mov     eax, dword [ebp-4]                              ; eax holds the cell value
        
        mov     esp, ebp
        pop     ebp
        ret


; Logic: sets the value of array cell i,j to be newVal. newVal, i and j (in that order) are arguments given in c calling convention.
; Implementation: the data array is DataArr. calculates the offset needed to reach a cell (i*jsize+j). sets the value of that cell to be newVal.
set_cor_value:
        push    ebp
        mov     ebp, esp

        pusha
        mov     ebx, dword [ebp+8]                              ; ebx holds j
        mov     eax, dword [ebp+12]                             ; eax holds i
        mov     edx, dword [ebp+16]                             ; edx holds the value to be changed into
        mov     ecx, dword [WorldWidth]                         ; ecx holds the jsize value
        imul    ecx, eax                                        ; ecx holds the i*jsize value
        add     ecx, ebx                                        ; ecx holds the i*jsize + j
        add     ecx, DataArr                                    ; ecx almost holds arr[i,j]
        mov     byte [ecx], dl                                  ; set cell value to that of the first argument
        popa

        mov     esp, ebp
        pop     ebp
        ret

; Logic: for 2 given arguments i and j, checks if the cell [i,j] is out of the array bounds. corrects the given i,j to be the location of the cell,
;        as if the board is infinite, and once a "wall" is reached, starts from the other end of the board. this function operates under the 
;        assumption that a cell given is never more than 1 cell outside of the world borders. for expamle,  [-1,3] will turn into [WorldLength,3].
;        i and j (in that order) are given in c calling convention.
; Implementation: the data array is DataArr. checks if 0<=i<=WorldLength-1, and corrects it as needed, turing i=WorldLength into i=0, and i=-1 into
;                 i=WorldLength-1. does the same for j.
fix_positions:
        push    ebp
        mov     ebp, esp
        sub     esp, 8                                          ; leave room for local variable

        pusha
        mov     ebx, dword [ebp+8]                              ; ebx holds j
        mov     eax, dword [ebp+12]                             ; eax holds i
        cmp     eax, 0
        jl      .fix_left
        cmp     eax, dword [WorldLength]
        jge     .fix_right
.ret_from_i_fix:
        cmp     ebx, 0
        jl      .fix_up
        cmp     ebx, dword [WorldWidth]
        jge     .fix_down
.ret_from_j_fix:
        mov     dword [ebp-8], eax
        mov     dword [ebp-4], ebx
        popa
        mov     eax, dword [ebp-8]
        mov     ebx, dword [ebp-4]

        mov     esp, ebp
        pop     ebp
        ret
.fix_left:
        mov     eax, dword [WorldLength]
        dec     eax
        jmp     .ret_from_i_fix
.fix_right:
        mov     eax, 0
        jmp     .ret_from_i_fix
.fix_up:
        mov     ebx, dword [WorldWidth]
        dec     ebx
        jmp     .ret_from_j_fix
.fix_down:
        mov     ebx, 0
        jmp     .ret_from_j_fix

; Logic: pharses the string given (in C calling convention). if the string is not a number, returns 0.
; Implementation: takes the string byte by byte, checking for valid number each time. multiples the current result by 10, and adds the current
;                 number value. retuns the answer in eax.
my_atoi:
        push    ebp
        mov     ebp, esp                                        ; Entry code - set up ebp and esp
        sub     esp, 4
        pusha
        
        mov     ecx, dword [ebp+8]                              ; Get argument (pointer to string)
        xor     eax, eax
        xor     ebx, ebx
        mov     edi, 10
.my_atoi_loop:
        xor     edx, edx
        cmp     byte[ecx], 0
        jz      .my_atoi_end
        cmp     byte[ecx], '0'
        jl      .invalid
        cmp     byte[ecx], '9'
        jg      .invalid                                        ; number has to be between 0 to 9
        imul    edi
        mov     bl, byte[ecx]
        sub     bl, '0'
        add     eax, ebx
        inc     ecx
        jmp     .my_atoi_loop
.my_atoi_end:
        mov     dword [ebp-4], eax

        popa
        mov     eax, dword [ebp-4]
        mov     esp, ebp                                        ; Function exit code
        pop     ebp
        ret
.invalid:
        mov     eax, 0
        jmp     .my_atoi_end
