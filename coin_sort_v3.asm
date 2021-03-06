;ROBOTIC COIN SORT PROGRAM
;
; BY ADAM JENSEN

    LIST    P=16F874A,R=DEC
    #INCLUDE P16F874A.INC
    __CONFIG _RC_OSC&_WDT_OFF&_CP_OFF&_DEBUG_OFF&_WRT_OFF&_BODEN_ON&_PWRTE_OFF&_LVP_OFF
    __IDLOCS 1010 ; VERSION 1.11

#DEFINE DELAY1  0x0F    ;VALUE TO INITIALIZE COUNT DOWN TIMER

    CBLOCK 0x20 ;START VARIABLE DEFINITION IN REGISTER BANK 0
                ;AT BEGINNING OF USER REGISTER SPACE.

    POSN1       ;BINARY VALUE 0 - 3 REPRESENTING MOTOR 1 POSITION
                ;(ONE OF THE FOUR POSSIBLE POSITION)
                ;INCREMENTING BY ONE MOVES SHAFT CLOCKWISE
    POSN2       ; MOTOR 2 POSITION
    POSN3       ; MOTOR 3 POSITION
    OUT_DATA1   ;ACTUAL NUMERICAL VALUE SENT TO OUTPUT PORT (PORTC) TO ROTATE MOTOR 1. (ARM ROTATION)
                ;THESE WILL BE THE OUTPUTS LISTED BELOW.
    OUT_DATA2   ;ACTUAL VALUE FOR MOTOR 2 (FINGER MOVEMENT)
    OUT_DATA3   ;ACTUAL VALUE FOR MOTOR 3 (LIFT MOVEMENT)
    COIN        ;COIN TYPE 0 - 3, WHICH IS USED TO DETERMINE COIN BASED OPERATIONS
                ;0 = QUARTER
                ;1 = NICKEL
                ;2 = PENNY
                ;3 = DIME

    CSTEPS      ;VARIABLES TO REMEMBER HOW MANY STEPS WERE TAKEN
    CITER
    STPES       ;STEP COUNTER (USED TO COUNT NUMBER OF STEPS REMAINING UNTIL DESTINATION REACHED)
    BACKUP      ;BACKUP VARIABLE (STORE COPIES OF STUFF)
    ITER        ;ITERATIONS (TIMES STEPS COUNTER IS TO BE REPEATED)
    DELAY       ;DELAY COUNTER VARIABLE FOR ARM MOVEMENT
    VAR         ;JUST A GENERAL USE VAR
    ENDC

    ORG 0x00    ;SET CODE ORIGIN AT THIS ADDRESS
    GOTO    MAIN_CODE   ;BYPASS FIRST FOUR PROGRAM LOCATIONS TO AVOID INTERRUPT ISSUES

    ORG 0X04    ;START CODE HERE
MAIN_CODE   ;THIS PROGRAM HAS SEVERAL SUB ROUTINES WHICH WILL WORK TOGETHER TO SORT VARIOUS COINS WITH A ROBOTIC ARM
    ;HERE IS A PROGRAM OUTLINE:
    ;
    ;IDLE_LOOP  <-- WAITING FOR INPUT OF SOME FORM
    ;
    ;CONFIG     <-- SET UP ROBOT FOR RUN MODE
    ;   ROTATE ARM
    ;       > UNTIL CONTACT
    ;   CLOSE HAND
    ;   COUNT STEPS     <-- STEPS COUNTDOWN (TO MAKE SURE HAND IS IN CORRECT START POSITION)
    ;   RETURN
    ;
    ;ARM_UD
    ;   BUTTON INPUT
    ;   APPROPRIATE ARM LIFT
    ;   RETURN
    ;
    ;MAIN_PROGRAM
    ;   CLOSE HAND
    ;       DETECT COIN?
    ;   LIFT ARM
    ;   DETERMINE COIN TYPE (SET NUMBER OF STEPS IN X)
    ;   TAKE X STEPS
    ;   OPEN HAND
    ;   TAKE X STEPS BACK
    ;   LOWER HAND
    ;   RETURN
    ;
    ;MOTORS
    ;   WHICH MOTOR?
    ;       ROTATION & POSITION FOR EACH
    ;   RETURN

    ;ALL MOTOR POSITION AND ROTATION VARIABLES ARE NUMBERED 1 - 3. ALL NUMBERED 1 ARE FOR THE ARM ROTATION MOTOR
    ;ALL NUMBERED 2 ARE FOR THE FINGER MOVEMENT MOTOR. ALL NUMBERED 3 ARE FOR THE LIFT MOTOR.

    ;PORTA BITS 0 - 3 ARE FOR MOTOR 1, PORTC BITS 0 - 3 ARE FOR MOTOR 2 AND PORTC BITS 4 - 7 ARE FOR MOTOR 3
    ;PORTB BITS 0 - 7 ARE FOR INPUT
    ; 0 = CONFIG        * BUTTON
    ; 1 = ARM --> UP    * BUTTON
    ; 2 = ARM --> DOWN  * BUTTON
    ; 3 = SORT PROGRAM  * BUTTON
    ; 4 = EMERGENCY HALT* BUTTON
    ; 5 = COIN DETECTOR         * WIRING (ELECTRICAL CONTACT)
    ; 6 = ARM POSITION DETECTOR * WIRING (ELECTRICAL CONTACT)
    ; 7 = FREE

    ;MOTOR POSITIONS:
    ;   MOTOR1 CLOCKWISE = TO COIN DEPOSITS
    ;       CCWISE = TO COIN POST & ELECTRICAL CONTACT
    ;   MOTOR2 CLOCKWISE = CLOSE HAND
    ;       CCWISE = OPEN HAND
    ;   MOTOR3 CLOCKWISE = LIFT
    ;       CCWISE = LOWER
    ;MOTOR OUTPUTS TO THE MOTOR ARE AS FOLLOWS: 1001, 1010, 0110, 0101, --> LOOP...     (OR 9, 10, 6, 5, ETC.)

    CLRF POSN1  ;SET DEFAULT
    CLRF POSN2
    CLRF POSN3
    CLRF OUT_DATA1
    CLRF OUT_DATA2
    CLRF OUT_DATA3
    CLRF STEPS
    CLRF ITER
    CLRF DELAY
    CLRF COIN
    CLRF BACKUP
    CLRF CSTEPS
    CLRF CITER
    BSF STATUS,RP0  ;SWITCH TO BANK 1
    BCF OPTION_REG,NOT_RBPU ;TURN ON PULL-UPS
    BCF TRISA,0 ;SET PORTA BITS 0 - 3 AS OUTPUT
    BCF TRISA,1
    BCF TRISA,2
    BCF TRISA,3
    CLRF TRISC  ;SET PORTC BITS 0 - 7 AS OUTPUT
    BCF STATUS,RPO  ;SWITCH BACK TO BANK 0
    CLRF PORTA
    CLRF PORTC
                    ; (PORTB BITS 0 - 7 SHOULD ALREADY BE INPUTS)
    BSF PORTA,0     ;SET ARM TO DEFAULT POSITION
    BSF PORTA,3
;=====////////// SEGMENT 1 (IDLE LOOP) \\\\\\\\\\======
    ;THIS IS WHERE THE CHIP WILL BE WHILE WAITING FOR COMMANDS

IDLE_LOOP           ;GET INPUT FROM BUTTONS AND GO TO THE APPROPRIATE SECTION OF CODE
    BTFSS PORTB,0
    GOTO FINGER_CONFIG
    BTFSS PORTB,1
    CALL ARM_UP
    BTFSS PORTB,2
    CALL ARM_DN
    BTFSS PORTB,3
    GOTO MAIN_PROGRAM
    BTFSS PORTB,4
    GOTO EM_HALT

    GOTO IDLE_LOOP  ;LOOP UNTIL SOMETHING HAPPENS

/=====////////// SEGMENT 2 (BOT CONFIGURATION) \\\\\\\\\\=====
    ;THESE ARE THE ROUTINES THAT ENABLE THE USER TO CONFIGURE THE BOT FOR USE
    ;THEY INCLUDE A PRESET CONFIGURATION (FOR COIN DIAMETER CHECK, ETC.)
    ;AND ROUTINES FOR MANUAL MOVEMENT OF PARTS

FINGER_CONFIG   ;THIS CLOSES THE HAND, AND STOPS AT COIN CONTACT. THE COIN USED SHOULD BE A QUARTER. THE COMPUTER WILL THEN OPEN
                ;THE HAND 470 STEPS. AT THIS POINT THE HAND IS OPEN AND THE CHIP KNOWS THE EXACT POSITION OF THE FINGER
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT

    INCF POSN2,F    ;INCREMENENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN2,F   ;MASK OUT BITS 4 - 7 (ROLLS NUMBER FROM 4 BACK TO 0)
    MOVF POSN2,W    ;LOAD NEW POSITION INTO W BEFORE CALLING LOOKUP TABLE
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA2 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    MOVWF PORTC

    BTFSC PORTB,5   ;CHECK FOR COIN CONTACT
    GOTO FINGER_CONFIG  ;IF NONE, CLOSE ANOTHER STEP
                        ;IF CONTACT, OPEN A CERTAIN NUMBER OF STEPS.
    MOVLW 0xD7          ;SET "STEPS" TO 215
    MOVWF STEPS
    MOVLW 0x02          ;SET REPETITIONS TO 1[+1 FOR NONZERO...] (ADDS 256 TO NUMBER)
    MOVWF ITER
COUNTER
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    DECF POSN2,F
    MOVLW B'00000011'   ;MASK AGAIN
    ANDWF POSN2,F       ;NUMBER SHOULD GO FROM 0 TO 256, AND THEN IS MASKED TO 3
    MOVF POSN2,W
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA2     ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR.
    MOVWF PORTC

    DECFSZ STEPS,F  ;IF STEPS IS NONZERO KEEP GOING
    GOTO COUNTER
    DECFSZ ITER,F   ;WHEN STEPS HITS ZERO, CHECK TO SEE HOW MANY ITERATIONS
    GOTO COUNTER    ;IF THERE ARE REMAINING ITERATIONS REPEAT
    ;IF NOT, RAISE THE ARM, AND GO BACK TO IDLE.

    MOVLW 0x0C      ;PREPARE TO RAISE ARM 12 STEPS
    MOVWF STEPS
FINISH              ;RAISE THE ARM, IN PREPARATION FOR NORMAL RUN...
    CALL ARM_UP
    DECFSZ STEPS,F
    GOTO FINISH

    GOTO IDLE_LOOP  ;IF NOT, IDLE

ARM_UP  ;THIS ROUTINE RAISES THE ARM WHEN THE APPROPRIATE BUTTON IS HELD DOWN
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    DECF POSN3,F
    MOVLW B'00000011'   ;MASK AGAIN
    ANDWF POSN3,F       ;NUMBER SHOULD GO FROM 0 TO 256, AND THEN IS MAKSED TO 3
    MOVF POSN3,W
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA3     ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR.
    RLF OUT_DATA3,F     ;ROTATE CONTENTS TO THE LEFT, STORE IN FILE
    RLF OUT_DATA3,F     ;AND REPEAT 4 TIMES TO MOVE VALUES TO FAR LEFT
    RLF OUT_DATA3,F
    RLF OUT_DATA3,F     ;EXAMPLE: 00001001 *ROTATES* --> 10010000
    MOVF OUT_DATA3,W    ;PUT IT BACK IN W
    MOVWF PORTC         ;AND SEND IT TO PORTC (IT SHOULD ONLY AFFECT PINS 4 - 7)

    BTFSS PORTB,1       ;SEE IF THE BUTTON IS STILL PRESSED DOWN
    GOTO ARM_UP     ;IF SO, CONTINUE
    RETURN      ;IF NOT, BACK TO IDLE

ARM_DN  ;THIS ROUTINE LOWERS THE ARM WHEN THE APPROPRIATE BUTTON IS HELD DOWN
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    INCF POSN3,F    ;INCREMENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN3,F   ;MASK OUT BITS 4 - 7 (ROLLS NUMBER FROM 4 BACK TO 0)
    MOVF POSN3,W    ;LOAD NEW POSITION INTO W BEFORE CALLING LOOKUP TABLE
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA3 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    RLF OUT_DATA3,F     ;ROTATE CONTENTS TO THE LEFT, STORE IN FILE
    RLF OUT_DATA3,F     ;AND REPEAT 4 TIMES TO MOVE VALUES TO FAR LEFT
    RLF OUT_DATA3,F
    RLF OUT_DATA3,F     ;EXAMPLE: 00001001 *ROTATES* --> 10010000
    MOVF OUT_DATA3,W    ;PUT IT BACK IN W
    MOVWF PORTC

    BTFSS PORTB,2   ;SEE IF BUTTON IS STILL PRESSED
    GOTO ARM_DN     ;YES, LOOP
    RETURN          ;NO, IDLE

;=====////////// SECTION 3 (MAIN PROGRAM) \\\\\\\\\\=====
    ;THIS SECTION OF CODE CONTAINS THE MAIN PROGRAM

MAIN_PROGRAM    ;THE ARM SHOULD BEGIN 12 STEPS ABOVE THE COIN PEG
        ;THE PROGRAM WILL LOWER THE ARM 12 STEPS, BRAB THE COIN, RAISE THE ARM, DETERMINE THE COIN TYPE,
        ;ROTATE THE ARM TO THE POINT OF DEPOSIT, DROP THE COIN, AND RETURN TO THE COIN PEG

    MOVLW 0x0C      ;SET "STEPS" TO 12 (1/4 ROTATION)
    MOVWF STEPS
LOWER
    CALL ARM_DN     ;LOWER THE ARM 12 CLICKS.
    DECFSZ STEPS,F
    GOTO LOWER

    CLRF DELAY
    MOVLW 0x38  ;THIS ISN'T ACTUALLY A DELAY...
    MOVWF DELAY ;IT IS THE COUNTER THAT HLEPS THE COMPUTER SEPARATE THE COINS INTO NUMERICAL CATEGORIES.

    CLRF COIN
    CLRF VAR
    CLRF CITER
    INCF CITER,F    ;SET TO 1. MAKE SURE IT DOESN'T JIP US THE EXTRA 256...
GRAB_COIN       ;CLOSE FINGER ON THE COIN.
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    INCF POSN2,F    ;INCREMENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN2,F   ;MASK OUT BITS 4 - 7 (ROLLS NUMBER FROM 4 BACK TO 0)
    MOVF POSN2,W    ;LOAD NEW POSITION INTO W BEFORE CALLING LOOKUP TABLE
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA2 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    MOVWF PORTC

    INCF CSTEPS,F       ;INCREASE THE NUMBER OF STEPS...
    DECFSZ VAR,F        ;...EVERY TIME IT ROLLS OVER FROM 256...
    GOTO SKIP_LINE
    INCF CITER,F        ;...INCREASE THE NUMBER OF ITERATIONS.
