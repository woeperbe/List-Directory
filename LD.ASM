;   ************************************************
;   *                                               *
;   *  LIST DIRECTORY WITH OPTIONAL INFO            *  
;   *                                               *
;   *   LS [???????.*] [/S] [/C] [/Z]               *
;   *       /S - Sort listing                       *
;   *       /C - Display CRC16                      *
;   *       /R - Display File Size                  *
;   *                                               *
;   *  PUBLIC DOMAIN SOFTWARE MADE BY WOEPER 2026   *
;   *                                               *
;   *************************************************
;
BDOS        EQU     0005H
SCANFIRST   EQU     17          ; Search first
SCANNEXT    EQU     18          ; Search next
CONOUT	    EQU		2			; Character out
PSTRING	    EQU		9			; print string
OPENF	    EQU		15			; Open file
CLOSEF	    EQU		16			; Close file	
READS	    EQU		20			; Read sequential
WRITES	    EQU		21			; Write sequential
SETDMA      EQU     26          ; Set DMA address
;
FCB		    EQU		05CH		; default FCB block
FCB2        EQU     06CH        ; Second parameter block
BUFFER	    EQU		080H		; Default Buffer	
CMDLINE	    EQU		080H		; Command line buffer	
TPA		    EQU		100H		; Start of TPA
;
CR		    EQU		13			; Cariage return
LF		    EQU		10			; line feed
EOF		    EQU		26			; End of file
;
            LIST	NOEXPAND
;               
            SEG		CSEG
;		
            ORG		TPA         ; Start of program at TPA
;
            LXI     SP,STACK    ; Local Stack pointer   
            XRA     A           ; Prepare 0
            STA     FILECNT     ; clear file counter
            STA     SORTFLAG    ; no sorting    
            STA     CRCFLAG     ; no CRC calculation
            STA     ASCIIFLAG   ; no CRC  ascii mode
            STA     SIZEFLAG    ; no Size mode flag
            
;
; ---------------------------------------------------------       
; PARSE COMMAND LINE FOR WILDCARD AND/OR FLAGS
; ---------------------------------------------------------
;           
            LXI		H,BUFFER	; Point to command line		
            MOV		A,M			; get string length in ACU
            ORA		A			; test
            JNZ     GO00        ; nothing entered
            CALL	INITFCB     ; if zero init FCB with wildcard *.*
            JMP     GOSCAN      ; Start the scan
GO00:       LDA     FCB+1       ; if Default FCB contains /
            CPI     '/'         ;  this means only option flags 
            CZ      INITFCB     ; have been entered so init wildcard
GO01:       LXI     H,BUFFER    ; get counter again
            MOV     B,M         ; counter to B
GO02:	    INX		H			; bump index
            DCR		B			; decrement count
            JZ		GOSCAN 		; counter zero -> Done	
            MOV		A,M			; het byte
            CPI		'/'			; is it /
            JNZ		GO02		; no next hit
            INX		H			; Yes /
            MOV		A,M			; get next one
            CPI		'S'			; is it A ?
            JNZ		GO03		; No continue
            MVI		A,1			; Set flag
            STA		SORTFLAG    ; Sort active
GO03:       MOV		A,M			; get next one
            CPI     'C'         ; is CRC requested
            JNZ     GO04        ; no continue test  
            MVI     A,1         ; set acu to 1
            STA     CRCFLAG     ; to set the CRC request flag
GO04:       MOV     A,M         ; Get character again
            CPI     'A'         ; ASCII CRC mode requested ?    
            JNZ     GO05        ; No continue the scan
            MVI     A,1         ; prepare true
            STA     ASCIIFLAG   ; to set the ASCII  mode flag
GO05:       MOV     A,M         ; Get character again
            CPI     'R'         ; Size mode requested ?    
            JNZ     GO06        ; No continue the scan
            MVI     A,1         ; prepare true
            STA     SIZEFLAG    ; to set the Size request flag
