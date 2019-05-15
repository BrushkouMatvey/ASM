.model small 
.stack 100h 
.data 
string db 200 dup('$') 
instr db "Enter string:",0Dh,0Ah,'$'

outstr db 0dh,0ah, "Final string:", 0Dh,0Ah,'$'
msg_empty db 0Ah, 0Dh,'String is empty','$'
size db 0            

.code 
START:  
        mov ax,@data 
        mov ds, ax
                   
        mov ah, 09h
        lea dx, instr
        int 21h
               
        lea bx, string  
        mov [bx], 200 
        mov dx, bx 

        mov ah,0Ah 
        
        int 21h 

        add bl, string[1] 
        add bx, 2 
        mov [bx],'$'
        
        mov al, string[1]
        mov size, al
          
        cmp size, 0
        je EMPTY
    
        cmp size, 1
        je OUTPUT
          

REVERSE_STRING:
        lea bx, string + 2    
        mov di, bx
        add bl, size 
        mov si, bx
        dec si
        jmp LOOP_REVERSE
LOOP_REVERSE:        
        cmp di, si 
         
        mov al, [si]
        xchg al, [di]
        xchg al, [si]

        inc di       
        dec si
        cmp si,di
        jae LOOP_REVERSE

REVERSE_WORDS:      
        xor dx,dx 
        xor ax,ax 

        lea bx, string 
        add bx, 2 

        mov si, bx 
        mov di, bx 
         

NEXT_BYTE: 
        inc si  
        mov al,[si] 
        cmp al,' ' 
        je FOUND_THE_END 
        cmp al,'$' 
        je FOUND_THE_END 
        jmp NEXT_BYTE 

FOUND_THE_END: 
        mov dx,si  
        dec si 
        mov bx, di 

DO_REVERSE: 
        cmp bx, si 
        jae DONE 

        mov al, [bx] 
        mov ah, [si] 

        mov [si], al 
        mov [bx], ah 

        inc bx 
        dec si 
        jmp DO_REVERSE 

DONE:   
        
        mov si,dx  
        inc dx 
        mov bx,dx 
        mov di,bx 
        mov al,[si] 

        mov ah,[si] 
        cmp ah,'$' 
        jne NEXT_BYTE
        jmp OUTPUT 

        
EMPTY:
    mov ah, 09h
    mov dl, offset msg_empty                           
    int 21h
    
    jmp END
OUTPUT:   
    mov ah, 09h
    lea dx, outstr
    int 21h   
  
    mov dx, offset string 
    add dx, 2 
    int 21h    
      
END:
    mov ah, 4ch 
    int 21h 
END START