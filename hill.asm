        bits 16
        cpu 686
        org 0x7C00

BUF     equ 0x1000
SKY     equ 77
GRASS   equ 47
DIRT    equ 114
DARK    equ 186
CAN     equ 40
CARX    equ 90
CARY    equ 130

%define V(x) bp+x-state

start:
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov bp, state
        mov di, bp
clear:  mov cx, 64
        rep stosw
        mov al, 0x13
        int 0x10
        mov al, 0x26
        out 0x40, al
        out 0x40, al
        push BUF
        pop es

frame:
        hlt
        in al, 0x60
        sub al, 0x4B
        cmp al, 2
        jbe .key
        mov al, 1
.key:   dec ax
        cbw
        mov [V(gas)], ax

        mov si, bp
        mov cl, 2
wheel:  fild word [V(gas)]
        fidiv word [kd]
        call vc
        fild word [V(gas)]
        fidiv word [V(kt)]
        fadd dword [grav]
        call vc
        neg word [V(kt)]
        fld dword [si-8]
        call ground
        fld1
        fadd dword [si-8]
        call ground
        fsub st0, st1
        fxch
        fld dword [si-4]
        fsub st0, st1
        fldz
        fcomip st0, st1
        jae .air
        fxch
        fstp dword [si-4]
        fmulp st1, st0
        fadd dword [si-8]
        fstp dword [si-8]
.air:   fninit
        loop wheel

        fld dword [bp+12]
        fsub dword [bp+4]
        fld dword [bp+8]
        fsub dword [bp+0]
        fpatan
        fld st0
        fsincos
        mov cl, 2
.k:     fld st0
        fimul word [len]
        fadd dword [si-16]
        fstp dword [si-8]
        fstp st0
        lodsd
        loop .k

        mov si, -CARX
col:    mov [V(tmp)], si
        fild word [V(tmp)]
        fadd dword [bp+0]
        fist word [V(tmp2)]
        call ground
        fsub dword [bp+4]
        fistp word [V(tmp)]
        lea di, [si+CARX]
        mov bx, -CARY-5
        sub bx, [V(tmp)]
        xor dx, dx
        test word [V(tmp2)], 0x3F8
        jnz .row
        test si, si
        jnz .nf
        mov [V(fuel)], si
.nf:    js .row
        mov dx, -10
.row:   mov al, SKY
        cmp bx, dx
        jl .put
        mov al, CAN
        test bx, bx
        js .put
        mov al, GRASS
        cmp bx, 3
        jb .put
        mov al, DIRT
        test bl, 8
        jz .put
        mov al, DARK
.put:   stosb
        inc bx
        add di, 319
        jnc .row
        inc si
edge:   cmp si, 320-CARX
        jl col

        mov si, parts
part:   fild word [si]
        fidiv word [kd]
        fadd st0, st1
        fsincos
        fimul word [si+2]
        fistp word [V(tmp)]
        fimul word [si+2]
        fistp word [V(tmp2)]
        imul di, [V(tmp2)], 320
        add di, [V(tmp)]
        add di, (CARY-5)*320+CARX
        lodsd
        lodsb
        call blob
        cmp si, bp
        jb part
hit:    cmp byte [es:di], 100
        adc byte [V(dead)], -1

bar:    mov di, 40
        mov cl, [V(fuel)+1]
        not cl
        rep stosb

        push es
        pop ds
        push 0xA000
        pop es
        xor si, si
        xor di, di
        mov ch, 0x7D
        rep movsw
        push ds
        pop es
        push cs
        pop ds

        mov bl, 15
        mov ax, 0x0E0D
        int 0x10
        fld dword [bp+0]
        fbstp tword [V(tmp)]
        mov dx, [V(tmp)+1]
        mov cl, 4
.n:     rol dx, 4
        mov al, dl
        and al, 15
        add al, '0'
        int 0x10
        loop .n

        add dword [V(fuel)], 16
over:   cmp byte [V(dead)], 0
        je frame
.wait:  in al, 0x60
        cmp al, 0x39
        jne .wait
        jmp start

vc:     fld dword [si]
        fld st0
        fsub dword [si+16]
        fmul dword [damp]
        faddp st2, st0
        fst dword [si+16]
        faddp st1, st0
        fstp dword [si]
        lodsd
        ret

ground: fld st0
        fidiv word [f1]
        fsin
        fld st1
        fidiv word [f2]
        fsin
        faddp st1, st0
        fxch
        fidiv word [f3]
        fmulp st1, st0
        ret

blob:   mov bx, circ
.r:     mov cl, [bx]
        jcxz .x
        push di
        sub di, cx
        add cx, cx
        inc cx
        rep stosb
        pop di
..@s:   add di, 320
        inc bx
        jmp .r
.x:     ret

circ:   db 2, 3, 4, 5, 5, 5, 5, 5, 4, 3, 2

parts:
        dw 0, 0
        db 8
wheel1: dw 0, 26
        db 8
        dw -101, 10
        db 40
        dw -42, 16
        db 40
        dw -23, 28
        db 40
head:   dw -73, 22
        db 66

state:

grav    equ hit-1
damp    equ over-1
kd      equ bar+1
kt      equ clear+1
f1      equ bar+1
len     equ wheel1+2
f2      equ head+2
f3      equ ..@s+2
fuel    equ state+0x3D
dead    equ state+0x3F
gas     equ state+0x42
tmp2    equ state+0x44
tmp     equ state+0x46

        times 510 - ($ - $$) db 0
        dw 0xAA55