GO06:       MOV     A,M         ; Get back again
            CPI     '?'         ; Help demanded ?
            JZ      DISPHELP    ; yes do that
            JMP     GO02        ; continue to scan command line
;
; ---------------------------------------------------------       
; START READING THE DIRECTORY SEARCH FIRST
; ---------------------------------------------------------
;            
GOSCAN:     LXI     D,FCB         ; Find first file
            MVI     C,SCANFIRST   ; Through  
            CALL    BDOS          ; BDOS
            CPI     255           ; end ?  
            JZ      DONE          ; Jump if empty
;
; ---------------------------------------------------------       
; PROCESS THE ENTRY
; ---------------------------------------------------------
;            
LOOP:       ANI     3               ; Index 0-3
            ADD     A               ; Shift left 5 times
            ADD     A               ; to multiply by 32
            ADD     A               ; 2^5 = 32 bytes
            ADD     A
            ADD     A
            LXI     H,BUFFER        ; HL = Entry in BUFFER
            MOV     E,A             ; Offset to DE    
            MVI     D,0
            DAD     D               ; Add to get the correct location    
            INX     H               ; Skip drive byte
            PUSH    H               ; Save pointer to the found entry
            LXI     H,FILES         ; point to the start of table
            LXI     D,11            ; length of move
            LDA     FILECNT         ; Get current position in buffer
LOOP0:      ORA     A               ; test if 0
            JZ      LOOP5           ; ok first entry
            DCR     A               ; decrement count
            DAD     D               ; add  offset
            JMP     LOOP0           ; not done yet 
LOOP5:      XCHG                    ; buffer pointer to DE
            POP     H               ; Get found pointer
            MVI     B,11            ; Entry length        
LOOP1:      MOV     A,M             ; move
            STAX    D               ; the found entry
            INX     H               ; to
            INX     D               ; the buffer
            DCR     B               ;  decrement length counter        
            JNZ     LOOP1           ; go  until 11 bytes moved    
;
; ---------------------------------------------------------       
; CONTINUE SCANNING THE DIRECTORY
; ---------------------------------------------------------
;             
            LDA     FILECNT         ; prepare filecounter    
            INR     A               ; increment
            STA     FILECNT         ; for next hit
            CPI     255             ; 255 files is overflow
            JZ      OVERFLOW        ; terminate
            LXI     D,FCB           ; Find next file
            MVI     C,SCANNEXT      ; FCB still in process
            CALL    BDOS            ; work horse
            CPI     255             ; end of listing ?
            JNZ     LOOP            ; Repeat if found
;
;---------------------------------------------------------       
; GO SORT THET TABLE
;---------------------------------------------------------

            LDA     SORTFLAG        ; Check if the SORT flag is set
            ORA     A               ; if so ?
            CNZ     SORT            ; Go do the Bubble sort
;
;---------------------------------------------------------       
; DISPLAY THE TABLE TO CONSOLE
;---------------------------------------------------------
;
            CALL    USTEXT      ; Signon message
            DB      'Directory listing of ',0
            LDA     FILECNT     ; Get filecounter
            MOV     L,A         ; move to HL
            MVI     H,0         ;
            CALL    DECOUT      ; Display file count
            CALL    USTEXT      ; Following
            DB      ' files',0  ; by text files
            LDA     CRCFLAG     ; get CRCFLAG
            ORA     A           ; test
            JZ      DISP0       ; nope skip
            CALL    USTEXT      ; Add text
            DB      ' with CRC',0 ; that CRC will be added    
DISP0:      LDA     SIZEFLAG    ; Get size flag
            ORA     A           ; test
            JZ      DISP1       ; nope skip
            CALL    USTEXT      ; output
            DB      ' and Records',0 ; records to signon   
DISP1:      CALL    USTEXT      ; and terminate
            DB      CR,LF,CR,LF,0     ; by CR LF
