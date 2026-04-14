LIST    P=16F877
INCLUDE <P16F877.INC>
__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_OFF & _HS_OSC & _WRT_ENABLE_ON & _LVP_OFF & _DEBUG_OFF & _CPD_OFF


;Password Storage:
IN_1         EQU 0x30 ; EQU = a bit in storage
IN_2         EQU 0x31
IN_3         EQU 0x32
IN_4         EQU 0x33
ATTEMPTS     EQU 0x29 ; counts how many wrong passward we have pressed
TEMP_BYTE    EQU 0x20 ; store char to help convert to LCD

D1           EQU 0x22 ; מונה ל delay func
D2           EQU 0x23 ; מונה ל delay func
D3           EQU 0x24 ; מונה ל delay func

ORG     0x00 ; start the code from 0x00 in memory.
GOTO    START 
ORG     0x10

START:
	; go to Bank 0 and clear all ports:
    BCF     STATUS, RP0 
    BCF     STATUS, RP1
    CLRF    PORTD
    CLRF    PORTE
    CLRF    PORTA  

	; go to Bank 1 and make all PORTA digital: for RA2 to actually work we need this:
    BSF     STATUS, RP0     ; Bank 1
	MOVLW   0x07            ; all digital
	MOVWF   ADCON1

    CLRF    TRISD ; assign output
    CLRF    TRISE ; assign output

    MOVLW   0x0F
    MOVWF   TRISB ; RB0-3 = 1, RB4-7 = 0.
    BCF     OPTION_REG, 7 ; bit 7 in here is RBPU. מפעיל pull-ups פנימיים ב־ PORTB

    MOVLW   B'00000100' ; RA2 = 1(input)
    MOVWF   TRISA ; decides the direction of PORTA. 

    BCF     STATUS, RP0     ; move back to Bank 0.

    CLRF    ATTEMPTS        ; reset attempts on start.

    CALL    LCD_INIT


; --- Main Loop ---
PASSWORD_ENTRY:
    CALL    LCD_CLEAR ; clears view for next password.

    ; Get Digit 1
    CALL    GET_KEY
    MOVWF   IN_1 ; first password digit: move the value to the variable.
    MOVLW   '*'
    CALL    LCD_SEND_CHAR ; shows * on the screen.

    ; Get Digit 2
    CALL    GET_KEY
    MOVWF   IN_2 ; second digit
    MOVLW   '*'
    CALL    LCD_SEND_CHAR

    ; Get Digit 3
    CALL    GET_KEY
    MOVWF   IN_3 ; third digit
    MOVLW   '*'
    CALL    LCD_SEND_CHAR

    ; Get Digit 4
    CALL    GET_KEY
    MOVWF   IN_4 ; fourth digit
    MOVLW   '*'
    CALL    LCD_SEND_CHAR

	;----------------------------------- 
	; Check password: 1234

    ; Check 1st Digit
    MOVLW   0x01 ;  W = 1
    SUBWF   IN_1, W ; W - IN_1 = ?. if 0, which means equals, which means the first digit is correct, check second digit. else, WRONG_PASS. 
    BTFSS   STATUS, Z
    GOTO    WRONG_PASS

    ; Check 2nd Digit (Must be 2)
    MOVLW   0x02 ; W = 2
    SUBWF   IN_2, W ; W - IN_2 = ?. 0 - move to third digit. else, WRONG_PASS.
    BTFSS   STATUS, Z 
    GOTO    WRONG_PASS

    ; Check 3rd Digit (Must be 3)
    MOVLW   0x03 ; w = 3
    SUBWF   IN_3, W ; W - IN_3 = ?. 0 - move to fourth digit. else, WRONG_PASS.
    BTFSS   STATUS, Z
    GOTO    WRONG_PASS

    ; Check 4th Digit (Must be 4)
    MOVLW   0x04 ; w = 4
    SUBWF   IN_4, W ;  W - IN_4 = ?. 0 - correct password! Else, WRONG_PASS.
    BTFSS   STATUS, Z
    GOTO    WRONG_PASS

    ; If all passed: password correct!
    CLRF    ATTEMPTS  ; reset attempts
    CALL    LCD_CLEAR ; clear the screen
    CALL    DISPLAY_OPEN ; show "OPEN" on screen
    GOTO    WAIT_RESET ; תני למשתמש לראות את התוצאה לפני שמאפסים

;---------------------------------------

WRONG_PASS:
    ; count wrong attempts (+1)
    INCF    ATTEMPTS, F

    ; if ATTEMPTS == 3: show ERROR and lock until RA2 changes:
    MOVLW   0x03
    SUBWF   ATTEMPTS, W     ; W = ATTEMPTS - 3. if W = 0, ERROR, just skip. Else, SHOW_CLOSE
    BTFSS   STATUS, Z
    GOTO    SHOW_CLOSE      ; display "CLOSE" on screen

