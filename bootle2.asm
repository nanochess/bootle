	;
        ; Bootle v2: A Wordle clone in a boot sector.
	; 
	; by Oscar Toledo G.
	; https://nanochess.org/
	; 
        ; Creation date: Feb/27/2022. 12pm to 2pm.
        ; Revision date: Feb/27/2022. 4pm to 6pm. Integrated 2500 word list.
        ;                             Added word list verification. Shows
        ;                             word at end.
        ;                             Added loader (360 kb image).
	;

	cpu 8086

    %ifndef com_file            ; If not defined create a boot sector.
com_file:       equ 0
    %endif

    %if com_file
        org 0x0100              ; Start address for COM file.
    %else
        org 0x7c00              ; Start address for boot sector.
    %endif

BOARD_BASE:     equ 8*160+70    ; Top corner of board.
HEART:          equ 0x0403      ; Red heart for non-filled letters.

        ;
        ; Start of the game.
        ;
start:
    %if com_file
    %else
.23:
        push cs
        pop es
        mov ax,0x0208           ; Read 8 sectors
        mov cx,0x0002           ; Track 0, sector 2 (1st is boot)
        mov bx,0x7e00
        mov dx,0x0000           ; Side 0
        int 0x13
        jb .23
.24:
        push cs
        pop es
        mov ax,0x0209           ; Read 9 sectors
        mov cx,0x0001           ; Track 0, sector 1
        mov bx,0x7e00+8*512
        mov dx,0x0100           ; Side 1
        int 0x13
        jb .24
.25:
        push cs
        pop es
        mov ax,0x0208           ; Read 8 sectors = 25 total sectors.
        mov cx,0x0101           ; Track 1, sector 1
        mov bx,0x7e00+17*512
        mov dx,0x0000           ; Side 0
        int 0x13
        jb .25
    %endif
        mov ax,0x0002           ; Color text 80x25.
	int 0x10
	cld
        push cs                 ; Copy the code segment address...
        pop ds                  ; ...to the data segment address.
        mov ax,0xb800           ; Point to video segment...
        mov es,ax               ; ...with the extended segment address.
        ;
        ; Setup board.
        ;
.10:
        es mov byte [0x0fa0],0  ; First time
        mov di,BOARD_BASE       ; Top left corner of board.
        push di
.0:           
        mov cx,5                ; 5 letters.
.1:
        mov ax,HEART            ; Red hearts.
        stosw                   ; Draw on screen.
        inc di                  ; Separator (one character)
	inc di
	loop .1
	add di,160-5*4
        cmp di,BOARD_BASE+160*6 ; Has it completed 6 rows?
        jb .0                   ; No, jump
        pop di                  ; Start again at top row.

        ;
        ; Try another word.
        ;
.9:
        xor cx,cx               ; Letters typed so far.
        push di                 ; Save pointer to start of word on the screen.
.3:
        call read_keyboard      ; Read a key.
        cmp al,0x0d             ; Enter pressed?
        jz .4                   ; Yes, jump.
        cmp al,0x08             ; Backspace pressed?
        jnz .2                  ; Yes, jump.
        or cx,cx                ; Letters to erase?
        jz .3                   ; No, jump.
        sub di,4
        mov ax,HEART            ; Draw a red heart.
        stosw
        dec di                  ; Get pointer back.
        dec di
        dec cx                  ; One letter less.
        jmp short .3            ; Wait for more input.
.2:
        cmp cl,5                ; Already 5 letters typed?
        jz .3                   ; Yes, jump.
        mov ah,0x07             ; Draw in white (AH=Attribute, AL=Key)
	stosw
        inc di                        
	inc di
        inc cx                  ; One letter more.

        es cmp byte [0x0fa0],0  ; First time?
        jnz short .3            ; No, jump.

        shl si,1                ; Create a random number.
        in al,0x40
        mov ah,0
        add si,ax

        jmp short .3            ; Wait for more input.

.4:     cmp cl,5                ; Enter accepted only if all letters filled.        
        jnz .3                  ; No, jump.
        pop di                  ; Back to start of row.

        ;
        ; The first time it chooses a word.
        ;
        ; This allows the pseudo-random counter to advance while
        ; the user enters letters.
        ;
        es cmp byte [0x0fa0],0  ; First time?
        jnz .5                  ; No, jump.
        es inc byte [0x0fa0]
        xchg ax,si
        xor dx,dx
        mov cx,LIST_LENGTH
        div cx                  ; Divide between list length.
        mov ax,5                ; Use remainder and multiply by 5.
        mul dx
        add ax,word_list
        xchg ax,si              ; This is the current word.