;            
            LXI     H,FILES     ; Start of buffer
            LDA     FILECNT     ; Get file counter
            MOV     B,A         ; move it to B
            LXI     D,11        ; entry length for file
DISP2:      CALL    DISPFIL     ; Display the file at HL
            DAD     D           ; Add offset to next file 
            DCR     B           ; increment file counter
            JZ      DONE        ; all done exit
            JMP     DISP2       ; next file please
;                        
DONE:       CALL    USTEXT      ; Signoff message
            DB      CR,LF,'Thanks for using LD Ver 0.0B2',0
            JMP     0

; ---------------------------------------------------------       
; DISPLAY ONE FILE ENTRY POINTED BY HL
; ---------------------------------------------------------
;
DISPFIL:    PUSH    B           ; Save      
            PUSH    D           ; All   
            PUSH    H           ; registers
            MVI     B,11        ; File name length
DISPFIL0:   MOV     C,M         ; get byte
            CALL    USOUT       ; to console
            MVI     A,4         ; Pplace .
            CMP     B           ; between file
            JNZ     DISPFIL1    ; and     
            MVI     C,'.'       ; extension
            CALL    USOUT       ;
DISPFIL1:   INX     H           ; bump index
            DCR     B           ; decrement counter
            JNZ     DISPFIL0    ; until zero
; CRC flag active ?            
            LDA     CRCFLAG     ; Get CRCFLAG
            ORA     A           ; test
            JZ      DISPFIL4    ; nope skip    
            POP     H           ; get pointer in table
            PUSH    H           ; save again
            XRA     A           ; clear
            STA     CRCFCB      ; defult drive
            MVI     C,11        ; byte length of filename
            LXI     D,CRCFCB+1  ; at FCB+1
DISPFIL2:   MOV     A,M         ; get that byte
            STAX    D           ; and build
            INX     D           ; the FCB
            INX     H           ;
            DCR     C           ;
            JNZ     DISPFIL2    ;
            MVI     C,36        ; Clear out
            XRA     A           ; the FCB block    
DISPFIL3:   STAX    D           ;
            INX     D           ;
            DCR     C           ;
            JNZ     DISPFIL3    ;    
            CALL    CALCCRC     ; get CRC value
            CALL    USTEXT      ; prepare display 
            DB      ' - 0x',0   ; for it    
            LHLD    CRC         ; Get CRC value
            CALL    HEXOUT      ; HEX output it
; SIZE flag active ?              
DISPFIL4:   LDA     SIZEFLAG    ; Get size glag
            ORA     A           ; test
            JZ      DISPFIL9    ; nope    
            POP     H           ; get buffer pointer
            PUSH    H           ; save again
            XRA     A           ; clear default drive
            STA     SIZEFCB     ;
            MVI     C,11        ; file length
            LXI     D,SIZEFCB+1 ; at FCB +1
DISPFIL5:   MOV     A,M         ; move that name
            STAX    D           ;
            INX     D           ;       
            INX     H           ;
            DCR     C           ;
            JNZ     DISPFIL5    ;       
            MVI     C,36        ; Clear out 
            XRA     A           ; the FCB
DISPFIL6:   STAX    D           ;    
            INX     D           ;    
            DCR     C           ;
            JNZ     DISPFIL6    ;
            CALL    GETSIZE     ; Display that record number    
;            
DISPFIL9:   MVI     C,CR        ; output
            CALL    USOUT       ; CR
            MVI     C,LF        ; output 
            CALL    USOUT       ; LF
            POP     H           ; restore
            POP     D           ; all 
            POP     B           ; registers
            RET                 ; and return
;
; ---------------------------------------------------------       
; BUBBLE SORT TABLE
; ---------------------------------------------------------
;
SORT:       LDA     FILECNT     ; Table length
            MOV     D,A    
OUTER:      DCR     D           ; Run N-1 times
            RZ                  ; If D=0, we are done
            LXI     H,FILES     ; HL points to current element (Entry A)
            MOV     B,D         ; B = Inner loop counter
