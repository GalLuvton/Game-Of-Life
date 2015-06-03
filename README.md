Game-Of-Life
============
This is Conway's game of life, made in assembly for the intel 80x86 processor.
In order to run this project, type "make" while in the root forder of the project.
<psssst! You can enable printing walls by making with the flag DEBUG=1>
The runnable file is located in /bin/, and is called ass3.

Run the project using the following command- "/ass3 <initFile> <WorldLength> <WorldWidth> <t> <k>".

initFile- the initial state of the board.
WorldLength- the length of a board column.
WorldWidth- the length of a board line.
t- the amount of generations the game will run.
k- printing parameter. the board will print every time (k mod t)=0, and one last time when the game is done.

Some attached examples are:
/ass3 init10x10glider 10 10 <t> <k>
/ass3 init10x10single 10 10 <t> <k>