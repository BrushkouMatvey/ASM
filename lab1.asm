.model tiny
.code   
org 100h
start:
    mov dx, offset message
    mov ah, 9
    int 21h   
    ret
message db "Hello World!", 13, 10, '$'
end start