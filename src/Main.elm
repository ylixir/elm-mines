--external modules
import Array exposing (Array)
import Browser
import Html exposing (Html, Attribute, button, div, input, span, text)
import Html.Attributes exposing (style, type_, value)
import Html.Events exposing (onClick, onInput, preventDefaultOn)
import Random exposing (Seed, initialSeed)
import Json.Decode as Json

--internal modules
import Board
import Board exposing (Board, Content(..), Square, Tile(..))

main =
  Browser.sandbox { init = init, update = update, view = view }


-- MODEL

type alias Game =
  { seed: Int
  , width: Int
  , height: Int
  , bombs: Int
  }

bombBoard: Int -> Seed -> Board -> Board
bombBoard bombs seed board =
  let
    (x, tmpSeed) = Random.step (Random.int 0 <| Board.maxX board) seed
    (y, nextSeed) = Random.step (Random.int 0 <| Board.maxY board) tmpSeed
  in
    if 0 == bombs then
      board
    else case Board.square x y board of 
      (_, Bomb) -> bombBoard bombs nextSeed board
      (_, _) -> bombBoard (bombs - 1) nextSeed (Board.bomb x y board)

newBoard: Game -> Board
newBoard g =
  let
    empty = Board.empty g.width g.height
  in
    bombBoard g.bombs (initialSeed g.seed) empty

type alias Model =
  { game: Game
  , board: Board
  , finished: Bool
  }

init : Model
init =
  let
    g =
      { seed = 0
      , width = 10
      , height = 10
      , bombs = 3
      }
  in
  { game = g
  , board = newBoard g
  , finished = False
  }


-- UPDATE

type Msg
  = Lose Int Int
  | Sweep Int Int
  | Toggle Int Int
  | Reset
  | SeedChange String

update : Msg -> Model -> Model
update msg m =
  let g = m.game in
  case (m.finished, msg) of
    (_,SeedChange s) -> { m | game = { g | seed = Maybe.withDefault 0 <| String.toInt s }}
    (_,Reset) -> { m | board = newBoard m.game, finished = False }
    (True,_) -> m
    (_,Sweep x y) -> { m | board = Board.sweep x y m.board }
    (_,Lose x y) -> { m | finished=True, board = Board.sweep x y m.board }
    (_,Toggle x y) -> { m | board = Board.toggle x y m.board }


-- EVENTS
onRightClick: msg -> Attribute msg
onRightClick message =
  preventDefaultOn "contextmenu" (Json.map (\m->(m,True)) (Json.succeed message))

-- VIEW

view : Model -> Html Msg
view model =
  let (flags,bombs) = flagBombCount model.board.squares
  in div []
    [ viewSettings model.game
    , button [ onClick Reset ] [ text <| (String.fromInt flags)++"/"++(String.fromInt bombs) ]
    , viewBoard model.board
    ]

viewSettings: Game -> Html Msg
viewSettings g =
  div []
    [ div [] [text "seed", input [value (String.fromInt g.seed), onInput SeedChange, type_ "number"][]]
    ]
viewBoard: Board -> Html Msg
viewBoard b =
  List.range 0 (Board.maxY b)
  |> List.map (viewRow b)
  |> div []

viewRow : Board -> Int -> Html Msg
viewRow b y =
  List.range 0 (Board.maxX b)
  |> List.map (viewSquare b y)
  |> row []

viewSquare: Board -> Int -> Int -> Html Msg
viewSquare b y x =
  case Board.square x y b of
    (Plain,Bomb) -> unswept [ onRightClick (Toggle x y), onClick (Lose x y) ] []
    (Plain,_) -> unswept [ onRightClick (Toggle x y), onClick (Sweep x y) ] []
    (Flagged,_) -> unswept [ onRightClick (Toggle x y) ] [text "!" ]
    (Question,_) -> unswept [ onRightClick (Toggle x y) ] [text "?" ]
    (Exposed,Neighbor 0) -> swept [] []
    (Exposed,Neighbor n) -> swept [] [text <| String.fromInt n]
    (Exposed,Bomb) -> lost [] [text "B"]

flagBombCount: (Array Square) -> (Int,Int)
flagBombCount a =
  let
    counter: Square -> (Int, Int) -> (Int, Int)
    counter s (f,b) =
      case s of
        (Flagged,Bomb)-> (f+1,b+1)
        (_,Bomb) -> (f,b+1)
        (Flagged,_) -> (f+1,b)
        (_,_) -> (f,b)
  in Array.foldl counter (0,0) a

-- STYLING

row: List (Attribute msg) -> List (Html msg) -> Html msg
row = div

base: List (Attribute msg) -> List (Html msg) -> Html msg
base attrs = span <| attrs++
  [ style "display" "inline-block"
  , style "width" "20px"
  , style "height" "20px"
  , style "border-width" "3px"
  , style "text-align" "center"
  , style "vertical-align" "top"
  , style "font-weight" "bold"
  ]

unswept: List (Attribute msg) -> List (Html msg) -> Html msg
unswept attrs = base <| attrs++
  [ style "background-color" "gray"
  , style "border-style" "outset"
  ]

swept: List (Attribute msg) -> List (Html msg) -> Html msg
swept attrs = base <| attrs++
  [ style "background-color" "gray"
  , style "border-style" "solid"
  , style "border-color" "gray"
  ]

lost: List (Attribute msg) -> List (Html msg) -> Html msg
lost attrs = base <| attrs++
  [ style "background-color" "red"
  , style "border-style" "solid"
  , style "border-color" "red"
  ]

