# Space Shooter with Multiplexer
Mod of the Space Shooter example from RetroGameDev book with integrated Sprite Multiplexer

![Screenshot](https://github.com/lvcabral/spaceshooter/blob/master/screenshot.png)

## Introduction

During the development of the game [Retaliate 64](https://github.com/lvcabral/retaliate64/) I needed to integrate a sprite multiplexer to make it more challenging with several enemies on screen, I spent a few weeks looking for alternatives and ended up using the one developed by [Lasse Öörni (Cadaver)](https://cadaver.github.io), that is really stable and structured in a way I could easily re-use the macros from the libraries created by Derek Morris on his book [RetroGameDev: C64 Edition](https://www.retrogamedev.com/c64edition).  I mentioned that in book forum and [John Dale (OldSkoolCoder)](https://www.youtube.com/channel/UCtWfJHX6gZSOizZDbwmOrdg) requested me to show how I did it. As the new Retaliate 64 (Community Edition) is still a few months to be published, I decided to make this small mod of the original Space Shooter from the book (upon Dion Olsthoorn's bunkers version) to demonstrate it. 

## How To Adapt the Space Shooter

I made the initial commit of this repo with the unchanged version, so you can analyze the following 2 commits to fully understand the changes I made. I will give here only an overview of the modification over the Space Shooter code, I will not explain how the Multiplexer work, for that please refer to [Cadaver's rant](https://cadaver.github.io/rants/sprite.html).

### First Commit - Integrating the Multiplexer

1. Replaced **libSprites.asm** with the new version with multiplexer routines and changed macros
2. Updated **gameMemory.asm** to add some constants used by the multiplexer
3. Removed all lines with macro LIBSPRITE_ENABLE_AV from **gameAliens.asm** and **gamePlayer.asm**
4. Updated **gameMain.asm** with the following changes:

![gameMain.asm](https://github.com/lvcabral/spaceshooter/blob/master/code1.png)


### Second Commit - Increasing the Number of Aliens

1. Change **gameAliens.asm** constant AlienMax value from 7 to 14
2. For every aliens* array add 7 more bytes, as shown below:

![gameMain.asm](https://github.com/lvcabral/spaceshooter/blob/master/code2.png)

## Project License

Copyright (C) Marcelo Lv Cabral. All rights reserved.

Licensed under [MIT](https://github.com/lvcabral/retaliate64/blob/master/LICENSE) License.

