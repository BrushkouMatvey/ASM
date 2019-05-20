.model tiny
.code
.386
 
org 100h

begin:

macro is_empty_line text_line, marker  
	push si
	
	mov si, offset text_line
	call strlen
	
	pop si
	cmp ax, 0    
	je marker 
endm

;source - number of register, reciver - register for result value 
get_part_time macro source, receiver
      mov al, source
      out 70h, al       ;print register into port
      in al, 71h        ;get info from register
      mov receiver, al
endm

;value - bcd number, source - place for result  
bcd_to_int macro value, source
      pusha                     
      
      mov al,value
      and al,00001111b    ;younger 4 bits
      add al, '0'         ;from string to number
      mov cs:source[2], al     ;write first digit into time string

      mov al,value
      shr al, 4           ;>>4, now we have older 4 bits
      add al, '0'         ;string into number
      mov cs:source[0], al    ;write secind digit
        
      popa     
endm

macro show_str out_str
	push ax
	push dx
	
	mov ah, 9h
	mov dx, offset out_str
	int 21h          
	
	mov dl, 10    
	mov ah, 2h
	int 21h      
	
	mov dl, 13    
	mov ah, 2h
	int 21h    
	
	pop dx
	pop ax
endm  
 
macro read_cmd
    xor ch, ch
	mov cl, ds:[80h] ; number of symbols in cmd          		
	mov cmd_size, cl ; 		
	mov si, 81h      ; adress of arguments 
	mov di, offset cmd_text 
	rep movsb   ;get symbols from cmd with adress to DI from SI
endm

macro conv num
    pusha 		;convert max_length string to max_length number

    push di
    push si    
               
    mov di, offset number_text
    mov si, offset number_text
    xor cx, cx               
    call strlen                   
    mov cx, ax  ;CX - length of number_text
    xor ax, ax                
    mov si, 10                   
    xor bh, bh                       
m1:
    mul si
    jc bad_cmd
                          
    mov bl, [di]                 
    cmp bl, 30h                                                                                                           
    
    jl bad_cmd                     
    cmp bl, 39h
    jg bad_cmd                     
    sub bl, 30h                  
    add ax, bx                   
    inc di                      
    loop m1 
                                  
    mov num, ax
    
    pop si
    pop di
    popa 
endm    

read_from_cmd proc
    push bx
    push cx
    push dx
    
    mov cl, cmd_size
    xor ch, ch
    mov si, offset cmd_text
    mov di, offset buffer
    call rewrite_word
next_word:
    mov di, offset number_text
    call rewrite_word  
    conv alarm_hours
    is_empty_line number_text bad_cmd
    
    mov di, offset number_text
    call rewrite_word
    conv alarm_minutes
    is_empty_line number_text bad_cmd
    
    mov di, offset number_text
    call rewrite_word
    conv alarm_seconds
    is_empty_line number_text bad_cmd

    mov di, offset number_text
    call rewrite_word
    conv signal_duration
    is_empty_line number_text bad_cmd 
    
    pusha      
	mov ax, alarm_hours
	cmp ax, 24
	jae bad_cmd 
	
	mov ax, alarm_minutes
	cmp ax, 60
	jae bad_cmd 
	
	mov ax, alarm_seconds
	cmp ax, 60
	jae bad_cmd

	mov ax, signal_duration
	cmp ax, 10
	jae bad_cmd
    popa
    
    mov di, offset buffer
	call rewrite_word
	is_empty_line buffer, cmd_is_good
	
bad_cmd:
	show_str bad_params_message
	mov ax, 1
	jmp endproc                   
	
cmd_is_good:
	mov ax, 0        

endproc:
	pop dx
	pop cx
	pop bx
	cmp ax, 0                          
	jne end_main
	ret
endp

Speaker_On proc near
    push ax
    in al, 61h ;read port
    or al, 00000011b;bits 0 and 1 into 1
    out 61h, al
    pop ax
    ret
Speaker_On endp

Speaker_Off proc near
    push ax
    in al, 61h
    and al, 11111100h
    out 61h, al
    pop ax
    ret
Speaker_Off endp 

get_time proc
    pusha
    get_part_time 0, dl ;seconds 
    ;bcd_to_int dl, time_str[12]
    
    get_part_time 2, dl ;minutes
    ;bcd_to_int dl, time_str[6]
    
    get_part_time 4, dl ;hours
    ;bcd_to_int dl, time_str[0]
    popa
    ret
endp    

int_handler proc far 
    pushf
    cli
    call set_Alarm
    call alarm_Beep
    jmp cs:old_handler    
endp

;процедура обработчика прерываний
int_handler proc far
    pushf               ;сохранение флагов
    call cs:old_int     ;вызов старого обработчика
    pusha
    
    push ds
    push es
    ;настройка регистра ds на данные резидентной программы
    push cs
    pop ds
    ;обработка данных
    ;.......
    ;восстановление регистров из стека
    pop es
    pop ds
    popa
    ;возврат из обработчика
    iret
int_handler endp
   
start:
    mov ax, cs
    mov es, ax
    read_cmd
    mov ds, ax 
    
    call read_from_cmd
    mov ax, 3587h ;get old_handler to bx
    int 21h
    
    mov word ptr old_handler, bx ;save old_handler
    mov word ptr old_handler + 2, es
    
    mov ax, 251Ch
    lea dx, int_handler
    int 21h
    
    jmp finish

fnish:
    mov ax, 3100h ;keep program resident
    mov dx, (start - begin + 10Fh) / 16 ;size of resident program in paragraphs
    int 21h
    ret
end_main:
    mov ah, 4ch
    int 21
    
end begin    
    
space_char              equ 32  
new_line_char           equ 13
return_char             equ 10
tabulation              equ 9
endl_char               equ 0 

max_size                equ 126 
cmd_size                db ?
cmd_text                db max_size + 2 dup(0)
number_text             db max_size + 2 dup(0)
          
num_10                  db 10
old_handler             dd ?
   
temp_length             dw 0     
alarm_hours             dw 0   
alarm_minutes           dw 0 
alarm_seconds           dw 0
signal_duration         dw 0  	
buffer                  db max_size + 2 dup(0)   