INNER:      PUSH    B           ; Save inner counter
            PUSH    D           ; Save outer counter
            PUSH    H           ; Save pointer to Entry A
            LXI     D,11        ; Calculate pointer to Entry B (HL + 11)
            DAD     D
            PUSH    H           ; Save pointer to Entry B
;
; ---------------------------------------------------------       
; COMPARE ENTRY A AND ENTRY B
; CURRENT STACK: [TOP] PTRB, PTRA, OUTER, INNER
; ---------------------------------------------------------
;
            XCHG                ; DE = Entry B
            POP     H           ; HL = Entry B
            POP     D           ; DE = Entry A
            PUSH    D           ; Put PtrA back
            PUSH    H           ; Put PtrB back
            CALL    COMPARE     ; Compare (DE) and (HL)
            POP     H           ; HL = Entry B
            POP     D           ; DE = Entry A
            PUSH    D           ; Put PtrA back
            PUSH    H           ; Put PtrB back
            CC      SWAP        ; If Carry (Entry B < Entry A), swap them
;
;---------------------------------------------------------
;   CLEAN UP AND ITERATE 
;---------------------------------------------------------
;
            POP     H           ; Clear PtrB off stack
            POP     H           ; HL = PtrA
            LXI     D,11        ; Move HL to next entry for next iteration
            DAD     D
            POP     D           ; Restore Outer counter
            POP     B           ; Restore Inner counter
            DCR     B           ; Decrement inner loop
            JNZ     INNER       ; Repeat inner loop
            JMP     OUTER       ; Repeat outer loop
;
; ---------------------------------------------------------
; COMPARE: COMPARES 11 BYTES AT (DE) AND (HL)
; RETURNS CARRY FLAG (CY) IF (HL) > (DE)
; ---------------------------------------------------------
;
COMPARE:    MVI     C,11        ; Byte counter
CMP_LP:     LDAX    D           ; A = Byte from Entry DE
            MOV     B,A         ; Move to B
            MOV     A,M         ; get byte from Entry HL
            CMP     B           ; Compare
            RNZ                 ; If not equal, we found our order (CY set accordingly)
            INX     D           ; Move to next byte 
            INX     H           ; both entries
            DCR     C           ; decrement the counter
            JNZ     CMP_LP      ; next hit
            RET                 ; They are identical

; ---------------------------------------------------------
; SWAP: SWAPS 11 BYTES BETWEEN (DE) AND (HL)
; ---------------------------------------------------------
;
SWAP:       MVI     C,11
SWAP_LP:    LDAX    D           ; Get byte from DE
            MOV     B,M         ; Get byte from HL
            MOV     M,A         ; Put (DE) in (HL)
            MOV     A,B         ; Put (HL) in (DE)
            STAX    D           ;
            INX     D           ; bump
            INX     H           ; both index
            DCR     C           ; decrerment counter
            JNZ     SWAP_LP     ; next byte
            RET                 ; and return

; ---------------------------------------------------------
; OPEN FILE AND CALCULATE THE CRC
; ---------------------------------------------------------
;
CALCCRC:    LXI		H,0FFFFH	; preset CRC
            SHLD	CRC			; store it
            MVI     C,SETDMA
            LXI     D,CRCBUFFER
            CALL    BDOS
            MVI		C,OPENF		;open the file
            LXI		D,CRCFCB
            CALL	BDOS
            INR     A
            JNZ     CALC9
            CALL    USOUT
            DB      'LD: Error opening file',0
            RET
CALC9:      LXI		D,CRCFCB	; point to file
            MVI		C,READS		; read next record
            CALL	BDOS		; via bdos
            INR     A
            RZ                  ; unable to read
            JMP     CALC8
            
CALC0:      LXI		D,CRCFCB	; point to file
            MVI		C,READS		; read next record
            CALL	BDOS		; via bdos
            CPI     1           ; end of file ?
            RZ                  ; end of file
