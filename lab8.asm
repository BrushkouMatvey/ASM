.model tiny
.code
org 100h 

begin:
    jmp start


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
   
bad_params_message      db "Bad cmd arguments", '$'
message                 db "my message", '$'
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
alarm_hours             db 0   
alarm_minutes           db 0 
alarm_seconds           db 0
signal_duration         dw 0    
buffer                  db max_size + 2 dup(0) 

strlen proc
    push bx
    push si  
    
    xor ax, ax 
start_calculation:
    mov bl, ds:[si] 
    cmp bl, endl_char
    je end_calculation 
    
    inc si
    inc ax        
    jmp start_calculation
    
end_calculation:
    pop si 
    pop bx
    ret
endp   


conv proc 
    push ax         ;convert max_length string to max_length number
    push bx
    push cx
    
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
                                  
    mov dx, ax
    
    pop si
    pop di 
    pop cx
    pop bx
    pop ax 
    ret
   ;popa 
endm

rewrite_word proc
    push ax
    push cx
    push di        
    
loop_parse_word:
    mov al, ds:[si]            
    cmp al, space_char        
    je is_stopped_char
    cmp al, new_line_char
    je is_stopped_char
    cmp al, tabulation
    je is_stopped_char
    cmp al, return_char
    je is_stopped_char
    cmp al, endl_char
    je is_stopped_char
    mov es:[di], al
    inc di
    inc si
    loop loop_parse_word 
    
is_stopped_char:
    mov al, endl_char
    mov es:[di], al
    inc si                  ;new word in cmd_text  
    
    pop di
    pop cx
    pop ax
    ret
endp    

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
    call conv 
    mov alarm_hours, dl 
    is_empty_line number_text bad_cmd
    
    mov di, offset number_text
    call rewrite_word 
    call conv 
    mov alarm_minutes, dl
    is_empty_line number_text bad_cmd
    
    mov di, offset number_text
    call rewrite_word 
    call conv
    mov alarm_seconds, dl 
    is_empty_line number_text bad_cmd

    mov di, offset number_text
    call rewrite_word 
    call conv        
    mov signal_duration, dx 
    is_empty_line number_text bad_cmd 
    
    pusha      
    mov al, alarm_hours
    cmp al, 24
    jae bad_cmd 
    
    mov al, alarm_minutes
    cmp al, 60
    jae bad_cmd 
    
    mov al, alarm_seconds
    cmp al, 60
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
    and al, 11111100b
    out 61h, al
    pop ax
    ret
Speaker_Off endp

beep proc
    call Speaker_On
    xor cx, cx  
    int 15h
    call Speaker_Off
endp    

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
    push dx
    push ax
    push bx
    ;mov ax, 1000
;    mov bx, signal_duration
;    mul bx  
;    call beep 
    show_str message
    pop bx
    pop ax 
    pop dx
endp

set_alarm proc
    pusha   
    mov ah,07h       ; перед тем как установить сбрасываем его
    int 1Ah 
    mov ah, 06h
    mov ch, alarm_hours
    mov cl, alarm_minutes
    mov dh, alarm_seconds
    int 1Ah 
    popa
    ret
endp     

start:
    mov ax, cs
    mov es, ax
    read_cmd
    mov ds, ax 
    
    call read_from_cmd 
    call set_alarm
    mov ax, 354Ah ;get old_handler to bx
    int 21h
    
    mov word ptr old_handler, bx ;save old_handler
    mov word ptr old_handler + 2, es
    
    mov ax, 254Ah
    lea dx, int_handler
    int 21h
    jmp finish

finish:
    mov ax, 3100h ;keep program resident
    mov dx, (start - begin + 10Fh) / 16 ;size of resident program in paragraphs
    int 21h
    ret
end_main:
    mov ah, 4ch
    int 21
    
end begin    
    
  