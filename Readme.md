# Data
We will be keeping track of basically two things, the parameters for the next
game, and the current game

#The next game board
This is basically just the parameters needed to generate a new game
1. a random seed
1. gameWidth
1. gameHeight
1. bombCount

#The current game board
the board will actually be 2 wider and 2 longer than the game size.
this allows us to be lazy about literal edge cases.
we will define the large area to be the board size and the small area to be the
game size
1. boardWidth
1. boardHeight
1. the board, an array of elements containing either a bomb, or a count of
   neighboring bombs
1. the tiles, an array of elements containing: plain, exposed, flagged, question