CALC8:      LXI 	H,CRCBUFFER ; hl points to start of buffer
            MVI		C,128		; One record is 128 bytes
CALC2:	    MOV 	A,M         ; a = current character in string
            STA 	BYT         ; save in byt
            LDA		ASCIIFLAG	; Get ASCII mode
            ORA		A			; test for it
            JZ		CALC3		; no Skip test
            LDA		BYT			; get last byte
            CPI		EOF			; is it EOF ?
            JZ      CALC4		; yes return
CALC3:	    CALL 	UPDT       	; update the crc
            INX 	H           ; point to next character in string
            DCR		C           ; Decrementthe buffer pointer counter
            JNZ 	CALC2       ; no yet at end, repeat loop for rest of string
            JMP     CALC0       
            
CALC4:      LXI     D,CRCFCB    ; point to FCB
            MVI     C,CLOSEF    ; close that file
            CALL    BDOS        ;
            INR     A           ; test
            RZ                  ; if error
            CALL    USOUT       ; display that
            DB      'LD: Error closing file.',0             
            RET                 ; and return
;		
;----------------------------------------------------
; UPDATE CRC BASED ON CURRENT CHARACTER FROM BUFFER
;----------------------------------------------------
;
UPDT:       PUSH 	PSW         ; Save ACU
            PUSH 	B           ; Save BC
            PUSH 	H           ; Save HL
            XRA 	A           ; a = zero
            STA		CEE+1       ; upper 8 bits of cee is zero
            LDA 	BYT         ; lower 8 bits of cee is character
            STA 	CEE         ; cee = current character as 16 bit number
            MOV 	B,A
            LDA 	CRC+1       ; a = upper 8 bits of crc
            XRA 	B           ; xor crc>>8 ^ cee
            STA 	INDX        ; result is index into the crc table
            XRA 	A           ; upper 8 bits of index is zero
            STA 	INDX+1
            LDA 	CRC         ; crc = crc << 8
            STA 	CRC+1
            XRA 	A
            STA 	CRC
            LHLD 	INDX        ; bc = index * 2
            MOV 	B,H
            MOV 	C,L
            DAD 	B
            MOV 	B,H
            MOV 	C,L
            LXI 	H,TBL       ; hl = table[index]
            DAD 	B           ; hl points to entry in table
            MOV 	A,M         ; low order 8 bits of table[index]
            STA 	TBLWRD
            MOV 	B,A
            LDA 	CRC         ; low 8 bits of crc
            XRA 	B           ; crc = (crc>>8) ^ table[index]
            STA 	CRC         ; save the new crc
            INX 	H
            MOV 	A,M
            STA 	TBLWRD+1
            MOV 	B,A
            LDA 	CRC+1
            XRA 	B           ; upper 8 bits of crc
            STA 	CRC+1       ; crc = (crc >> 8) ^ table[index]
            POP 	H
            POP 	B
            POP 	PSW
            RET
;
;------------------------------------------------------------------------ 
; PRINT HL AS HEX 
;------------------------------------------------------------------------				
;            
GETSIZE:	CALL    USTEXT      ; text separator
            DB      ' - ',0     ;
            MVI		C,35		; setup file size opcode
			LXI		D,SIZEFCB	; and def fcb
			CALL	BDOS		; get size
			LHLD	SIZEFCBR	; get record number
			CALL	DECOUT3		; output it
            RET
;
;------------------------------------------------------------------------ 
; PRINT HL AS HEX 
;------------------------------------------------------------------------				
;
HEXOUT: 	PUSH	H			; Save HL
            PUSH	D			; Save DE
            PUSH	B			; Save BC
            PUSH	PSW			; Save PSW
            MOV 	A,H         ; Get HIGH byte
            CALL 	PRNHL1      ; Output it
            MOV 	A,L         ; Get LOW byte
            CALL	PRNHL1		; Output it
            POP		PSW			; Restore PSW
            POP		B			; Restore BC
            POP		D			; Restore DE
            POP		H			; Restore HL
            RET					; Return to caller
