     name "kernel"
; this is a very basic example
; of a tiny operating system.
;
; this is kernel module!
;
; it is assumed that this machine
; code is loaded by 'micro-os_loader.asm'
; from floppy drive from:
;   cylinder: 0
;   sector: 2
;   head: 0


;=================================================
; how to test micro-operating system:
;   1. compile micro-os_loader.asm
;   2. compile micro-os_kernel.asm
;   3. compile writebin.asm
;   4. insert empty floppy disk to drive a:
;   5. from command prompt type:
;        writebin loader.bin
;        writebin kernel.bin /k
;=================================================

; directive to create bin file:
#make_bin#

; where to load? (for emulator. all these values are saved into .binf file)
#load_segment=0800#
#load_offset=0000#

; these values are set to registers on load, actually only ds, es, cs, ip, ss, sp are
; important. these values are used for the emulator to emulate real microprocessor state 
; after micro-os_loader transfers control to this kernel (as expected).
#al=0b#
#ah=00#
#bh=00#
#bl=00#
#ch=00#
#cl=02#
#dh=00#
#dl=00#
#ds=0800#
#es=0800#
#si=7c02#
#di=0000#
#bp=0000#
#cs=0800#
#ip=0000#
#ss=07c0#
#sp=03fe#



; this macro prints a char in al and advances
; the current cursor position:
putc    macro   char
        push    ax
        mov     al, char
        mov     ah, 0eh
        int     10h     
        pop     ax
endm


; sets current cursor position:
gotoxy  macro   col, row
        push    ax
        push    bx
        push    dx
        mov     ah, 02h
        mov     dh, row
        mov     dl, col
        mov     bh, 0
        int     10h
        pop     dx
        pop     bx
        pop     ax
endm


print macro x, y, attrib, sdat
LOCAL   s_dcl, skip_dcl, s_dcl_end
    pusha
    mov dx, cs
    mov es, dx
    mov ah, 13h
    mov al, 1
    mov bh, 0
    mov bl, attrib
    mov cx, offset s_dcl_end - offset s_dcl
    mov dl, x
    mov dh, y
    mov bp, offset s_dcl
    int 10h
    popa
    jmp skip_dcl
    s_dcl DB sdat
    s_dcl_end DB 0
    skip_dcl:    
endm



; kernel is loaded at 0800:0000 by micro-os_loader
org 0000h

; skip the data and function delaration section:
jmp start 
; The first byte of this jump instruction is 0E9h
; It is used by to determine if we had a sucessful launch or not.
; The loader prints out an error message if kernel not found.
; The kernel prints out "F" if it is written to sector 1 instead of sector 2.
           



;==== data section =====================

; welcome message:
msg  db "TURK-OS'A HO",158," GELD",152,"N",152,"Z!! Liste i",135,"in 'help' yaz",141,"n",141,"z.", 0 


cmd_size        equ 40    ; size of command_buffer
command_buffer  db cmd_size dup("b")
clean_str       db cmd_size dup(" "), 0
prompt          db  ">", 0


; commands:
chelp    db "help", 0
chelp_tail:
ccls     db "cls", 0
ccls_tail:           
cdraw  db "draw", 0
cdraw_tail:
cfactorial  db "factorial", 0
cfactorial_tail:
cprep  db "prepared by", 0
cprep_tail:
cquit    db "quit", 0
cquit_tail:
cexit    db "exit", 0
cexit_tail:
creboot  db "reboot", 0
creboot_tail:

    
help_msg db "T",154,"rk-os'",117," se",135,"ti",167,"iniz i",135,"in te",159,"ekk",154,"r ederiz!", 0Dh,0Ah
         db "Desteklenen komutlar",141,"n listesi:", 0Dh,0Ah
         db "               ", 0Dh,0Ah
         db "help             - Bu listeyi yazd",141,"r.", 0Dh,0Ah
         db "cls              - Ekran",141," temizleme.", 0Dh,0Ah
         db "draw             - ",128,"izim yapma." , 0Dh,0Ah
         db "factorial        - Faktoriyel alma.", 0Dh,0Ah
         db "prepared by      - Projeyi haz",141,"rlayanlar.", 0Dh,0Ah
         db "reboot           - Makineyi yeniden ba",159,"lat.", 0Dh,0Ah
         db "quit             - Reboot ile ayn",141,".", 0Dh,0Ah 
         db "exit             - Quit ile ayn",141,".", 0Dh,0Ah
         db "farkl",141," komutlar gelecek", 0Dh,0Ah, 0

