/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001
// ASSIGNMENT 1
// TITLE: "LED Ant Defender Game"
//
// MICHAEL CHRISTENSEN & ELLIE RICHARDS
//       mc13818            er13825
//
/////////////////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <platform.h>

#define BUTTON_A    14
#define BUTTON_B    13
#define BUTTON_C    11
#define BUTTON_D    7
#define BUTTON_NONE 15

#define MOVE_PERMITTED  0
#define MOVE_FORBIDDEN  1
#define GAME_OVER       2
#define RESTART         3
#define TERMINATE       -1  //something LEDs cant mistake
#define LEVEL_UP        -4  //something thats not a clock position (attacker ant sends as attempt)

#define TOGGLE_PAUSE        -2
#define BUTTON_C_PRESSED    -3  //something thats not a clock value
#define DUMMY   4
#define OK      5
#define DENIED  6

#define RED     -5
#define GREEN   -6
#define SCORE   -7

#define MODE_WAITING 8
#define MODE_PAUSED  9
#define MODE_IN_GAME 10

out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

/////////////////////////////////////////////////////////////////////////////////////////
//
//  Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////

//wraps an integer to keep it within the bounds of the clock positions
int wrap(int pos) {
    if (pos > 11) {
        return 0;
    } else if (pos < 0) {
        return 11;
    } else {
        return pos;
    }
}

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser) {
    unsigned int lightUpPattern;
    int running = 1;
    while (running) {
        fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
        if (lightUpPattern == TERMINATE) {
            running = 0;
        } else {
            p <: lightUpPattern; //send pattern to LEDs
        }
    }
    printf("LED terminated. goodbye\n");
    return 0;
}

//WAIT function
void waitMoment(int duration) {
    timer tmr;
    uint waitTime;
    tmr :> waitTime;
    waitTime += duration;
    tmr when timerafter(waitTime) :> void;
}

//PROCESS TO COORDINATE DISPLAY of LED Ants
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toQuadrant0,
        chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3) {
    unsigned int userAntToDisplay = 11;
    unsigned int attackerAntToDisplay = 5;
    int i, j;
    cledG <: 1; //make ants green
    int running = 1;
    while (running) {
        select {
            case fromUserAnt :> userAntToDisplay:
            break;
            case fromAttackerAnt :> attackerAntToDisplay:
            if(attackerAntToDisplay == TERMINATE) {
                running = 0;    //kill this thread after loop cycle ends

                //change LED colours to red
                cledG <: 0;
                cledR <: 1;

                //turn on all LEDs to flash red before shut down
                toQuadrant0 <: 112;
                toQuadrant1 <: 112;
                toQuadrant2 <: 112;
                toQuadrant3 <: 112;
                waitMoment(10000000);   //pause for effect

                //kill LED threads
                toQuadrant0 <: TERMINATE;
                toQuadrant1 <: TERMINATE;
                toQuadrant2 <: TERMINATE;
                toQuadrant3 <: TERMINATE;
                continue;
            } else if(attackerAntToDisplay == RED) {    //instructed to set LEDs to red
                cledG <: 0;
                cledR <: 1;
                continue;
            } else if(attackerAntToDisplay == GREEN) {  //instructed to set LEDs to green
                cledG <: 1;
                cledR <: 0;
                continue;
            } else if(attackerAntToDisplay == SCORE) {  //instructed to display score
                int score;
                cledG <: 1; //set lights to green
                cledR <: 0;
                fromAttackerAnt :> score;   //read the score from attacker
                if(score > 12) score = 12;  //cant display a score larger than 12
                int quad = (score-1)/3; //the quadrant the score is in
                int rem = score%3;
                int pattern;
                if(rem == 1) pattern = 16;  //light pattern 001
                else if(rem == 2) pattern = 48; //light pattern 011
                else if(rem == 0) pattern = 112; //light pattern 111
                //light up all quads before the one with the score in, and display the
                //correct light pattern on that last one. All others afterwards must be off.
                if(quad == 0) {
                    toQuadrant0 <: pattern;
                    toQuadrant1 <: 0;
                    toQuadrant2 <: 0;
                    toQuadrant3 <: 0;
                } else if(quad == 1) {
                    toQuadrant0 <: 112;
                    toQuadrant1 <: pattern;
                    toQuadrant2 <: 0;
                    toQuadrant3 <: 0;
                } else if(quad == 2) {
                    toQuadrant0 <: 112;
                    toQuadrant1 <: 112;
                    toQuadrant2 <: pattern;
                    toQuadrant3 <: 0;
                } else if(quad == 3) {
                    toQuadrant0 <: 112;
                    toQuadrant1 <: 112;
                    toQuadrant2 <: 112;
                    toQuadrant3 <: pattern;
                }
                continue;
            }
            break;
        }
        j = 16 << (userAntToDisplay % 3);
        i = 16 << (attackerAntToDisplay % 3);
        toQuadrant0 <: (j*(userAntToDisplay/3==0)) + (i*(attackerAntToDisplay/3==0));
        toQuadrant1 <: (j*(userAntToDisplay/3==1)) + (i*(attackerAntToDisplay/3==1));
        toQuadrant2 <: (j*(userAntToDisplay/3==2)) + (i*(attackerAntToDisplay/3==2));
        toQuadrant3 <: (j*(userAntToDisplay/3==3)) + (i*(attackerAntToDisplay/3==3));
    }
    printf("visualiser terminated. goodbye\n");
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, out port speaker, unsigned long millis) {
    timer tmr;
    int t, isOn = 1;
    unsigned long total_ticks = millis * 100000;    //100000 timer ticks = 1ms
    millis = total_ticks/wavelength;
    tmr :> t;
    for (int i = 0; i < millis; i++) {
        isOn = !isOn;
        t += wavelength;
        tmr when timerafter(t) :> void;
        speaker <: isOn;
    }
}