SKIP_LINE
    DECFSZ DELAY,F  ;COUNT DOWN FROM 56
    GOTO CONT       ;IF IT REACHES 0, SKIP NEXT PORTION
    INCF COIN,F     ;INCREASE THE COIN COUNTER
    MOVLW 0xC8      ;SUBTRACT 200 FROM "DELAY", SUCH THAT EACH INCREMENT IS 56 APART
    SUBWF DELAY,F   ;INCREMENTS ARE 56, 112, 168, 224, 280, 336, 392, 448, 504, 560, 616, AND 672.
                    ;THE LAST INCREMENT THAT WAS REACHED BEFORE COIN CONTACT IS USED TO DETERMINE COIN TYPE
                    ; QUARTER   = 448   = 8TH INCREMENT
                    ; NICKEL    = 504   = 9TH
                    ; PENNY     = 560   = 10TH
                    ; DIME      = 616   = 11TH
CONT
    BTFSC PORTB,5   ;CHECK FOR COIN CONTACT
    GOTO GRAB_COIN
    ;IF COIN DETECTED, THEN DETERMINE TYPE (ACTUALLY RAISE THE ARM FIRST, SO THAT THE "STEPS" VARIABLE IS FREE FOR USE)

    MOVLW 0x0C      ;SET "STEPS" TO 12 (1/4 ROTATION)
    MOVWF STEPS
RAISE               ;RAISE THE ARM AGAIN
    CALL ARM_UP     ;RAISE THE ARM 12 CLICKS SO IT IS OUT OF THE WAY OF THE COIN PEG...
    DECFSZ STEPS,F
    GOTO RAISE

    ;NOW DETERMINE COIN TYPE AND THE NUMBER OF STEPS REQUIRED TO PLACE IN THE CORRECT CAN.
    MOVLW 0x08  ;PREPARE TO SUBTRACT 8 FROM "COIN" (THIS MOVE THE COIN VALUES FROM 8, 9, 10 & 11 TO 0, 1, 2 & 3)
                ; THE COIN TYPE IS DETERMINED BY NUMBERS 0 - 3
                ; QUARTER = 0, NICKEL = 1, PENNY = 2, DIME = 3
    SUBWF COIN,F    ;SUBTRACTION
    MOVF COIN,W     ;MOVE TO W-REG
    CALL COIN_TYPE  ;LOOK UP INFORMATION. THIS TELL US HOW MANY STEPS TO ROTATE BEFORE DROPPING THE COIN.
    MOVWF STEPS     ;SAFE THE TYPE IN A FILE
    MOVWF BACKUP    ;BACK IT UP FOR RETURN ROTATION

CCWISE      ;TURN TO THE COIN DEPOSIT
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    INCF POSN1,F    ;INCREMENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN1,F   ;MASK OUT BITS 4 - 7 (ROLLS NUMBER FROM 4 BACK TO 0)
    MOVF POSN1,W    ;LOAD NEW POSITION INTO W BEFORE CALLING LOOKUP TABLE
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA1 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    MOVWF PORTA
    CLRF DELAY
DLC
    DECFSZ DELAY,F  ;COUNT DOWN FROM 256 (EVERY TIME THIS IS USED IT WILL BOUNCE BACK TO 256)
    GOTO DLC

    DECFSZ STEPS,F  ;IF STEPS IS NONZERO KEEP GOING
    GOTO CCWISE     ;IF THERE ARE REMAINING STEPS RETURN,
                    ;IF NOT CONTINUE WITH PROGRAM

STEP_COUNT          ;OPEN THE HAND AGAIN
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    INCF POSN2,F    ;INCREMENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN2,F
    MOVF POSN2,W
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA2 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    MOVWF PORTC

    DECFSZ CSTEPS,F ;IF STEPS IS NONZERO KEEP GOING
    GOTO STEP_COUNT
    DECFSZ CITER,F  ;WHEN STEPS HITS ZERO, CHECK TO SEE HOW MANY ITERATIONS
    GOTO STEP_COUNT ;IF THERE ARE REMAINING ITERATIONS RETURN
    ;IF NOT, GO ON.

