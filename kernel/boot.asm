; Multiboot header constants
MBOOT_HEADER_MAGIC  equ 0x1BADB002
MBOOT_PAGE_ALIGN    equ 1<<0
MBOOT_MEM_INFO      equ 1<<1
MBOOT_HEADER_FLAGS  equ MBOOT_PAGE_ALIGN | MBOOT_MEM_INFO
MBOOT_CHECKSUM      equ -(MBOOT_HEADER_MAGIC + MBOOT_HEADER_FLAGS)

section .multiboot
align 4
    dd MBOOT_HEADER_MAGIC
    dd MBOOT_HEADER_FLAGS
    dd MBOOT_CHECKSUM

section .bss
align 16
stack_bottom:
    resb 16384         ; 16 KiB stack
stack_top:

section .text
global _start
extern kernel_main
_start:
    mov esp, stack_top ; Set up the stack pointer
    
    ; Reset EFLAGS
    push 0
    popf
    
    ; Clear screen and reset attributes
    mov edi, 0xB8000
    mov ax, 0x0F20   ; Black background (0), white foreground (F), space character (20)
    mov ecx, 80*25   ; Full screen
    rep stosw        ; Fill screen with default attributes
    
    ; Reset cursor position
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    xor al, al
    out dx, al
    
    ; Call kernel
    call kernel_main

    ; Halt if kernel returns
    cli
.hang:
    hlt
    jmp .hang

global isr0, isr80
extern isr_handler

isr0:
    push 0              ; Push dummy error code
                        ; (div by zero doesn't push one automatically)
    push 0              ; Push interrupt number
    pusha
    push ds
    push es
    push fs
    push gs

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    push esp            ; Pass pointer to saved registers
    cld                 ; Required by 32-bit System V ABI
    call isr_handler
    add esp, 4

    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8          ; Remove the interrupt and error code from stack
    iret

isr80:
    push 0              ; Push dummy error code
                        ; (software interrupts don't push one automatically)
    push 0x80           ; Push interrupt number
    pusha
    push ds
    push es
    push fs
    push gs

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    push esp            ; Pass pointer to saved registers
    cld                 ; Required by 32-bit System V ABI
    call isr_handler
    add esp, 4

    pop gs
    pop fs
    pop es
    pop ds
    popa

    add esp, 8          ; Remove the interrupt and error code from stack
    iret

global gdt_flush

gdt_flush:
    mov eax, [esp+4]
    lgdt [eax]          ; Load GDT descriptor from stack
    mov ax, 0x10        ; Load data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:.flush     ; Far jump to reload code segment
.flush:
    ret

global idt_flush

idt_flush:
    mov eax, [esp+4]
    lidt [eax]          ; Load IDT descriptor from stack
    ret