/*
 *  Methods to play each sound used in the game.
 *  NOTES:
 *  C4  793704
 *  Eb4 667429
 *  G4  529718
 *  C5  396822
 *  E5  314966
 *  G5  264889
 *  C6  198441
 */
void playGameOverSound(out port speaker) {
    playSound(396822, speaker, 100);
    playSound(529718, speaker, 100);
    playSound(667429, speaker, 100);
    playSound(793704, speaker, 200);
}
void playUserMoveSound(out port speaker) {
    playSound(2000000, speaker, 50);
}
void playLevelUpSound(out port speaker) {
    playSound(396822, speaker, 100);
    playSound(264889, speaker, 100);
    playSound(198441, speaker, 200);
}
void playTerminateSound(out port speaker) {
    playSound(198441, speaker, 300);
    playSound(264889, speaker, 300);
    playSound(314966, speaker, 300);
    playSound(396822, speaker, 600);
}
void playPauseSound(out port speaker) {
    playSound(198441, speaker, 100);
}
void playRestartSound(out port speaker) {
    playSound(198441, speaker, 100);
    playSound(396822, speaker, 100);
}

//READ BUTTONS and send to userAnt
void buttonListener(in port b, chanend toUserAnt) {
    int r;
    int running = 1;
    int response;
    //var to prevent buttons B and C from rapid firing when held down
    int isReleased = 1;

    //continuously read button state and send them to user (even if nothing is pressed)
    //(This prevents the user from hanging up until a button is actually pressed)
    while (running) {
        b :> r; //read button

        //if no buttons are pressed then all are released so reset flag
        if(r == BUTTON_NONE) {
            isReleased = 1;
        }

        if(r == BUTTON_C || r == BUTTON_B) {
            if(isReleased == 0) {   //this is not the first time they were pressed
                r = BUTTON_NONE;    //set r to none to prevent rapid fire of buttons
            }
            isReleased = 0; //they were pressed so released is now false
        }
        toUserAnt <: r; // send button pattern to userAnt
        toUserAnt :> response;

        if(response == TERMINATE) {
            running = 0;
        }

        waitMoment(10000000); //pause to let user release button
    }
    printf("Buttons terminated. Goodbye!\n");
}