REZERO
    BTFSS PORTB,4       ;EMERGENCY HALT ROUTINE
    GOTO EM_HALT        ;THIS GOES IN EVERY ROUTINE WITH MOTOR MOVEMENT

    INCF POSN1,F    ;INCREMENT ONE STEP
    MOVLW B'00000011'   ;LOAD MASK INTO W
    ANDWF POSN1,F
    MOVF POSN1,W
    CALL POSITION_LOOKUP
    ANDLW 0x0F      ;FILTER RESULTS FOR 4 BITS
    MOVWF OUT_DATA1 ;PUT THE INFORMATION BACK INTO THE OUTPUT VAR
    MOVWF PORTA
    CLRF DELAY

DLD
    DECFSZ DELAY,F  ;COUNT DOWN FROM 256 (EVERY TIME THIS IS USED IT WILL BOUNCE BACK TO 256)
    GOTO DLD        ;THIS SEGMENT SLOWS DOWN THE ARM ROTATION SEVERELY.

    DECFSZ BACKUP,F ;IF STEPS IS NONZERO KEEP GOING
    GOTO REZERO ;IF THERE ARE REMAINING STEPS RETURN
    ;IF NOT CONTINUE WITH THE PROGRAM
    GOTO IDLE_LOOP  ;FINALLY, DONE WITH THE LOOP!!!

;=====////////// SECTION 4 (OTHER SUB ROUTINES) \\\\\\\\\\=====
    ;THIS SECTION CONTAINS THE HALT, COIN TYPE, AND THE POSITION LOOKUP SUBS. OH, AND THE REVERSE COIN SUB

POSITION_LOOKUP
    ;THIS ROUTINE TAKES A POSITION VALUE W IN AND CONVERTS IT TO
    ;A FOUR BIT VALUE (BITS 0 - 3) TO CONTROL THE MOTOR COILS DIRECTLY
    ANDLW   0x03    ;JUST FOR KICKS, MAKE SURE W IS 0 - 3
    ADDWF   PCL,F   ;ADD W TO THE PROGRAM COUNTER LOW REGISTER
    RETLW B'00001001'
    RETLW B'00001010'
    RETLW B'00000110'
    RETLW B'00000101'
    ;OUTPUTS TO THE MOTOR ARE AS FOLLOWS: 1001, 1010, 0110, 0101, --> LOOP... (OR 9, 10, 6, 5 ETC.)
    RETURN ;SHOULD BE UNREACHABLE

COIN_TYPE
    ANDLW 0x03  ;MAKE SURE W IS 0 - 3
    ADDWF PCL,F ;JUMP TO THE APPROPRIATE NUMBER BASED ON THE COIN TYPE
                ;PROGRAM WILL PUT THE COINS IN PLACE ACCORDING TO VALUE, NOT DIAMETER
    RETLW 0x02  ;QUARTERS, 1 STEP
    RETLW 0x06  ;NICKELS, 5 STEPS
    RETLW 0x08  ;PENNIES, 7 STEPS
    RETLW 0x04  ;DIMES, 3 STEPS

    RETURN ; THE PROGRAM SHOULD NEVER REACH THIS COMMAND ....

EM_HALT
    CLRF POSN1      ;RESET ALL THE VARIABLES TO 0
    CLRF POSN2
    CLRF POSN3
    CLRF OUT_DATA1
    CLRF OUT_DATA2
    CLRF OUT_DATA3
    CLRF STEPS
    CLRF ITER
    CLRF DELAY
    CLRF COIN
    CLRF BACKUP
    CLRF CSTEPS
    CLRF CITER
    CLRF PORTA      ;CUT POWER TO MOTORS
    CLRF PORTC      ;CUT POWER TO MOTORS
    GOTO IDLE_LOOP  ;AND RETURN TO IDLE

END ;THE ALMIGHTY END OF PROGRAM
