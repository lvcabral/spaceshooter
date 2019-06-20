
This is a modified version of the C64 Space Shooter game that comes with the excellent book "Retro Game Dev" by Derek Morris.

Modifications:

* Added three bunkers, similar to those from Space Invaders. The code for the bunkers can be found in gameBunkers.asm;
* In gameFlow.asm, the bunkers are (re)drawn as soon as the fire-button is pressed. Also the text "press fire to start" is moved up a bit;
* Added 8 bunker characters to the custom character set, which are used to build up the bunkers and show damage;
* Disallowing the player to move up/down by setting PlayerYMin to 229 in gamePlayer.asm;
* A small change to gameStars.asm so that stars won't overwrite other characters on the screen and cause "flickering". Now even stars are displayed in between the "press fire to start" text and the top line containing the scores;
* In gameBullets, just before drawing the new bullet position, a check for GAMEBUNKERS_COLLIDED_AA was added. If the bullet has hit a bunker, it will be removed/disabled instead of being drawn to the screen;
* Added macro's LIBSCREEN_GETCHAR_ACC and LIBSCREEN_SETCHAR_ACC to libScreen.asm which are used to fetch the character directly into the Accumulator register;

Enjoy!

Dion