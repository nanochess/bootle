	;
	; Bootle: A Wordle clone in a boot sector.
	; 
	; by Oscar Toledo G.
	; https://nanochess.org/
	; 
        ; Creation date: Feb/27/2022. 12pm to 2pm.
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
LIST_LENGTH:    equ 57          ; Length of word list.

        ;
        ; Start of the game.
        ;
start:
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
        cmp di,BOARD_BASE       ; First time?
        jnz .5                  ; No, jump.
        in al,0x40              ; Get a pseudo-random number.
	mov ah,0
        mov dl,LIST_LENGTH
        div dl                  ; Divide between list length.
        mov al,5                ; Use remainder and multiply by 5.
	mul ah
        add ax,word_list
        xchg ax,si              ; This is the current word.
.5:
        ;
        ; At this point it should validate the word against the valid
        ; word list, but given the word list is pretty short, then this
        ; step is not done.
        ;

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
.14:        
        call read_keyboard      ; Wait for a key.
        jmp .10                 ; Start new bootle.

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

        ;
        ; Word list for the game
        ;
word_list:
        db "ADULT"
        db "ARGUE"
        db "AWARD"
	db "BROOM"
        db "BLOCK"
        db "BUYER"
	db "COULD"
        db "CHEST"
        db "CLOCK"
        db "DOUBT"
        db "DEPTH"
        db "DRINK"
        db "EARTH"
        db "ENTRY"
        db "EVENT"
        db "FIGHT"
        db "FORCE"
        db "FLOOR"
        db "GROUP"
        db "GRANT"
        db "GUIDE"
        db "HORSE"
        db "HEART"
        db "HOUSE"
        db "IMAGE"
        db "INDEX"
        db "ISSUE"
        db "JUDGE"
        db "KNIFE"
        db "LEVEL"
        db "LIGHT"
        db "LUNCH"
	db "MOUSE"
        db "MODEL"
        db "MAJOR"
        db "NORTH"
        db "NOISE"
        db "NURSE"
        db "OTHER"
        db "OWNER"
	db "PAUSE"
        db "PEACE"
        db "PITCH"
        db "QUEEN"
        db "RADIO"
        db "REPLY"
        db "RUGBY"
        db "SCENE"
        db "SHIFT"
        db "STUDY"
        db "THEME"
        db "THING"
        db "TOUCH"
        db "UNCLE"
        db "VIVID"
        db "WATCH"
        db "YOUTH"

    %if com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif

