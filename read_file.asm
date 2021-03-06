;;
;; Created on 2019-04-26 by Jacob Bethany
;; Purpose: To learn how to read from a file in asm on Linux systems.
;;
;; /* whence values for lseek(2) */
;; #define      SEEK_SET        0       /* set file offset to offset */
;; #define      SEEK_CUR        1       /* set file offset to current plus offset */
;; #define      SEEK_END        2       /* set file offset to EOF plus offset */
;;
;; https://unix.superglobalmegacorp.com/Net2/newsrc/sys/fcntl.h.html
;;
;; /* open-only flags */
;; #define      O_RDONLY        0x0000          /* open for reading only */
;; #define      O_WRONLY        0x0001          /* open for writing only */
;; #define      O_RDWR          0x0002          /* open for reading and writing */
;;
;; System interrupt (0x80) information for Linux:
;; http://syscalls.kernelgrok.com/
;;
use32
format elf executable
entry start

;;section '.text' code executable readable writeable
segment readable executable writeable ;; on linux we don't use code or give it a name, apparently....

 sz_msg db 'Hello, world!',10,13,0 ;our dear string
 sz_error db 'Some error occured:      ',10,13,0
 sz_file_name db 'hello_world.asm',0
 ul_file_handle dd 0
 ul_file_size dd 0
 ul_current_file_position dd 0

 uc_file_buffer rb 256 ;;256 byte buffer to use to read the file.
 ;;len equ $ - sz_msg ;;length of our dear string

;;as defined by "entry start"
start:

  ;;Error reporting test.
  ;;;;mov edx, 12345
  ;;;;call report_error

  ;;Alarm for 1 second.
  ;;mov eax, 0x1b
  ;;mov ebx, 1
  ;;int 0x80

  ;;Try to open the requested file.
  mov eax, 0x05         ;;using lopen().
  mov ebx, sz_file_name ;;ebx = the file to open.
  xor ecx, ecx ;;mov ecx, 0x00         ;;O_RDONLY
  int 0x80

  ;;Check to see if we've failed to open the file.
  mov edx, 1 ;;set the error code.
  cmp eax, 0
  je report_error

  ;;Store the file handle for later.
  mov [ul_file_handle], eax

  ;;Try to seek to the end of the file.
  mov ebx, eax  ;;ebx = file handle
  mov eax, 0x13 ;;eax = system interrupt for lseek
  xor ecx, ecx  ;;ecx = 0 (offset from  it)
  mov edx, 2    ;;edx = SEEK_END
  int 0x80

  ;;If lseek returned an error.
  mov edx, 2 ;;set the error code.
  cmp eax, 0
  jl report_error

  ;;eax holds the current size of the file.
  mov [ul_file_size], eax



  ;;Try to seek to the start of the file.
  mov ebx, [ul_file_handle]  ;;ebx = file handle
  mov eax, 0x13 ;;eax = system interrupt for lseek
  xor ecx, ecx  ;;ecx = 0 (offset from  it)
  mov edx, 0    ;;edx = SEEK_SET
  int 0x80

  ;;If lseek returned an error.
  mov edx, 3 ;;set the error code
  cmp eax, 0
  jl report_error


  ;;Read the file up to 255 bytes at a time.
prepare_to_read_from_file:
 ;;If edx (255) > the size of the file, use the size of the file.
  mov eax, [ul_file_size]
  mov edx, 255 ;;read up to 255 bytes.
  cmp edx, eax
  jle read_from_the_file

  ;;otherwise the size of the file is less than the size of the buffer, so only read in what we need to read.
  mov edx, eax

  ;;Actually read the file, now that we know how much we'd like to read.
read_from_the_file:
;;Clear the buffer into which we'll be reading.
  mov eax, uc_file_buffer ;;the buffer to zero
  mov ebx, 0              ;;the byte to which to set each element of the array.
  mov ecx, 256            ;;the size of the buffer
  call memory_set

  ;;edx (the number of bytes to read) was resolved above.
  mov eax, 0x03
  mov ebx, [ul_file_handle]
  mov ecx, uc_file_buffer
  int 0x80

  ;;Update the current file position.
  mov ecx, eax
  add ecx, [ul_current_file_position]
  mov [ul_current_file_position], ecx

  mov edx, 4 ;;set the error code.
  cmp eax, 0
  jl report_error

read_file_okay:

  ;;Show the portion of the file that was read.
  mov eax, uc_file_buffer
  call puts

  mov eax, [ul_current_file_position]
  mov ecx, [ul_file_size]
  cmp eax, ecx
  jl prepare_to_read_from_file



  jmp finish_execution
report_error:
    mov eax, sz_error

    mov ecx, eax
    mov ebx, ':'
    call string_find_character
    add eax, 2 ;;put 1 space between eax and the colon.


    mov ebx, edx
    call itoa ;(eax:string, ebx:number_to_convert_to_ascii) [buffer length is delimited by zero at the end.]
    mov eax, sz_error
    call puts ;eax = string to display.

