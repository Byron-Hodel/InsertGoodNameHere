This repository is the result of a Project from my CIS 375 course at the University of Michigan-Dearborn.

Since the assignment allows for me to choose what to impliment, I chose to impliment some basic
ray marched height map terrain, similar to the voxelspace algorithm used in Comanche: Maximum Overkill.
Just to clearify, this is not an implimentation of the voxelspace algorithm.

For now, the goal of the project is to impliement the following features.

 * Height Map Rendering Using raymarching on the GPU using webgl.
 * Procedural Height Map Generation.
 * Camera Movement through time and space.
 * A Ui which the user can interact with.

I plan to continue this after the project is due, so these requirements are bound to be expanded upon
or changed.

Future Ideas for the project include:

 * ability to traverse the scene (on the ground)
 * level of detail.
 * terrain modification. Something like the ability to make holes and tunnles
 * Foliage, (like trees and maybe grass)
 * Maybe expand to paltforms other than the browser

How to Build:
 1. Ensure Odin-lang is installed on your system
 2. navigate to project root directory
 3. run build.sh
 4. wait.

How to Run:
 1. open a local server on whatever port you want, wont work without server
 2. open local server in browser.
