        bits 16
        cpu 686
        org 0x7C00

BUF     equ 0x1000
MX      equ 100
HELM    equ 14
FMAXH   equ 10
GSTEP   equ 16

%define V(x) bp+x
%define K(x) bp+x-state

OLD     equ 24
GAS     equ 48
FUEL    equ 50
COINS   equ 52
LASTK   equ 54
CAMX    equ 56
CAMY    equ 60
CO      equ 62
SN      equ 64
SCX     equ 66
SCY     equ 68
SZ      equ 70
TMP     equ 72
FY      equ 74
DEAD    equ 76
BCD     equ 78
GY      equ 88
NEXT    equ 58
GAP     equ 90

%macro R 5
        db %1, -(%2), %3, -(%4), %5
%endmacro
%macro C 4
        db %1, -(%2), 0, -(%3), %4
%endmacro

        xor ax, ax
        mov ds, ax
        mov es, ax
        mov ax, 0x0201
        mov cx, 2
        mov dh, 0
        mov bx, 0x7E00
        int 0x13
        mov al, 0x13
        int 0x10
        mov dx, 0x3C8
        mov al, 0xC0
        out dx, al
        inc dx
        xchg ax, cx
pal:    mov al, cl
        out dx, al
        shr al, 1
        out dx, al
        mov al, 63
        out dx, al
        inc cl
        jnz pal
        mov al, 0x26
        out 0x40, al
        out 0x40, al
        xchg ax, cx

start:  push ds
        pop es
        mov bp, state
        mov di, bp
        mov cl, 92
        rep stosb
        mov si, initp
        mov di, bp
        mov cl, 6
.i:     fild word [si]
        fst dword [di]
        fstp dword [di+OLD]
        lodsw
        scasd
        loop .i
        push BUF
        pop es

frame:  hlt
        in al, 0x60
        sub al, 0x4B
        cmp al, 2
        jbe .k
        mov al, 1
.k:     dec ax
        cbw
        inc word [V(FUEL)]
        cmp byte [V(FUEL+1)], FMAXH
        jb .g
        ja dead
        xor ax, ax
.g:     mov [V(GAS)], ax

        mov si, bp
        mov cl, 3
integ:  fldz
        call vc
        fild word [V(GAS)]
        fidiv word [K(f1)]
        fadd dword [K(grav)]
        call vc
        neg word [V(GAS)]
        loop integ

        mov bx, bp
        mov cl, 4
iter:   mov si, ctab
cons:   lodsw
        mov bl, al
        movzx di, ah
        fld dword [bp+di]
        fsub dword [bx]
        fld dword [bp+di+4]
        fsub dword [bx+4]
        fld st1
        fmul st0, st0
        fld st1
        fmul st0, st0
        faddp st1, st0
        fsqrt
        fidivr word [si]
        fld1
        fsubrp st1, st0
        fidiv word [si+2]
        fmul st2, st0
        fmulp st1, st0
        fld dword [bx+4]
        fadd st0, st1
        fstp dword [bx+4]
        fsubr dword [bp+di+4]
        fstp dword [bp+di+4]
        fld dword [bx]
        fadd st0, st1
        fstp dword [bx]
        fsubr dword [bp+di]
        fstp dword [bp+di]
        lodsd
        test byte [si], 2
        jz cons

wcol:   fld dword [bp+di]
        call ground
        fld1
        fadd dword [bp+di]
        call ground
        fsub st0, st1
        fxch
        fisub word [K(rad)]
        fsubr dword [bp+di+4]
        fldz
        fcomip st0, st1
        jae .air
        fld st1
        fmul st0, st0
        fld1
        faddp st1, st0
        fdiv st1, st0
        fidivr word [V(GAS)]
        fidiv word [K(kd)]
        fld st1
        fmul st0, st3
        fadd st0, st1
        fadd dword [bp+di]
        fstp dword [bp+di]
        fmul st0, st2
        fsubrp st1, st0
        fadd dword [bp+di+4]
        fstp dword [bp+di+4]
.air:   fninit
        sub di, 8
        jnc wcol
        dec cx
        jnz iter

cam:    fld dword [bp+di+24]
        fistp word [bp+di+CAMX+8]
        sub word [bp+di+CAMX+8], MX
        add di, 4
        jnz cam


        mov si, 319
col:    mov [V(TMP)], si
        fild word [V(TMP)]
        fld st0
        fiadd word [V(CAMX)]
        call ground
        fisub word [V(CAMY)]
        fistp word [V(GY)]
        fadd st0
        fiadd word [V(CAMX)]
        fidiv word [K(f1)]
        fsin
        fimul word [K(f2)]
        fiadd word [K(f1)]
        fistp word [V(FY)]
        mov di, si
        xor bx, bx
.row:   mov al, bl
        shr al, 2
        or al, 0xC0
        cmp bx, [V(FY)]
        jl .sky
        add al, 10
.sky:   mov cx, bx
        sub cx, [V(GY)]
        jl .put
        mov al, 10
        cmp cx, 2
        jb .put
        mov al, 2
        cmp cx, 6
        jb .put
        mov al, 6
        test cl, 16
        jz .put
        mov al, 0x72
.put:   stosb
        inc bx
        add di, 319
        cmp bl, 200
        jb .row
        dec si
        jns col

        mov ax, [V(CAMX)]
        sar ax, 5
        inc ax
        mov dx, ax
        inc dx
        inc dx
        mov cx, 9
items:  pusha
        cmp ax, [V(LASTK)]
        jl inext
        mov si, can
        cmp ax, [V(NEXT)]
        je ikeep
        mov si, coin
        test al, 8
        jnz inext
ikeep:  cmp ax, dx
        jg idraw
        inc ax
        mov [V(LASTK)], ax
        test byte [si], 8
        jnz ican
        inc word [V(COINS)]
        jmp inext

ground: fld st0
        fidiv word [K(f1)]
        fsin
        fld st1
        fidiv word [K(f2)]
        fsin
        faddp st1, st0
        fxch
        fidiv word [K(f3)]
        fmulp st1, st0
        ret


initp   dw 0, -9, 36, -9, 18, -21
damp    dd 0.996

        times 510 - ($ - $$) db 0
        dw 0xAA55

ican:   mov [V(FUEL+1)], ch
        add word [V(GAP)], GSTEP
        add ax, [V(GAP)]
        mov [V(NEXT)], ax
        jmp inext
idraw: fldz
        shl ax, 5
        mov [V(TMP)], ax
        fild word [V(TMP)]
        fld st0
        call ground
        fisub word [K(rad)]
        call draw
inext: popa
        inc ax
        loop items

        xor di, di
wdraw:  fld dword [bp+di]
        fidiv word [K(rad)]
        fld dword [bp+di]
        fld dword [bp+di+4]
        mov si, wheel
        call draw
        xor di, 8
        jnz wdraw

        fld dword [bp+12]
        fsub dword [bp+4]
        fld dword [bp+8]
        fsub dword [bp+0]
        fpatan
        fld dword [bp+16]
        fld dword [bp+20]
        mov si, car
        call draw

        push es
        pop ds
        push 0xA000
        pop es
        xor si, si
        mov ch, 0x7D
        rep movsw
        push ds
        pop es
        push cs
        pop ds

        mov cl, FMAXH
        sub cl, [V(FUEL+1)]
        jle .nb
        mov bl, 0x27
        add bl, cl
        mov ax, 0x09DE
        int 0x10
.nb:    mov bl, 15
        mov dx, 0x0011
        fld dword [bp+16]
        fidiv word [K(rad)]
        call pnum
        mov ax, 0x0E6D
        int 0x10
        mov dx, 1
        fild word [V(COINS)]
        call pnum
        cmp [V(DEAD)], ch
        je frame
dead:   in al, 0x60
        sub al, 0x39
        jnz dead
        jmp start

pnum:   mov ah, 2
        int 0x10
        fbstp tword [V(BCD)]
        mov dx, [V(BCD)]
        mov cl, 4
.d:     rol dx, 4
        mov ax, 0x0E0F
        and al, dl
        add al, '0'
        int 0x10
        loop .d
        ret

vc:     fld dword [si]
        fld st0
        fsub dword [si+OLD]
        fmul dword [K(damp)]
        faddp st2, st0
        fst dword [si+OLD]
        faddp st1, st0
        fstp dword [si]
        lodsd
        ret

draw:   fisub word [V(CAMY)]
        fistp word [V(SCY)]
        fisub word [V(CAMX)]
        fistp word [V(SCX)]
        fsincos
        fimul word [K(c256)]
        fistp word [V(CO)]
        fimul word [K(c256)]
        fistp word [V(SN)]
        lodsb
        cbw
        mov [V(SZ)], ax
        mov bx, ax
        neg bx
.y:     mov cx, [V(SZ)]
        neg cx
.x:     pusha
        mov ax, [V(SCY)]
        add ax, bx
        cmp ax, 200
        jae .s
        imul di, ax, 320
        add di, [V(SCX)]
        add di, cx
        mov ax, cx
        imul ax, [V(CO)]
        mov dx, bx
        imul dx, [V(SN)]
        add ax, dx
        push ax
        mov ax, bx
        imul ax, [V(CO)]
        mov dx, cx
        imul dx, [V(SN)]
        sub ax, dx
        pop dx
        mov dl, dh
        mov dh, ah
.e:     lodsb
        xchg ax, bx
        test bl, bl
        jz .s
        lodsw
        add al, dl
        xchg ax, cx
        lodsw
        add al, dh
        test ch, ch
        jnz .r
        mov bh, ah
        imul al
        xchg ax, cx
        imul al
        add ax, cx
        sub al, bh
        sbb ah, 0
        jns .e
        jmp .h
.r:     cmp cl, ch
        ja .e
        cmp al, ah
        ja .e
.h:     mov al, [es:di]
        or al, bl
        cmp al, 16
        adc byte [V(DEAD)], 0
        mov [es:di], bl
        jmp .e
.s:     popa
        inc cx
        cmp cx, [V(SZ)]
        jle .x
        inc bx
        cmp bx, [V(SZ)]
        jle .y
        ret

ctab:   db 0, 16
        dw 22, 6
        db 8, 16
        dw 22, 6
        db 0, 8
        dw 36, 2


wheel:  db 10
        C 0x12, 0, 0, 90
        C 0x1B, 0, 0, 40
        R 0x15, -1, 2, -6, 12
        R 0x15, -6, 12, -1, 2
        db 0

coin:   db 6
        C 42, 0, 0, 30
        C 44, 0, 0, 14
        db 0

can:    db 10
        R 40, -5, 10, -6, 13
        R 31, -3, 6, -2, 3
        db 0

car:    db 27
        R 0x70, -22, 44, 2, 3
        R 40, -24, 46, -8, 10
        R 0x2C, 20, 3, -7, 2
        R 0x14, -15, 3, -14, 10
        R 32, -11, 7, -13, 8
        R 66, -6, 9, -11, 2
        R 0x16, -17, 2, -22, 18
        C HELM, -7, -18, 14
        C 66, -5, -16, 6
        db 0

grav    dd 0.06
kd      dw -50
rad     dw 9
f1      dw 72
f2      dw 31
f3      dw 300
c256    dw 256

        times 1024 - ($ - $$) db 0
        align 32, db 0
state:
