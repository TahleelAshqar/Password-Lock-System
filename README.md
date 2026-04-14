# Password-Lock-System
Password lock system using PIC16F877 with keypad input and LCD.

This project implements a password-based locking system using PIC16F877 in Assembly.  
The system reads input from a keypad, validates a 4-digit password, and displays feedback on an LCD.

## Features
- 4-digit password input via keypad
- LCD feedback:
  - "OPEN" → correct password
  - "CLOSE" → wrong attempt
  - "ERROR" → system locked after 3 failed attempts
- Attempt counter with lock mechanism
- Lock reset triggered by external input (RA2)
- Keypad scanning (4x4 matrix)
- LCD control in 8-bit mode

## Hardware Components
- PIC16F877 microcontroller
- 4x4 keypad (PORTB)
- LCD display (PORTD + PORTE control lines)
- Input pin (RA2) for system reset/unlock

## How It Works
1. User enters a 4-digit password using the keypad
2. Each digit is masked with `*` on the LCD
3. The system compares the input to the correct password: `1234`
4. If correct:
   - Displays "OPEN"
   - Resets the attempt counter
5. If incorrect:
   - Displays "CLOSE"
   - Increments the attempt counter
6. After 3 wrong attempts:
   - Displays "ERROR"
   - Locks the system until RA2 input changes

## Key Concepts Used
- Bank switching (STATUS register)
- I/O configuration (TRIS registers)
- Keypad matrix scanning
- LCD command/data handling
- Delay routines (software timing)
- State-based control flow

## Notes
- LCD operates in 8-bit mode
- Keypad uses internal pull-ups on PORTB
- Password is hardcoded in the program

## Author
Tahleel Ashkar
