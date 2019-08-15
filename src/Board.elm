module Board exposing
  ( Board
  , Content(..)
  , Square
  , Tile(..)
  , bomb
  , empty
  , maxX
  , maxY
  , square
  , sweep
  , toggle
  )

import Array exposing (Array)

type Tile
  = Plain
  | Exposed
  | Flagged
  | Question
type Content
  = Bomb
  | Neighbor Int

type alias Square = (Tile ,Content)

-- we should do an opaque type here, but i'm just going to keep things simple
type alias Board =
  { width: Int
  , height: Int
  , squares: Array Square
  }

bomb: Int -> Int -> Board -> Board
bomb x y b = 
  let
    n = realIndex x y b
  in
    case (Maybe.withDefault (Exposed, Bomb) <| Array.get n b.squares) of
      (t,Bomb) -> b
      (t,c) -> { b| squares = (b.squares
        |> Array.set n (t, Bomb)
        |> increment (n+b.width-1)
        |> increment (n+b.width)
        |> increment (n+b.width+1)
        |> increment (n+1)
        |> increment (n-1)
        |> increment (n-b.width-1)
        |> increment (n-b.width)
        |> increment (n-b.width+1)
        )} 


empty: Int -> Int -> Board
empty w h =
  { width = w+2
  , height = h+2
  , squares = Array.initialize ((w+2)*(h+2)) (\i -> (Plain, Neighbor 0))
  }

maxX: Board -> Int
maxX b = b.width - 3

maxY: Board -> Int
maxY b = (Array.length b.squares) // b.width - 3

square: Int -> Int -> Board -> Square
square x y b =
  let n = realIndex x y b
  in Maybe.withDefault (Exposed, Bomb) <| Array.get n b.squares

sweep: Int -> Int -> Board -> Board
sweep x y b =
  let
    n = realIndex x y b
    (_,c) = Maybe.withDefault (Exposed, Bomb) <| Array.get n b.squares
  in
    { b| squares = Array.set n (Exposed, c) b.squares } 


toggle: Int -> Int -> Board -> Board
toggle x y b =
  let
    n = realIndex x y b
    s = case (Maybe.withDefault (Exposed, Bomb) <| Array.get n b.squares) of
      (Plain,c) -> (Flagged,c)
      (Flagged,c) -> (Question,c)
      (Question,c) -> (Plain,c)
      (Exposed,c) -> (Exposed,c)
  in
    { b| squares = Array.set n s b.squares } 


-- not exposed

--note we have no rails here to avoid index overflows
realIndex: Int -> Int -> Board -> Int
realIndex x y b = b.width + (y*b.width) + 1 + x

increment: Int -> Array Square -> Array Square
increment n b = case (Maybe.withDefault (Exposed, Bomb) <| Array.get n b) of
  (t,Bomb) -> b
  (t,Neighbor x) -> Array.set n (t, Neighbor (x+1)) b