PRNHL1:     PUSH 	PSW         ; Save low digit
            RRC                 ; Shift
            RRC                 ; high
            RRC                 ; digit
            RRC                 ; into low
            CALL 	PRNHL2      ; Display a single digit
            POP 	PSW         ; Restore low digit
            CALL	PRNHL2		; Display a single digit
            RET					; Return from subroutine
PRNHL2:	    ANI 	0Fh         ; Remove high digit
            CPI	 	10          ; Convert to ASCII
            SBI 	2Fh			; Adjust
            DAA					; Digital adjust acu
            MOV		C,A
            CALL	USOUT		; Output the digit
            RET
;
;-----------------------------------------------------------------------
; ** BINAIR TO ASCII  5 DIGITS IN HL LEADING 0 DELETED
;-----------------------------------------------------------------------
;
DECOUT:			MVI		B,80H				; flag to no print
				LXI		D,-10000			; setup 10000
				CALL	DECNO				; see how many
				LXI		D,-1000				; setup 1000
				CALL	DECNO				; see howmany
				LXI		D,-100				; setup 100
				CALL	DECNO				; see how many
				LXI		D,-10				; setup 10
				CALL	DECNO				; see howmany
				MVI		B,0					; clear inhibit print flag
				LXI		D,-1				; setup 1
DECNO:			INR		B					; see howmany
				DAD		D					; substract it
				JC		DECNO				; carry ?
				DCR		B					; yes adjust count
				XCHG						; to de
				XRA		A					; clear carry clear acu
				SUB		L					; substarct l
				MOV		L,A					; save l
				MVI		A,0					; save carry but a to 0
				SBB		H					; substract h
				MOV		H,A					; save h
				XCHG						; back to hl
				DAD		D					; readd
				MOV		A,B					; get no print flag
				CPI		80H					; still set
				RZ							; yes then return
				MOV		A,B					; get flag
				ANI		7FH					; mask out flag
				ORI		'0'					; make ascii  
				PUSH	H					; save hl
				MOV		C,A	
				CALL	USOUT				; echo it
				POP		H					; restore hl
				MVI		B,0					; disable flag now
				RET	
;
;-----------------------------------------------------------------------
; ** BINAIR TO ASCII  3 DIGITS IN HL ALIGNED WITH SPACES
;-----------------------------------------------------------------------
;
DECOUT3:    MVI     B,80H
            LXI		D,-100		; setup 100
			CALL	DECNO3		; see how many
			LXI		D,-10		; setup 10
			CALL	DECNO3		; see howmany
			MVI		B,0			; clear inhibit print flag
			LXI		D,-1		; setup 1
DECNO3:		INR		B			; see howmany
			DAD		D			; substract it
			JC		DECNO3		; carry ?
			DCR		B			; yes adjust count
			XCHG				; to de
			XRA		A			; clear carry clear acu
			SUB		L			; substarct l
			MOV		L,A			; save l
			MVI		A,0			; save carry but a to 0
			SBB		H			; substract h
			MOV		H,A			; save h
			XCHG				; back to hl
			DAD		D			; readd
			MOV		A,B			; get no print flag
			CPI		80H			; still set
			JZ      DECNO1		; yes then return
			MOV		A,B			; get flag
			ANI		7FH			; mask out flag
			ORI		'0'			; make ascii  
DECNO0:		PUSH	H			; save hl
			MOV		C,A	
			CALL	USOUT		; echo it
			POP		H			; restore hl
			MVI		B,0			; disable flag now
			RET	
DECNO1:     PUSH	H			; save hl
            MVI     C,' '
			CALL	USOUT		; echo it
			POP		H			; restore hl
            RET
