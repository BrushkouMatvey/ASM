.model small
.stack 100h
.data

bad_params_message db "Bad cmd arguments", '$'
bad_source_file_message db "Cannot open file", '$'
file_not_found_message db "File not found", '$'
error_closing_file_message db "Cannot close file", '$'
error_read_file_text_message db "Error reading from file", '$'
file_is_empty_message db "File is empty", '$' 
result_message db "Number of lines with a length less than specified : ", '$'

b_num_10                    db 10


space_char equ 32  
new_line_char equ 13
return_char equ 10
tabulation equ 9
endl_char equ 0   
symbol  db ?
flag_not_empty dw 0

max_size equ 126 
cmd_size db ?
cmd_text db max_size + 2 dup(0)
path db max_size + 2 dup(0)
number_text db max_size + 2dup(0) 
           
num_10 db 10
   
temp_length dw 0     
source_id dw 0
max_length dw 0 	
lines_counter dw 0
buffer db max_size + 2 dup(0) 

.code
 
 
macro exit_app
   mov ax, 4C00h
   int 21h  
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
     
     
 
macro is_empty_line text_line, marker  
	push si
	
	mov si, offset text_line
	call strlen
	
	pop si
	cmp ax, 0    
	je marker 
endm


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
   
     
macro read_cmd
    xor ch, ch
	mov cl, ds:[80h] ; number of symbols in cmd          		
	mov cmd_size, cl ; 		
	mov si, 81h      ; adress of arguments 
	mov di, offset cmd_text 
	rep movsb   ;get symbols from cmd with adress to DI from SI
endm


        
print_result proc
    push dx
    push bx
    mov bx, ax 
    mov bp, sp			
							
loop1:            
    cmp ax, 0
    je skip_actions
    div b_num_10    
    xor bx, bx
    mov bl, ah
    xor ah, ah
skip_actions:
    push bx 
    cmp al, 0
    je print_num 
    jmp loop1
        
print_num:          
	loop3:
    	xor dx, dx  
    	pop bx
    	add bx, '0'
    	mov ah, 02h
    	mov dl, bl
    	int 21h
    	cmp bp, sp
    	jne loop3
    pop bx
    pop dx    
    ret
endp
 

          
conv proc
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
                                  
    mov max_length, ax
    
    pop si
    pop di
    popa                 
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
	mov di, offset path
	call rewrite_word
	is_empty_line path, bad_cmd        
	                                          
	mov di, offset number_text               
	call rewrite_word
	call conv ;max_length
	
	pusha      
	mov ax, max_length
	cmp ax, 32768
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
	inc si 					;new word in cmd_text  
	
	pop di
	pop cx
	pop ax
	ret
endp


                                                 
open_file proc
	push bx
	push dx 
	
	mov ah, 3Dh	; 3d - open existing file;	
	mov al,00h	; 00 - for only reading
	mov dx, offset path        ;filename
	int 21h                       
	jb bad_open	                               ; If cf = 1 then cannot open file
	
	mov source_id, ax	                        ; ax - file descriptor
	mov ax, 0			 
	jmp end_open		 
	
bad_open:
	show_str bad_source_file_message
	cmp ax, 02h                                 ; 2h - cannot find file
	jne error_found
	show_str file_not_found_message
	jmp error_found    
	
error_found:
	mov ax, 1         
	
end_open:
	pop dx
	pop bx    
	
	cmp ax, 0
	jne end_main
	ret
endp    

file_handling proc
    pusha
    mov di, max_length
    mov si, 0
    mov lines_counter, 0  

count_loop:
    
    mov bx, source_id  
    mov cx, 1
    lea dx, symbol
    mov ah, 3Fh
    int 21h   
    
    
    cmp ax, 0  
    je exit_handling
    
    mov flag_not_empty, 1
    
    xor ax, ax
    mov al, symbol
    cmp al, 0Dh
    jne dont_inc_args
set_lines_counter:   
  
    cmp si,di     

    jge too_much_length 
    
    inc lines_counter
    
    too_much_length:
    xor si, si
    dec si
    
dont_inc_args:
    cmp al, 0Ah
    je count_loop
    inc si
    jmp count_loop    

exit_handling:
    
    cmp flag_not_empty, 0
    je empty_file
    
    cmp si,di     
    jg too_much_length2
    
    inc lines_counter 
       
    too_much_length2:
        
    popa
    ret
empty_file:
    show_str file_is_empty_message
    popa
    ret              
	
endp 
                
                
                
close_file proc
	push bx
	push cx  
	
	xor cx, cx
	mov ah, 3Eh   ; 3e - close file    
	mov bx, source_id   
	int 21h
	jnb good_close	; if c=0 - OK	   
	
	show_str error_closing_file_message
	inc cx 	
			
good_close:
	mov ax, cx 		
	pop cx
	pop bx 
	
	cmp ax, 0
	jne end_main
	ret
endm
    
 
 
 
start:
	mov ax, @data
	mov es, ax
	read_cmd            
	mov ds, ax
	
	call read_from_cmd				
    call open_file 
	call file_handling
	call close_file			
		
				     
    mov ah, 9h                      
	mov dx, offset result_message
	int 21h                     
	
	mov ax, lines_counter     
    call print_result 
    
    mov dl, 10    
	mov ah, 2h
	int 21h    
	          
	mov dl, 13     
	mov ah, 2h
	int 21h  
	 
	
end_main:
	exit_app 

end start