//DEFENDER PROCESS... The defender is controlled by this process userAnt,
//                    which has channels to a buttonListener, visualiser and controller
void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController) {
    unsigned int userAntPosition = 11; //the current defender position
    int buttonInput; //the input pattern from the buttonListener
    unsigned int attemptedAntPosition = 11; //the next attempted defender position after considering button
    int controllerResponse; //the verdict of the controller as to whether move is allowed
    int running = 1; //flag to know when to terminate this thread
    int paused = 0; //flag to know when to pause this thread
    toVisualiser <: userAntPosition; //show initial position

    while (running) {
        fromButtons :> buttonInput;
        fromButtons <: DUMMY;   //send anything back to buttons to let them know it's ok to proceed
        if (buttonInput == BUTTON_A)
            attemptedAntPosition = wrap(userAntPosition + 1); //user ant moves anti-clockwise
        if (buttonInput == BUTTON_D)
            attemptedAntPosition = wrap(userAntPosition - 1); //user ant moves clockwise
        if (buttonInput == BUTTON_C)
            //set position to a code that signals C was pressed: controller
            //decides whether this means terminate, restart, etc.
            attemptedAntPosition = BUTTON_C_PRESSED;
        if (buttonInput == BUTTON_B) { //pause pressed
            paused = 1; //set pause flag
            toController <: TOGGLE_PAUSE; //tell controller to pause
            toController :> controllerResponse; //read controller's repsonse to pause request
            if(controllerResponse == OK) {  //OK means we are in game mode so pause is allowed
                while (paused) { //loop continuously until unpaused
                    waitMoment(10000000); //delay to allow button release
                    fromButtons :> buttonInput; //read button input
                    fromButtons <: DUMMY;   //send dummy to buttons so they can proceed
                    if (buttonInput == BUTTON_B) { //B is pressed to unpause
                        paused = 0; //reset pause flag
                        toController <: TOGGLE_PAUSE;   //tell controller to unpause
                        toController :> controllerResponse; //read (but dont use) controller response so it can proceed
                    } else if (buttonInput == BUTTON_C) {
                        //tell controller C was pressed, it'll figure out what to do.
                        //In this case it means terminate.
                        toController <: BUTTON_C_PRESSED;
                        toController :> controllerResponse;
                        paused = 0; //break out of pause
                    }
                }
            }
        }
        toController <: attemptedAntPosition; //ask controller if attempted move is permissible/send it a special code
        toController :> controllerResponse; //read controller response
        if (controllerResponse == MOVE_PERMITTED) { //if move is permitted then update:
            userAntPosition = attemptedAntPosition; //ant's position is updated
            toVisualiser <: userAntPosition; //new position is sent to the visualiser to be shown
        } else if (controllerResponse == MOVE_FORBIDDEN) { //move forbidden
            //do nothing
        } else if (controllerResponse == GAME_OVER) { //gameOver
            waitMoment(100000000);  //delay so that final pos is displayed to user

            toController :> controllerResponse; //wait until controller says its ok to continue (score has been dealt with)

            //reset user position and update visually
            userAntPosition = 11;
            attemptedAntPosition = userAntPosition;
            toVisualiser <: userAntPosition;
        } else if (controllerResponse == RESTART) { //restart
            //reset same as above, but no delay
            userAntPosition = 11;
            attemptedAntPosition = userAntPosition;
            toVisualiser <: userAntPosition;
        } else if (controllerResponse == LEVEL_UP) { //levelUp
            //pass
        } else if (controllerResponse == TERMINATE) { //terminate thread
            fromButtons :> buttonInput; //read from buttons so we can talk to him
            fromButtons <: TERMINATE;   //tell buttons to terminate
            running = 0;
        }
        waitMoment(1000000);
    }
printf("User terminated. Goodbye!\n");
}