;
;------------------------------------------------------------------------------
;       CHARACTER  IN C TO CONSOLE
;------------------------------------------------------------------------------
;
USOUT:	    PUSH	B			; To be shure
            PUSH	D			; save all registers 
            PUSH	H			; :-)
            MOV		E,C			; char to E
            MVI		C,CONOUT	; tell Char Out	
            CALL	BDOS		; work bdos ....
            POP		H			; restore 
            POP		D           ;
            POP		B           ;
            RET                 ; and Return
;
;------------------------------------------------------------------------------
; DEFINE *.* WILDCARD IN DEFAULT FCB
;------------------------------------------------------------------------------
;            
INITFCB:    PUSH    H           ; save HL
            XRA     A           ; Clear ACU
            STA     FCB         ; Set Default drive
            LXI     H,FCB+1     ; FCB+1
            MVI     B,11        ; 11 bytes
INITFCB1:   MVI     M,'?'       ; of '?'  character
            INX     H           ; bump index
            DCR     B           ; decrement counter
            JNZ     INITFCB1    ; until all done    
            POP     H           ; restore HL
            RET                 ; and return
;
;-----------------------------------------------------------------------
; DISPLAY MESSAGE [PC] or [HL]
;-----------------------------------------------------------------------
;
USTEXT: 		POP 	H        ; Get address
				CALL 	PRTSTR   ; Output message
				PCHL             ; And return
PRTSTR: 		MOV 	A,M      ; Get byte from message
				INX 	H        ; Advance to next
				ANA 	A        ; End of message?
				RZ               ; Yes, exit
				MOV		C,A
				CALL 	USOUT    ; Output the character
				JMP 	PRTSTR   ; And proceed
;
;-----------------------------------------------------------------------
; DISPLAY HELP MESSAGE 
;-----------------------------------------------------------------------
;
DISPHELP:       CALL    USTEXT
                DB      'LD [????????.*] [/S] [/C] [/Z]',CR,LF
                DB      '/S - Sort file listing',CR,LF
                DB      '/C - Show CRC16 of each displayed file',CR,LF
                DB      '/R - Show number of records of displayed files',CR,LF,
                DB      'Public Domain software by WOEPER 2026',0
                JMP     0
;
;-----------------------------------------------------------------------
; DISPLAY OVERFLOW MESSAGE 
;-----------------------------------------------------------------------
;
OVERFLOW:       CALL    USTEXT
                DB      'LD: Exceeded 256 files !',CR,LF,0
                JMP     0