;---------------------------------------
; Display ERROR and lock until RA2 changes
ERROR_LOCK:
    CALL    LCD_CLEAR ; clear screen
    CALL    DISPLAY_ERROR ; display "ERROR" on screen

    ; save current RA2 state
    MOVF    PORTA, W 
    ANDLW   0x04 ; RA2 = 1 -> w = 0x04 , RA2 = 0 -> W = 0x00.
    MOVWF   TEMP_BYTE ; the old state of RA2

;---------------------------------------
; keep locked until RA2 status changes
LOCK_LOOP:
    MOVF    PORTA, W ; תקרא המצב הנוכחי של PORTA
    ANDLW   0x04 ; RA2 = 1 -> w = 0x04 , RA2 = 0 -> W = 0x00
    XORWF   TEMP_BYTE, W ; if equal = nothing changed = 0 -> LOCK_LOOP
    BTFSC   STATUS, Z
    GOTO    LOCK_LOOP

    ; switch changed -> reset and go back
    CLRF    ATTEMPTS
    GOTO    PASSWORD_ENTRY ; start over

;---------------------------------------
; display "CLOSE" on screen
SHOW_CLOSE:
    CALL    LCD_CLEAR
    CALL    DISPLAY_CLOSE

;---------------------------------------
; Wait a couple seconds so user can see the message
WAIT_RESET:
    CALL    DELAY_LONG
    CALL    DELAY_LONG
    CALL    DELAY_LONG
    GOTO    PASSWORD_ENTRY  ; Start over

;---------------------------------------
; Helper to handle a single key press/release
GET_KEY:
    CALL    WAIT_FOR_PRESS
    CALL    SCAN_KEYPAD
    MOVWF   TEMP_BYTE       ; Save result
    CALL    WAIT_FOR_RELEASE
    MOVF    TEMP_BYTE, W    ; Return result in W
    RETURN

;---------------------------------------
; מאפסת שורות (4-7)
; קוראת עמודות (0-3)
; if a column equals 0 - a change - it was pressed there
WAIT_FOR_PRESS:
    MOVLW   0x00
    MOVWF   PORTB ; RB4–RB7 = 1 (no press),to recognize keyword press
    MOVF    PORTB, W
    ANDLW   0x0F 
    SUBLW   0x0F ; check if any of RB0–RB3 = 0, to regonize if there was a press
    BTFSC   STATUS, Z 
    GOTO    WAIT_FOR_PRESS
    CALL    DELAY_LONG
    RETURN

;---------------------------------------
; קוראת העמודות (0-3)
; waits until all columns equal 1 - none of them is pressed
; if a column equals 1 = it's pressed
WAIT_FOR_RELEASE:
    MOVLW   0x00
    MOVWF   PORTB ;RB4–RB7 = 0
    MOVF    PORTB, W
    ANDLW   0x0F ; keep RB0–RB3, that's what we need to recognize a release
    SUBLW   0x0F
    BTFSS   STATUS, Z ; if z = 0 -> a key is still pressed. Else, relearsed 
    GOTO    WAIT_FOR_RELEASE
    CALL    DELAY_LONG
    RETURN

;---------------------------------------
;RB0-3: cols
;RB4-7: rows
; 0 - something was pressed. 
; 1 -  nothing got pressed, move.

SCAN_KEYPAD:
    ; RB4 = 0 -> Row 1
    MOVLW   B'11101111'
	; now we check which column was the key pressed to find it:
    MOVWF   PORTB
    BTFSS   PORTB, 0 ; if RB0 = 0 -> return 1:
    RETLW   0x01
    BTFSS   PORTB, 1 ; if RB1 = 0 -> return 2:
    RETLW   0x02
    BTFSS   PORTB, 2 ; if RB1 = 0 -> return 3:
    RETLW   0x03
    BTFSS   PORTB, 3 ; if RB1 = 0 -> return A:
    RETLW   0x0A

    ; RB5 = 0 -> Row 2
    MOVLW   B'11011111'
	; now we check which column was the key pressed to find it:
    MOVWF   PORTB
    BTFSS   PORTB, 0 ; if RB0 = 0 -> return 4:
    RETLW   0x04
    BTFSS   PORTB, 1 ; if RB0 = 0 -> return 5:
    RETLW   0x05
    BTFSS   PORTB, 2 ; if RB0 = 0 -> return 6:
    RETLW   0x06
    BTFSS   PORTB, 3 ; if RB0 = 0 -> return B:
    RETLW   0x0B

    ; RB6 = 0 -> Row 3
    MOVLW   B'10111111'
	; now we check which column was the key pressed to find it:
    MOVWF   PORTB
    BTFSS   PORTB, 0 ; if RB0 = 0 -> return 7:
    RETLW   0x07
    BTFSS   PORTB, 1 ; if RB0 = 0 -> return 8:
    RETLW   0x08
    BTFSS   PORTB, 2 ; if RB0 = 0 -> return 9:
    RETLW   0x09
    BTFSS   PORTB, 3 ; if RB0 = 0 -> return C:
    RETLW   0x0C

    ; RB7 = 0 -> Row 4
    MOVLW   B'01111111'
	; now we check which column was the key pressed to find it:
    MOVWF   PORTB
    BTFSS   PORTB, 0 ; if RB0 = 0 -> return *:
    RETLW   0x0E     ; *
    BTFSS   PORTB, 1 ; if RB0 = 0 -> return 0:
    RETLW   0x00     ; 0
    BTFSS   PORTB, 2 ; if RB0 = 0 -> return #:
    RETLW   0x0F     ; #
    BTFSS   PORTB, 3 ; if RB0 = 0 -> return D:
    RETLW   0x0D     ; D
    RETLW   0x00

;---------------------------------------
; It configures the LCD to operate in 8-bit mode with two display lines, 
; and turns the display on with the cursor and blinking disabled.
LCD_INIT:
    MOVLW   0x38
    MOVWF   TEMP_BYTE
    CALL    LCD_SEND_CMD
    MOVLW   0x0C
    MOVWF   TEMP_BYTE
    CALL    LCD_SEND_CMD
    RETURN

;---------------------------------------
; clears the LCD screen and resets the cursor position.
LCD_CLEAR:
    MOVLW   0x01
    MOVWF   TEMP_BYTE
    CALL    LCD_SEND_CMD
    RETURN

;---------------------------------------
; OPEN on screen
DISPLAY_OPEN:
    MOVLW   'O'
    CALL    LCD_SEND_CHAR
    MOVLW   'P'
    CALL    LCD_SEND_CHAR
    MOVLW   'E'
    CALL    LCD_SEND_CHAR
    MOVLW   'N'
    CALL    LCD_SEND_CHAR
    RETURN

;---------------------------------------
; CLOSE on screen
DISPLAY_CLOSE:
    MOVLW   'C'
    CALL    LCD_SEND_CHAR
    MOVLW   'L'
    CALL    LCD_SEND_CHAR
    MOVLW   'O'
    CALL    LCD_SEND_CHAR
    MOVLW   'S'
    CALL    LCD_SEND_CHAR
    MOVLW   'E'
    CALL    LCD_SEND_CHAR
    RETURN

;---------------------------------------
; ERROR on screen
DISPLAY_ERROR:
    MOVLW   'E'
    CALL    LCD_SEND_CHAR
    MOVLW   'R'
    CALL    LCD_SEND_CHAR
    MOVLW   'R'
    CALL    LCD_SEND_CHAR
    MOVLW   'O'
    CALL    LCD_SEND_CHAR
    MOVLW   'R'
    CALL    LCD_SEND_CHAR
    RETURN

;---------------------------------------
; Takes a char-value stored in W and displays it on screen
LCD_SEND_CHAR:
    MOVWF   TEMP_BYTE ; store the character
    BSF     PORTE, 1 ; RS = 1, sending a value not a command.
    MOVF    TEMP_BYTE, W ; return value to W
    MOVWF   PORTD ; place the value on the LCD data bus
    BSF     PORTE, 0 ; E = 1, prepares the LCD to latch the data
    CALL    DELAY_SHORT
    BCF     PORTE, 0 ; return to E = 0
    CALL    DELAY_LONG
    RETURN

;---------------------------------------
; send a command instruction to the LCD.
LCD_SEND_CMD:
    BCF     PORTE, 1
    MOVF    TEMP_BYTE, W
    MOVWF   PORTD
    BSF     PORTE, 0
    CALL    DELAY_SHORT
    BCF     PORTE, 0
    CALL    DELAY_LONG
    RETURN

;---------------------------------------
; --- Delays ---
; איחור של חומרה כדי שנספיק להציג ולעדכן מה קורה במסך
DELAY_SHORT:
    MOVLW   0x50
    MOVWF   D1
L1: DECFSZ  D1, F
    GOTO    L1
    RETURN

;---------------------------------------
; כך שנוכל לראות בעין הטקסט על המסך לפי המצב של הסיסמה
DELAY_LONG:
    MOVLW   0xFF
    MOVWF   D2
L2: MOVLW   0xFF
    MOVWF   D3
L3: DECFSZ  D3, F
    GOTO    L3
    DECFSZ  D2, F
    GOTO    L2
    RETURN

    END