//returns 1 (0 otherwise) if moveCounter is divisible by 31, 37 or 47 to give a
//pseudorandom direction switch. Used by attackerAnt.
int shouldSwitchDirectionRandom(int moveCounter) {
    if(moveCounter % 31 == 0 || moveCounter % 37 == 0 || moveCounter % 47 == 0) {
        return 1;
    } else {
        return 0;
    }
}

//ATTACKER PROCESS... The attacker is controlled by this process attackerAnt,
//                    which has channels to the visualiser and controller
void attackerAnt(chanend toVisualiser, chanend toController) {
    int currentLevel = 1; //stores the current level
    int moveCounter = 0; //moves of attacker so far
    int movesRequired = 10; //moves required to make before reaching next level
    unsigned int attackerAntPosition = 5; //the current attacker position
    unsigned int attemptedAntPosition; //the next attempted  position after considering move direction
    int currentDirection = 1; //the current direction the attacker is moving
    int controllerResponse = 0; //the verdict of the controller if move is allowed
    toVisualiser <: attackerAntPosition; //show initial position
    int running = 1; //flag to know when to terminate this thread
    long waitTime = 40000000;   //initial (level 0) time to wait between ant moves

    while (running) {
        //check if random change of direction is needed.
        if (shouldSwitchDirectionRandom(moveCounter)) {
            currentDirection *= -1; //reverse attacker direction
        }
        //if a sufficient number of moves have been made then level up
        if(moveCounter >= movesRequired) {
            attemptedAntPosition = LEVEL_UP;
        } else {    //otherwise continue as normal
            //update attempt to next position in the correct direction
            attemptedAntPosition = wrap(attackerAntPosition + currentDirection);
        }

        toController <: attemptedAntPosition; //send the attempt to the controller to process
        toController :> controllerResponse; //read the controller's response
        if (controllerResponse == MOVE_PERMITTED) { //move was permitted
            moveCounter++;
            attackerAntPosition = attemptedAntPosition; //update new position
            toVisualiser <: attackerAntPosition; //inform visualiser of new position
        } else if (controllerResponse == MOVE_FORBIDDEN) { //move was forbidden by controller, so change direction
            //check if direction would already have been switched, if not then it's safe to switch it.
            if(!shouldSwitchDirectionRandom(moveCounter)) {
                currentDirection *= -1;
            }
        } else if (controllerResponse == GAME_OVER) { //game over
            //reset game vars
            toVisualiser <: attemptedAntPosition; //update visualiser of winnning pos
            toVisualiser <: RED;  //tell visualiser to set LEDs to red to show end pos
            waitMoment(100000000);  //delay slightly to show this pos to user

            toVisualiser <: SCORE;
            toVisualiser <: currentLevel;
            waitMoment(200000000);

            toController <: OK; //tell controller score has been processed, OK to continue

            currentLevel = 1;
            moveCounter = 0;
            waitTime = 40000000;
            attackerAntPosition = 5;
            currentDirection = 1;
            controllerResponse = 0;
            toVisualiser <: GREEN;  //tell visualiser to reset LED colour
            toVisualiser <: attackerAntPosition; //update visualiser of new pos
        } else if (controllerResponse == RESTART) { //restart
            //same as above but dont show red final positions
            currentLevel = 1;
            moveCounter = 0;
            waitTime = 40000000;
            attackerAntPosition = 5;
            currentDirection = 1;
            controllerResponse = 0;
            toVisualiser <: GREEN;  //tell visualiser to reset LED colour
            toVisualiser <: attackerAntPosition; //update visualiser of new pos
        } else if (controllerResponse == LEVEL_UP) { //level up
            //update game vars
            moveCounter = 0;
            movesRequired += 10;
            currentLevel++;
            printf("LEVEL UP: %d\n", currentLevel);
            waitTime *= 0.7;    //speed up a bit
        } else if (controllerResponse == TERMINATE) { //terminate thread
            toVisualiser <: TERMINATE; //pass on the termination request
            running = 0;
        }
        waitMoment(waitTime);
    }
    printf("Attacker terminated. Goodbye!\n");
}