.5:
        ;
        ; Validates the word against the dictionary
        ;
        push si
        mov cx,LIST_LENGTH
        mov si,word_list
.19:    push si
        push di
        push cx
        mov cx,5                ; Each word is 5 letters.
.20:    es mov al,[di]          ; Compare one letter.
        add di,4
        inc si
        cmp al,[si-1]           
        jnz .18
        loop .20
.18:    pop cx
        pop di
        pop si
        jz .21                  ; Jump if matching word.
        add si,5                ; Go to next word.
        loop .19                ; Continue search.
        pop si
        ;
        ; Word not found in dictionary.
        ;
        push di                 ; Save pointer to start of row.
        mov cx,5                ; Restore letter count.
        add di,5*4              ; Restore cursor position
        jmp .3

.21:    pop si
        ;
        ; Now find exact matching letters.
        ;
        mov cx,0x10             ; Five letters to compare (bitmask)
        push si                 ; Save in stack the word address.
        push di
.6:
        es mov al,[di]          ; Read a typed letter.
        cmp al,[si]             ; Comparison against word.
        jnz .11                 ; Jump if not matching.
        mov ah,2                ; Green - Exact match
        or ch,cl                ; Set bitmask (avoid showing it as misplaced)
        db 0xbb                 ; MOV BX, to jump over two bytes
.11:
        mov ah,5                ; Magenta - Not found.

.8:     stosw                   ; Update color on screen.
        inc di                  ; Advance to next typed letter.
        inc di
        inc si                  ; Advance letter pointer on dictionary.
        shr cl,1
        jnz .6                  ; Repeat until completed.
        pop di
        pop si

        cmp ch,0x1f             ; All letters match
        jz .14                  ; Exit the game.

        ;
        ; Now find misplaced letters.
        ;
        mov cl,0x10
        mov dh,ch

.17:    es mov ax,[di]          ; Read a typed letter
        test ch,cl              ; Already checked?
        jne .12                 ; Yes, jump.
        mov dl,0x10             ; Test against the five letters of word.
        mov bx,si               ; Point to start of word.
.16:    test dh,dl              ; Already checked?
        jne .15                 ; Yes, jump.
        cmp al,[bx]             ; Compare against word.
        jne .15                 ; Jump if not equal.
        mov ah,6                ; Brown, misplaced
        or dh,dl                ; Mark as already checked.
        jmp .12                 ; Exit loop.

.15:    inc bx                  ; Go to next letter of word.
        shr dl,1
        jnz .16                 ; Repeat until completed.
.12:
        stosw                   ; Update color on screen.
        inc di                  ; Advance to next typed letter.
        inc di
        shr cl,1
        jnz .17                 ; Repeat until completed.

        add di,160-5*4          ; Go to next row.
        cmp di,BOARD_BASE+160*6 ; Six chances finished?
        jb .9                   ; No, jump.
        ;
        ; Show the word
        ;
        mov di,BOARD_BASE+7*160
        mov cx,5
.22:    lodsb
        mov ah,0x03
        stosw
        loop .22
.14:        
        call read_keyboard      ; Wait for a key.
        jmp start               ; Start new bootle.

        ;
        ; Read the keyboard.
        ;
read_keyboard:
        push cx
        push si
        push di
        mov ah,0x00             ; Read keyboard.
        int 0x16                ; Call BIOS.
                                ; Convert lowercase to uppercase
        cmp al,0x61             ; ASCII 'a'
        jb .1
        cmp al,0x7b             ; ASCII 'z' + 1
        jnb .1
        sub al,0x20             ; Distance between letters.
.1:
        pop di
        pop si
        pop cx
	ret

        db "Bootle v2, by Oscar Toledo G. Feb/27/2022",0

        db "360KB image runnable on qemu, VirtualBox, or original IBM PC",0

    %if com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif

        ;
        ; Word list for the game
        ;
        %include "wordlist.asm"

    %if com_file                ; Fill to a 360K disk
    %else
        times 360*1024-($-$$) db 0xe5
    %endif