unknown  db "Yanl",141,"",159," Komut " , 0 

;======================================

start:

; set data segment:
push    cs
pop     ds


; set default video mode 80x25:
mov     ah, 00h
mov     al, 03h
int     10h

; blinking disabled for compatibility with dos/bios,
; emulator and windows prompt never blink.
mov     ax, 1003h
mov     bx, 0      ; disable blinking.
int     10h


; *** the integrity check  ***
cmp [0000], 0E9h
jz integrity_check_ok
integrity_failed:  
mov     al, 'F'
mov     ah, 0eh
int     10h  
; wait for any key...
mov     ax, 0
int     16h
; reboot...
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h
jmp	0ffffh:0000h	 
integrity_check_ok:
nop
; *** ok ***
              


; clear screen:
call    clear_screen
                     
                       
; print out the message:
lea     si, msg
call    print_string


eternal_loop:
call    get_command

call    process_cmd

; make eternal loop:
jmp eternal_loop


;===========================================
get_command proc near

; set cursor position to bottom
; of the screen:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]

gotoxy  0, al

; clear command line:
lea     si, clean_str
call    print_string

gotoxy  0, al

; show prompt:
lea     si, prompt 
call    print_string


; wait for a command:
mov     dx, cmd_size    ; buffer size.
lea     di, command_buffer
call    get_string


ret
get_command endp
;===========================================

process_cmd proc    near

;//// check commands here ///
; set es to ds
push    ds
pop     es

cld     ; forward compare.

; compare command buffer with 'help'
lea     si, command_buffer
mov     cx, chelp_tail - offset chelp   ; size of ['help',0] string.
lea     di, chelp
repe    cmpsb
je      help_command

; compare command buffer with 'cls'
lea     si, command_buffer
mov     cx, ccls_tail - offset ccls  ; size of ['cls',0] string.
lea     di, ccls
repe    cmpsb
jne     not_cls
jmp     cls_command
not_cls:

; compare command buffer with 'draw'
lea     si, command_buffer
mov     cx, cdraw_tail - offset cdraw   ; size of ['draw,0] string.
lea     di, cdraw
repe    cmpsb
je      draw_command 

 ; compare command buffer with 'factorial'
lea     si, command_buffer
mov     cx, cfactorial_tail - offset cfactorial   ; size of ['factorial',0] string.
lea     di, cfactorial
repe    cmpsb
je      factorial_command 

 ; compare command buffer with 'prepared by'
lea     si, command_buffer
mov     cx, cprep_tail - offset cprep   ; size of ['prepared by',0] string.
lea     di, cprep
repe    cmpsb
je      prep_command


; compare command buffer with 'quit'
lea     si, command_buffer
mov     cx, cquit_tail - offset cquit ; size of ['quit',0] string.
lea     di, cquit
repe    cmpsb
je      reboot_command

; compare command buffer with 'exit'
lea     si, command_buffer
mov     cx, cexit_tail - offset cexit ; size of ['exit',0] string.
lea     di, cexit
repe    cmpsb
je      reboot_command

; compare command buffer with 'reboot'
lea     si, command_buffer
mov     cx, creboot_tail - offset creboot  ; size of ['reboot',0] string.
lea     di, creboot
repe    cmpsb
je      reboot_command

; ignore empty lines
cmp     command_buffer, 0
jz      processed


;////////////////////////////

; if gets here, then command is
; unknown...

mov     al, 1
call    scroll_t_area

; set cursor position just
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
dec     al
gotoxy  0, al

lea     si, unknown
call    print_string

lea     si, command_buffer
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed

; +++++ 'help' command ++++++
help_command:
call clear_screen

; scroll text area 9 lines up:
mov     al, 9
call    scroll_t_area

; set cursor position 9 lines
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
sub     al, 11 
gotoxy  0, al

lea     si, help_msg
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed




; +++++ 'cls' command ++++++
cls_command:
call    clear_screen
jmp     processed    
                 
                 
; +++++ 'draw' command ++++++

draw_command proc near
    
    call clear_screen
    
    gotoxy 3, 1   
    print 3, 1, 0000_1111b,"                                             "   
    print 3, 2, 0000_1111b,"                                :::          "  
    print 3, 3, 0000_1111b,"                      :::::::    :::::       " 
    print 3, 4, 0000_1111b,"                 ::::::::::::::::::::::      "                
    print 3, 5, 0000_1111b,"               ::::::::::::::::::::::::::    "
    print 3, 6, 0000_1111b,"              :::::::::::::::::::::::::::    "
    print 3, 7, 0000_1111b,"                ::::::::::::::::::::::::::   "
    print 3, 8, 0000_1111b,"                  :::::::::::::::::::::::::  "
    print 3,  9,0000_1111b,"                   ::::::::::::::::::::::::  "
    print 3, 10,0000_1111b,"                    :::::::::::::::::::::::  "
    print 3, 11,0000_1111b,"                      :::::::::::::::::::::  " 
    print 3, 12,0000_1111b,"                             ::::::::::::::  "  
    print 3, 13,0000_1111b,"                       ::     ::::::    :::  " 
    print 3, 14,0000_1111b,"                :      ::: :  :::::    ::::  " 
    print 3, 15,0000_1111b,"  :             ::::::::::::   ::::::::::::  "                 
    print 3, 16,0000_1111b,"  :              ::::::::::::  ::::::::::::  "
    print 3, 17,0000_1111b,"   ::              :::::::::    :::::::::::  "
    print 3, 18,0000_1111b,"    ::              :::::::  : ::::::::::::  "
    print 3, 19,0000_1111b,"                     :::::      ::::::::::   "
    print 3, 20,0000_1111b,"                     ::::::      ::::::::    "
    print 3, 21,0000_1111b,"                     ::::::::::::::::::::    "
    print 3, 22,0000_1111b,"                     :::::::::::::::::::     " 
    print 3, 23,0000_1111b,"                     ::::    :::::::::::     "
    print 3, 24,0000_1111b,"                     ::::::::::::::::::      "
    print 3, 25,0000_1111b,"                         :::::::::::::       "
    print 3, 26,0000_1111b,"                          ::::::::::         "
    print 3, 27,0000_1111b,"                            :::::::          "
    print 3, 28,0000_1111b,"                              :              "
    print 3, 29,0000_1111b,"                    ::::     ::              "        
    print 3, 30,0000_1111b,"                     :::::::::  :::          "    
    print 3, 31,0000_1111b,"                       ::::                  "
    print 3, 32,0000_1111b,"                         :                   "    
    
        
    
    mov ax, 0  ; wait for any key....
    int 16h
    ret
    draw_command endp 
    jmp 
 


; +++ 'quit', 'exit', 'reboot' +++
reboot_command:
call    clear_screen 
print 5,2,0000_1111b, "TURK-OS'U KULLANDIGINIZ ICIN TESEKKURLER!!"
print 5,3,0000_1111b, "Yeniden baslatmak icin herhangi bir tusa basin"
mov ax, 0  ; wait for any key....
int 16h

; store magic value at 0040h:0072h:
;   0000h - cold boot.
;   1234h - warm boot.
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h ; cold boot.
jmp	0ffffh:0000h	 ; reboot!

; ++++++++++++++++++++++++++

processed:
ret


;===========================================

; scroll all screen except last row
; up by value specified in al

scroll_t_area   proc    near

mov dx, 40h
mov es, dx  ; for getting screen parameters.
mov ah, 06h ; scroll up function id.
mov bh, 07  ; attribute for new lines.
mov ch, 0   ; upper row.
mov cl, 0   ; upper col.
mov di, 84h ; rows on screen -1,
mov dh, es:[di] ; lower row (byte).
dec dh  ; don't scroll bottom line.
mov di, 4ah ; columns on screen,
mov dl, es:[di]
dec dl  ; lower col.
int 10h

ret
scroll_t_area   endp

;===========================================




; get characters from keyboard and write a null terminated string 
; to buffer at DS:DI, maximum buffer size is in DX.
; 'enter' stops the input.
get_string      proc    near
push    ax
push    cx
push    di
push    dx

mov     cx, 0                   ; char counter.

cmp     dx, 1                   ; buffer too small?
jbe     empty_buffer            ;

dec     dx                      ; reserve space for last zero.


;============================
; eternal loop to get
; and processes key presses:

wait_for_key:

mov     ah, 0                   ; get pressed key.
int     16h

cmp     al, 0Dh                 ; 'return' pressed?
jz      exit


cmp     al, 8                   ; 'backspace' pressed?
jne     add_to_buffer
jcxz    wait_for_key            ; nothing to remove!
dec     cx
dec     di
putc    8                       ; backspace.
putc    ' '                     ; clear position.
putc    8                       ; backspace again.
jmp     wait_for_key

add_to_buffer:

        cmp     cx, dx          ; buffer is full?
        jae     wait_for_key    ; if so wait for 'backspace' or 'return'...

        mov     [di], al
        inc     di
        inc     cx
        
        ; print the key:
        mov     ah, 0eh
        int     10h

jmp     wait_for_key
;============================

exit:

; terminate by null:
mov     [di], 0

empty_buffer:
pop     dx
pop     di
pop     cx
pop     ax
ret
get_string      endp




; print a null terminated string at current cursor position, 
; string address: ds:si
print_string proc near    
push    ax      ; store registers...
push    si      ;

next_char:      
        mov     al, [si]
        cmp     al, 0
        jz      printed
        inc     si
        mov     ah, 0eh ; teletype function.
        int     10h
        jmp     next_char
printed:

pop     si      ; re-store registers...
pop     ax      ;

ret
print_string endp



; clear the screen by scrolling entire screen window,
; and set cursor position on top.
; default attribute is set to white on blue.
clear_screen proc near
        push    ax      ; store registers...
        push    ds      ;
        push    bx      ;
        push    cx      ;
        push    di      ;

        mov     ax, 40h
        mov     ds, ax  ; for getting screen parameters.
        mov     ah, 06h ; scroll up function id.
        mov     al, 0   ; scroll all lines!
        mov     bh, 0000_1111b  ; attribute for new lines.
        mov     ch, 0   ; upper row.
        mov     cl, 0   ; upper col.
        mov     di, 84h ; rows on screen -1,
        mov     dh, [di] ; lower row (byte).
        mov     di, 4ah ; columns on screen,
        mov     dl, [di]
        dec     dl      ; lower col.
        int     10h

        ; set cursor position to top
        ; of the screen:
        mov     bh, 0   ; current page.
        mov     dl, 8   ; col.
        mov     dh, 8   ; row.
        mov     ah, 02
        int     10h

        pop     di      ; re-store registers...
        pop     cx      ;
        pop     bx      ;
        pop     ds      ;
        pop     ax      ;

        ret
clear_screen endp



;++++++ 'factorial' command ++++++
factorial_command:


; this example gets the number from the user,
; and calculates factorial for it.
; supported input from 0 to 8 inclusive!

name "fact"

call clear_screen

; this macro prints a char in AL and advances
; the current cursor position:
put    macro   char
        push    ax
        mov     al, char
        mov     ah, 0eh
        int     10h     
        pop     ax
endm




jmp startf


result dw ?
     


startf:
     
; get first number:

	mov al, 1
	mov bh, 0
	mov bl, 0000_1111b
	mov cx, n1end - offset msg1 ; calculate message size. 
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msg1
	mov ah, 13h
	int 10h 
	mov ah, 01h
	int 16h
	
jmp n1end
msg1 db 0Dh,0Ah, '0-8 aras',141,' say',141,' giriniz: '
n1end:

call    scan_numf


; factorial of 0 = 1:
mov     ax, 1
cmp     cx, 0
je      print_result

; move the number to bx:
; cx will be a counter:

mov     bx, cx

mov     ax, 1
mov     bx, 1

calc_it:
mul     bx
cmp     dx, 0
jne     overflow
inc     bx
loop    calc_it

mov result, ax


print_result:

; print result in ax:
    mov al, 1
	mov bh, 0
	mov bl, 0000_1111b
	mov cx, n2 - offset msg2 ; calculate message size. 
	mov dl, 2
	mov dh, 2
	push cs
	pop es
	mov bp, offset msg2
	mov ah, 13h
	int 10h 
jmp n2
msg2 db 0Dh,0Ah, 'Fakt',148,'riyel: '
n2:

cmp result, 0
je  is_0


mov     ax, result
call    print_num_unsf
jmp     exitf


overflow:
    mov al, 1
	mov bh, 0
	mov bl, 0000_1111b
	mov cx, n3 - offset msg3 ; calculate message size. 
	mov dl, 2
	mov dh, 2
	push cs
	pop es
	mov bp, offset msg3
	mov ah, 13h
	int 10h 
jmp n3
msg3 db 0Dh,0Ah, 'Sonu',135,' ',135,'ok b',129,'y',129,'k!', 0Dh,0Ah, '0-8 aras',141,' de',167,'er giriniz.'
n3:
jmp     startf

is_0:
    mov ax, 1
    call    print_num_unsf
    jmp     exitf

exitf:

; wait for any key press:
mov ah, 0
int 16h

ret




             



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; these functions are copied from emu8086.inc ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; gets the multi-digit SIGNED number from the keyboard,
; and stores the result in CX register:
SCAN_NUMf        PROC    NEAR
        PUSH    DX
        PUSH    AX
        PUSH    SI
        
        MOV     CX, 0

        ; reset flag:
        MOV     CS:make_minusf, 0

next_digitf:

        ; get char from keyboard
        ; into AL:
        MOV     AH, 00h
        INT     16h
        ; and print it:
        MOV     AH, 0Eh
        INT     10h

        ; check for MINUS:
        ;CMP     AL, '-'
        ;JE      set_minusf

        ; check for ENTER key:
        CMP     AL, 0Dh  ; carriage return?
        JNE     not_crf
        JMP     stop_inputf
not_crf:


        CMP     AL, 8                   ; 'BACKSPACE' pressed?
        JNE     backspace_checkedf
        MOV     DX, 0                   ; remove last digit by
        MOV     AX, CX                  ; division:
        DIV     CS:ten                  ; AX = DX:AX / 10 (DX-rem).
        MOV     CX, AX
        PUT    ' '                     ; clear position.
        PUT    8                       ; backspace again.
        JMP     next_digitf
backspace_checkedf:       


        ; allow only digits:
        CMP     AL, '0'
        JAE     ok_AE_0f
        JMP     remove_not_digitf
ok_AE_0f:        
        CMP     AL, '9'
        JBE     ok_digitf
remove_not_digitf:       
        PUT    8       ; backspace.
        PUT    ' '     ; clear last entered not digit.
        PUT    8       ; backspace again.        
        JMP     next_digitf ; wait for next input.       
ok_digitf:


        ; multiply CX by 10 (first time the result is zero)
        PUSH    AX
        MOV     AX, CX
        MUL     CS:ten                  ; DX:AX = AX*10
        MOV     CX, AX
        POP     AX

        ; check if the number is too big
        ; (result should be 16 bits)
        CMP     DX, 0
        JNE     too_bigf

        ; convert from ASCII code:
        SUB     AL, 30h

        ; add AL to CX:
        MOV     AH, 0
        MOV     DX, CX      ; backup, in case the result will be too big.
        ADD     CX, AX
        JC      too_big2f    ; jump if the number is too big.

        JMP     next_digitf

set_minusf:
        MOV     CS:make_minusf, 1
        JMP     next_digitf

too_big2f:
        MOV     CX, DX      ; restore the backuped value before add.
        MOV     DX, 0       ; DX was zero before backup!
too_bigf:
        MOV     AX, CX
        DIV     CS:ten  ; reverse last DX:AX = AX*10, make AX = DX:AX / 10
        MOV     CX, AX
        PUT    8       ; backspace.
        PUT    ' '     ; clear last entered digit.
        PUT    8       ; backspace again.        
        JMP     next_digitf ; wait for Enter/Backspace.
        
        
stop_inputf:
        ; check flag:
        CMP     CS:make_minusf, 0
        JE      not_minusf
        NEG     CX
not_minusf:

        POP     SI
        POP     AX
        POP     DX
        RET
make_minusf      DB      ?       ; used as a flag.
SCAN_NUMf        ENDP





; this procedure prints number in AX,
; used with PRINT_NUM_UNS to print signed numbers:
PRINT_NUMf       PROC    NEAR
        PUSH    DX
        PUSH    AX

        CMP     AX, 0
        JNZ     not_zerof

        PUT    '0'
        JMP     printedf

not_zerof:
        ; the check SIGN of AX,
        ; make absolute if it's negative:
        CMP     AX, 0
        JNS     positivef
        NEG     AX

        PUT    '-'

positivef:
        CALL    PRINT_NUM_UNSf
printedf:
        POP     AX
        POP     DX
        RET
PRINT_NUMf       ENDP



; this procedure prints out an unsigned
; number in AX (not just a single digit)
; allowed values are from 0 to 65535 (FFFF)
PRINT_NUM_UNSf   PROC    NEAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        ; flag to prevent printing zeros before number:
        MOV     CX, 1

        ; (result of "/ 10000" is always less or equal to 9).
        MOV     BX, 10000       ; 2710h - divider.

        ; AX is zero?
        CMP     AX, 0
        JZ      print_zerof

begin_printf:

        ; check divider (if zero go to end_print):
        CMP     BX,0
        JZ      end_printf

        ; avoid printing zeros before number:
        CMP     CX, 0
        JE      calcf
        ; if AX<BX then result of DIV will be zero:
        CMP     AX, BX
        JB      skipf
calcf:
        MOV     CX, 0   ; set flag.

        MOV     DX, 0
        DIV     BX      ; AX = DX:AX / BX   (DX=remainder).

        ; print last digit
        ; AH is always ZERO, so it's ignored
        ADD     AL, 30h    ; convert to ASCII code.
        PUT    AL


        MOV     AX, DX  ; get remainder from last div.

skipf:
        ; calculate BX=BX/10
        PUSH    AX
        MOV     DX, 0
        MOV     AX, BX
        DIV     CS:ten  ; AX = DX:AX / 10   (DX=remainder).
        MOV     BX, AX
        POP     AX

        JMP     begin_printf
        
print_zerof:
        PUT    '0'
        
end_printf:

        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
PRINT_NUM_UNSf   ENDP



ten             DW      10      ; used as multiplier/divider by SCAN_NUM & PRINT_NUM_UNS.




       
                  
; ++++++ 'Prepared By ' Command ++++++     
                             
prep_command:

call clear_screen                             
                             
 

     

	mov al, 1
	mov bh, 0
	mov bl, 0000_1111b
	mov cx, n33end - offset msg33 ; calculate message size. 
	mov dl, 0
	mov dh, 0
	push cs ;cs yi yedekleyerek stack e atip sonra onu es ile cagiriyor
	pop es
	mov bp, offset msg33
	mov ah, 13h
	int 10h 
	mov ah, 01h
	int 16h
	
jmp n33end
msg33 db 0Dh,0Ah, 'Mustafa Emre KILIN',128,' 20217170039 '
n33end: 

  
    
    mov al, 1
	mov bh, 0
	mov bl, 0000_1111b
	mov cx, n38end - offset msg38 ; calculate message size. 
	mov dl, 2
	mov dh, 2
	push cs
	pop es
	mov bp, offset msg38
	mov ah, 13h
	int 10h 
	
	
jmp n38end
msg38 db 0Dh,0Ah,'Salih Onur KARAKU',158,' 2020717017 ' 
n38end: 


           
       

jmp processed




    
             
    