//COLLISION DETECTOR... the controller process responds to �permission-to-move� requests
//                      from attackerAnt and userAnt. The process also checks if an attackerAnt
//                      has moved to LED positions I, XII and XI.
void controller(chanend fromAttacker, chanend fromUser, out port spkr) {
    unsigned int lastReportedUserAntPosition = 11; //position last reported by userAnt
    unsigned int lastReportedAttackerAntPosition = 5; //position last reported by attackerAnt
    unsigned int attempt = 11; //keeps track of user and attacker attempted positions
    int running = 1; //flag to know when to terminate this thread
    int paused = 0; //flag to know when to pause this thread
    int mode = MODE_WAITING; //keeps track of the state of the thread (initially waiting for game to start)

    while (running) {
        if (mode == MODE_WAITING) { //waiting to start
            //loop continuously until the user moves
            while (attempt == 11 || attempt == TOGGLE_PAUSE) { //keep listening for only buttons A or D
                fromUser :> attempt; //start game when user moves
                if (attempt == BUTTON_C_PRESSED) { //check if user has signalled thread termination
                    playTerminateSound(spkr);  //play sound to indicate termination
                    fromUser <: TERMINATE; //if so, tell user to shut down
                    fromAttacker :> attempt; //wait until attacker moves so you can talk to him
                    fromAttacker <: TERMINATE; //tell him to shut down
                    running = 0; //shut down this thread
                } else if(attempt == TOGGLE_PAUSE) {    //user requests to pause
                    fromUser <: DENIED; //tell user this is not allowed in waiting state
                } else { //user has made a normal kind of move
                    fromUser <: MOVE_FORBIDDEN; //forbid this first move
                }
            }
            //reset game vars:
            lastReportedUserAntPosition = attempt;
            lastReportedAttackerAntPosition = 5;
            attempt = 0;
            //start in game mode
            mode = MODE_IN_GAME;
        } else if (mode == MODE_PAUSED) { //paused
            paused = 1; //set paused flag
            playPauseSound(spkr);   //play sound to indicate pause
            int userResponse;
            //loop while paused
            while(paused) {
                fromUser :> userResponse;   //listen to user
                if(userResponse == TOGGLE_PAUSE) {  //user signals unpause
                    paused = 0; //reset pause flag
                    playPauseSound(spkr);   //play sound to indicate unpause
                    fromUser <: DUMMY;  //give user a response so he continues on his way
                    mode = MODE_IN_GAME;
                } else if(userResponse == BUTTON_C_PRESSED) {   //user signals restart
                    fromUser <: DUMMY;  //give user a response so he continues on his way
                    fromUser :> attempt;    //read his "attempted move"
                    fromUser <: RESTART;  //reply and tell him to restart
                    fromAttacker :> attempt;    //also tell the attacker
                    fromAttacker <: RESTART;
                    playRestartSound(spkr); //play sound to indicate restart
                    mode = MODE_WAITING;    //go back to initial waiting state
                    attempt = 11;   //reset attempt to user starting position
                    paused = 0;
                }
            }
        } else if (mode == MODE_IN_GAME) { //in game
            select {
                case fromAttacker :> attempt:
                //check collision between attempted attacker move and user pos
                if(attempt != lastReportedUserAntPosition) {
                    //check if the attacker has reached a game-winning position
                    if(attempt == 0 || attempt == 11 || attempt == 10) {
                        printf("GAME OVER!\n");
                        fromUser :> attempt; //read users move attempt
                        if(attempt == TOGGLE_PAUSE) { //user has actually already paused
                            fromUser <: DENIED; //tell user they can't pause now, too late.
                            fromUser :> attempt;
                            fromUser <: GAME_OVER;  //instead tell them the game is over
                            fromAttacker <: GAME_OVER;
                            playGameOverSound(spkr);    //play sound to indicate game over
                            attempt = 11;
                            mode = MODE_WAITING;
                        } else {
                            fromUser <: GAME_OVER; //tell them games over
                            fromAttacker <: GAME_OVER; //..and the attacker too
                            playGameOverSound(spkr);    //play sound to indicate game over
                            fromAttacker :> attempt;    //wait until attacker says its ok to continue (score has been dealt with)
                            fromUser <: OK;     //once this has been done, tell user to continue.

                            attempt = 11; //reset the attempt for user as user inital position
                            mode = MODE_WAITING;
                        }
                    } else if(attempt == LEVEL_UP) {
                        fromAttacker <: LEVEL_UP;
                        playLevelUpSound(spkr);  //play sound to indicate level up
                    } else {
                        fromAttacker <: MOVE_PERMITTED; //permit move
                        lastReportedAttackerAntPosition = attempt; //update new pos
                    }
                } else {
                    fromAttacker <: MOVE_FORBIDDEN; //forbid move
                }
                break;

                case fromUser :> attempt:
                //check collision between attempted user move and attacker pos
                if(attempt != lastReportedAttackerAntPosition &&
                        attempt != BUTTON_C_PRESSED && attempt != TOGGLE_PAUSE) {
                    fromUser <: MOVE_PERMITTED; //permit move
                    //if the user has actually changed position then play click sound
                    if(attempt != lastReportedUserAntPosition) {
                        playUserMoveSound(spkr);
                    }
                    lastReportedUserAntPosition = attempt; //update new pos
                } else if(attempt == BUTTON_C_PRESSED) {    //user wants to restart
                    fromUser <: RESTART;
                    fromAttacker :> attempt; //wait until attacker moves so you can talk to him
                    fromAttacker <: RESTART;
                    playRestartSound(spkr); //play sound to indicate restart
                    mode = MODE_WAITING;
                    attempt = 11;
                } else if(attempt == TOGGLE_PAUSE) { //user instructs to pause
                    fromUser <: OK; //tell them pausing is OK
                    mode = MODE_PAUSED;
                } else {
                    fromUser <: MOVE_FORBIDDEN; //forbid move
                }
                break;
            }
        }
    }
    printf("Controller terminated. Goodbye!\n");
}

