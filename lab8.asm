.model tiny
.code
org 100h 

begin:
    jmp start


is_empty_line macro text_line, marker  
    push si
    
    mov si, offset text_line
    call strlen
    
    pop si
    cmp ax, 0    
    je marker 
endm              

show_str macro out_str
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
 
read_cmd macro
    xor ch, ch
    mov cl, ds:[80h] ; number of symbols in cmd                 
    mov cmd_size, cl ;      
    mov si, 81h      ; adress of arguments 
    mov di, offset cmd_text 
    rep movsb   ;get symbols from cmd with adress to DI from SI
endm
   
bad_params_message      db "Bad cmd arguments", '$'
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
signal_duration         db 0    
buffer                  db max_size + 2 dup(0)

flag db ? 
time_sec db ?   
time_min db ?
time_hour db ?
prev_sec db ?         
count db ? 



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
endp

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

int_to_bcd macro num
    pusha
    
    mov al, num
    mov si, 10
    mov dx, 0
    div si     
    mov bx, ax  
    mul si  
    mov cl, num
    sub cx, ax   
    shl bx, 4  
    add bx, cx
    
    mov num, bl
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
    mov signal_duration, dl 
    is_empty_line number_text bad_cmd 
    ;int_to_bcd signal_duration
    pusha      
    mov al, alarm_hours
    cmp al, 24
    jae bad_cmd  
    int_to_bcd alarm_hours
    
    mov al, alarm_minutes
    cmp al, 60
    jae bad_cmd  
    int_to_bcd alarm_minutes
    
    mov al, alarm_seconds
    cmp al, 60
    jae bad_cmd 
    int_to_bcd alarm_seconds 

    mov al, signal_duration
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
    mov al,10110110b
    out 43h,al
    mov al,0Dh
    out 42h,al
    mov al,11h
    out 42h,al
    in al, 61h 
    or al, 00000011b
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
     

get_time proc                ;read current time from rtc
      pusha       
      
      mov ah, 02h
      int 1ah
      
      mov time_sec, dh
      mov time_min, cl
      mov time_hour, ch  

      popa
      ret
endp

beep proc
      pusha
      pushf
      push ds
      push es 
      
      cmp cs:flag, 1
      je check_timer 
      
      mov al, time_hour
      cmp al, cs:alarm_hours
      jne no_alarm      
      
      mov al, time_min
      cmp al, cs:alarm_minutes
      jne no_alarm
      
      mov al, time_sec
      cmp al, cs:alarm_seconds
      jne no_alarm
      
      
      mov cs:flag, 1
      call Speaker_On 
      mov cs:count, 0
      mov cs:prev_sec, al
      jmp no_alarm  
      
check_timer:
      mov al, time_sec 
      cmp cs:prev_sec, al          
      je no_alarm 
      mov cs:prev_sec, al 
      
      mov bl, cs:count 
      inc bl
      mov cs:count, bl    
      
      cmp bl, cs:signal_duration
      jne no_alarm    
      mov cs:flag, 0 
      mov cs:count, 0 
      call Speaker_Off
      
no_alarm:
      pop es
      pop ds
      popf
      popa
      ret
endp    

int_handler proc far 
    cli
    call get_time
    call beep
    sti 
    iret
endp

start:
    mov ax, cs
    mov es, ax
    read_cmd
    mov ds, ax 
    
    call read_from_cmd
    
    mov ax, 351Ch
    int 21h                
    
    mov word ptr old_handler, bx ;save old_handler
    mov word ptr old_handler + 2, es
    mov ax, 251Ch 
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
    
  