;                
;------------------------------------------------------------------------------
;   CRC16-CCITT-FALSE TABLE
;------------------------------------------------------------------------------
;
TBL:    	DW 0000H, 1021H, 2042H, 3063H, 4084H, 50A5H, 60C6H, 70E7H
            DW 8108H, 9129H, A14AH, B16BH, C18CH, D1ADH, E1CEH, F1EFH
            DW 1231H, 0210H, 3273H, 2252H, 52B5H, 4294H, 72F7H, 62D6H
            DW 9339H, 8318H, B37BH, A35AH, D3BDH, C39CH, F3FFH, E3DEH
            DW 2462H, 3443H, 0420H, 1401H, 64E6H, 74C7H, 44A4H, 5485H
            DW A56AH, B54BH, 8528H, 9509H, E5EEH, F5CFH, C5ACH, D58DH
            DW 3653H, 2672H, 1611H, 0630H, 76D7H, 66F6H, 5695H, 46B4H
            DW B75BH, A77AH, 9719H, 8738H, F7DFH, E7FEH, D79DH, C7BCH
            DW 48C4H, 58E5H, 6886H, 78A7H, 0840H, 1861H, 2802H, 3823H
            DW C9CCH, D9EDH, E98EH, F9AFH, 8948H, 9969H, A90AH, B92BH
            DW 5AF5H, 4AD4H, 7AB7H, 6A96H, 1A71H, 0A50H, 3A33H, 2A12H
            DW DBFDH, CBDCH, FBBFH, EB9EH, 9B79H, 8B58H, BB3BH, AB1AH
            DW 6CA6H, 7C87H, 4CE4H, 5CC5H, 2C22H, 3C03H, 0C60H, 1C41H
            DW EDAEH, FD8FH, CDECH, DDCDH, AD2AH, BD0BH, 8D68H, 9D49H
            DW 7E97H, 6EB6H, 5ED5H, 4EF4H, 3E13H, 2E32H, 1E51H, 0E70H
            DW FF9FH, EFBEH, DFDDH, CFFCH, BF1BH, AF3AH, 9F59H, 8F78H
            DW 9188H, 81A9H, B1CAH, A1EBH, D10CH, C12DH, F14EH, E16FH
            DW 1080H, 00A1H, 30C2H, 20E3H, 5004H, 4025H, 7046H, 6067H
            DW 83B9H, 9398H, A3FBH, B3DAH, C33DH, D31CH, E37FH, F35EH
            DW 02B1H, 1290H, 22F3H, 32D2H, 4235H, 5214H, 6277H, 7256H
            DW B5EAH, A5CBH, 95A8H, 8589H, F56EH, E54FH, D52CH, C50DH
            DW 34E2H, 24C3H, 14A0H, 0481H, 7466H, 6447H, 5424H, 4405H
            DW A7DBH, B7FAH, 8799H, 97B8H, E75FH, F77EH, C71DH, D73CH
            DW 26D3H, 36F2H, 0691H, 16B0H, 6657H, 7676H, 4615H, 5634H
            DW D94CH, C96DH, F90EH, E92FH, 99C8H, 89E9H, B98AH, A9ABH
            DW 5844H, 4865H, 7806H, 6827H, 18C0H, 08E1H, 3882H, 28A3H
            DW CB7DH, DB5CH, EB3FH, FB1EH, 8BF9H, 9BD8H, ABBBH, BB9AH
            DW 4A75H, 5A54H, 6A37H, 7A16H, 0AF1H, 1AD0H, 2AB3H, 3A92H
            DW FD2EH, ED0FH, DD6CH, CD4DH, BDAAH, AD8BH, 9DE8H, 8DC9H
            DW 7C26H, 6C07H, 5C64H, 4C45H, 3CA2H, 2C83H, 1CE0H, 0CC1H
            DW EF1FH, FF3EH, CF5DH, DF7CH, AF9BH, BFBAH, 8FD9H, 9FF8H
            DW 6E17H, 7E36H, 4E55H, 5E74H, 2E93H, 3EB2H, 0ED1H, 1EF0H
;
;----------------------------------------------------------------------
;		STORAGE AREA AND STACK
;----------------------------------------------------------------------
;
;
BYT:   	    DB 		0           ; byte used for building the table
INDX:       DW 		0           ; index into the crc table
CEE:        DW 		0           ; word used for building the table
POLY:       DW 		01021H      ; ccitt polynomial x^16 + x^12 + x^5 + 1
CRC:        DW 		0           ; 16 bit crc
TBLWRD:     DW 		0           ; current entry in crc table

SIZEFCB:    DB      0           ; Default drive/alternate drive
SIZEFCBF:   DB      '????????'  ; Filename
SIZEFCBE:   DB      '???'       ; Extension
            DS      3,0         ; BDOS work area
            DS      2,0
            DS      16,0
SIZEFCBR:   DS      3,0         ; record number
;
;
CRCFCB:     DB      0           ; Default drive/alternate drive
            DB      '????????'  ; Filename
            DB      '???'       ; Extension
            DS      2,0         ; BDOS work area
            DS      16,0
CRCFCBR:    DS      3,0         ; Record number
;            
CRCBUFFER:  DS      128,0       ; CRC reading buffer
;
FILECNT:    DB      0
DISPCNT:    DB      0
CRCFLAG:    DB      0
SORTFLAG:   DB      0
ASCIIFLAG:  DB      0
SIZEFLAG:   DB      0
FILES:      DS      12*256
;
            DS		128,0       ; 128 bytes local Stack space
STACK	    EQU		$
;
            END     0
;
        