//MAIN PROCESS defining channels, orchestrating and starting the processes
int main(void) {
    chan buttonsToUserAnt, //channel from buttonListener to userAnt
            userAntToVisualiser, //channel from userAnt to Visualiser
            attackerAntToVisualiser, //channel from attackerAnt to Visualiser
            attackerAntToController, //channel from attackerAnt to Controller
            userAntToController; //channel from userAnt to Controller
    chan quadrant0, quadrant1, quadrant2, quadrant3; //helper channels for LED visualisation

    par {
        //PROCESSES FOR YOU TO EXPAND
        on stdcore[1]:
        userAnt(buttonsToUserAnt, userAntToVisualiser, userAntToController);
        on stdcore[2]:
        attackerAnt(attackerAntToVisualiser, attackerAntToController);
        on stdcore[0]:
        controller(attackerAntToController, userAntToController, speaker);

        //HELPER PROCESSES
        on stdcore[0]:
        buttonListener(buttons, buttonsToUserAnt);
        on stdcore[0]:
        visualiser(userAntToVisualiser, attackerAntToVisualiser, quadrant0, quadrant1,
                quadrant2, quadrant3);
        on stdcore[0]:
        showLED(cled0, quadrant0);
        on stdcore[1]:
        showLED(cled1, quadrant1);
        on stdcore[2]:
        showLED(cled2, quadrant2);
        on stdcore[3]:
        showLED(cled3, quadrant3);
    }
    return 0;
}