;    add edx, 48
;    mov [eax], dl

;    mov eax, ecx ;;start at the begining of the string, again.
;    call puts

 ;;Free resources.

 ;;Close the file handle, if it was opened.
    mov eax, [ul_file_handle]
    cmp eax, 0
    jmp finish_execution

  ;;close the file.
  mov eax, 0x06
  mov ebx, ul_file_handle
  int 0x80

finish_execution:

    ;;Display a message.
    mov eax, sz_msg
    call puts


;;Exit via the kernel:
    mov ebx, 0  ;process' exit code
    mov eax, 1  ;system call number (sys_exit)
    int 0x80    ;call kernel - this interrupt won't return

 ;;eax = string to print.
 puts:
    call get_string_length  ;;edx = length of the string.

    mov ecx, eax     ;message to write
    mov ebx, 1       ;file descriptor (stdout)
    mov eax, 4       ;system call number (sys_write)
    int 0x80         ;call kernel
 ret

 ;;This takes a string pointer in eax and returns the length of the string in edx.
 get_string_length:
   mov edx, eax

   strlen_loop:
     cmp byte [edx], 0
     je strlen_done
     add edx, 1
     jmp strlen_loop
   strlen_done:
     sub edx, eax ;;get the offset from the start of the string.

   ret


 ;;eax = buffer to clear with a byte for each element.
 ;;ebx = the byte to use for each element of the buffer.
 ;;ecx = the size (in bytes) of the buffer.
 memory_set:
   memory_set_keep_going:
     mov [eax], bl
     add eax, 1
     sub ecx, 1
     jnz memory_set_keep_going

 ret

 ;;eax = string
 ;;ebx = token for which to look
 ;;returns in eax the position of the token, or the zero at the end of the string.
 string_find_character:

   string_find_character_continue:

   cmp [eax], byte bl
   je string_find_character_finished

   add eax, 1
   jmp string_find_character_continue

   string_find_character_finished:
 ret

 ;;in: eax = string
 ;;in: ebx = number to turn into string.
 ;;out: eax = string
 itoa:
   call get_string_length ;(eax:string, out-edx:length of the string)

   push ebx
   push esi ;;will store the start of the buffer for later.
   push edi ;;will store the end of the ascii representation for later.
   ;;push ebp ;;unused

   ;;Point to the end of the string.
   mov ecx, eax
   add ecx, edx
   sub ecx, 1

   mov edi, ecx ;;store the end of the ascii representation for later.

   ;;Insert a \n at the end of the string before we start generating the number.
   mov [ecx], byte 0x0a ;;\n(10) (\r = 0x0d (13))
   sub ecx, 1
   ;;mov edi, ecx ;;no reason to force this to the stack.

   mov esi, eax ;;esi = start of the string.
   mov eax, ebx ;;eax = the number to represent in ascii.
   ;;xchg eax, ebx ;;eax = number to continually divide by the base; ebx = pointer to the begining of the string.

;;eax = the number to represent in ascii.
;;ecx = descending pointer, from the end of the string towards the begining that is used to insert the ascii codes of the remainders as we continually divide the number in eax by the base (10).
;;edx = the hiword during division and the remainder afterwards.
;;ebx = 10 (the base of the number system into which we're converting the number).
;;esi = pointer to the start of the string.

   mov ebx, 10 ;;we'll continually divide by this number.

   itoa_continue:
     cmp eax, 10
     jl itoa_done

     xor edx, edx ;;diving divides edx:eax by whatever opcode you request. So, the hiword (EDX) needs to be zero before the division occurs.
     div ebx      ;;divide edx:eax by 10.

     add edx, 48
     mov [ecx], dl ;;take the remainder as the value at this position.

     sub ecx, 1
     jmp itoa_continue

     itoa_done:
       add eax, 48
       mov [ecx], al

     ;;we now have the number calculated at the end of the string.
     ;;Copy the number that we've generated to the start of the string, from the end.
     mov eax, esi ;;eax = start of the buffer
     mov ebx, ecx ;;ebx = start of the ascii representation, at the end of the buffer. (buff length - ascii representation length)

     mov ecx, edi ;;start at the end of the ascii representation. (otherwise we'd take the offset of the start of the ascii representation rather than the end of it)
     sub ecx, eax ;;ecx = the length to copy.
     call memory_copy ;;copy from the ascii representation at the end of the buffer, to the start of the buffer.

   ;;Restore the registers that we preserved.
   ;;pop ebp
   pop edi
   pop esi
   pop ebx

 ret

 ;;eax = destination
 ;;ebx = source
 ;;ecx = length
 memory_copy:
   mov esi, eax

   memory_copy_continue:
     mov dl, byte [ebx]
     mov [eax], byte dl
     add eax, 1
     add ebx, 1

     sub ecx, 1
     jnz memory_copy_continue

   mov eax, esi ;;restore eax to the begining of the string.

 ret
