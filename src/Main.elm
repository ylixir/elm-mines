--external modules
import Array exposing (Array)
import Browser
import Html exposing (Html, Attribute, button, div, input, span, text)
import Html.Attributes exposing (style, type_, value)
import Html.Events exposing (onClick, onInput, preventDefaultOn)
import Time exposing (Posix, posixToMillis)
import Random exposing (Seed, initialSeed)
import Json.Decode as Json
import Task

--internal modules
import Board
import Board exposing (Board, Content(..), Square, Tile(..))

main =
  Browser.element { init = init, update = update, view = view, subscriptions = (\a->Sub.none) }


-- MODEL

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

type alias Settings =
  { seed: Int
  , width: Int
  , height: Int
  , bombs: Int
  }

beginner: Int -> Settings
beginner s = { seed = s, width = 9, height = 9, bombs = 10}
intermediate: Int -> Settings
intermediate s = { seed = s, width = 16, height = 16, bombs = 40}
expert: Int -> Settings
expert s = { seed = s, width = 16, height = 30, bombs = 99}

newBoard: Settings -> Board
newBoard g =
  let
    empty = Board.empty g.width g.height
  in
    bombBoard g.bombs (initialSeed g.seed) empty

type alias Model =
  { settings: Settings
  , board: Board
  , finished: Bool
  }

init : () -> (Model, Cmd Msg)
init _ =
  let
    g = beginner 0
  in
    ( { settings = g
      , board = newBoard g
      , finished = False
      }
    , Task.perform SeedTime Time.now
    )


-- UPDATE

type Msg
  = Lose Int Int
  | Reset
  | SeedTime Posix
  | Set (Int -> Settings)
  | Sweep Int Int
  | Toggle Int Int
  | Change SettingsMsg

type SettingsMsg
  = Bombs String
  | Height String
  | Seed String
  | TimeRequest
  | Width String

update : Msg -> Model -> (Model, Cmd Msg)
update msg m =
  let g = m.settings in
  case (m.finished, msg) of
    (_,SeedTime t) -> 
      let settings = {g|seed=(posixToMillis t)}
      in ({board=(newBoard settings), finished=False, settings=settings}, Cmd.none)
    (_,Set s) -> ({ m | settings = s g.seed }, Cmd.none)
    (_,Change s) ->
      let (ns,c) = updateSettings s g
      in ({ m | settings = ns } , c)
    (_,Reset) -> ({ m | board = newBoard m.settings, finished = False }, Cmd.none)
    (True,_) -> (m, Cmd.none)
    (_,Sweep x y) -> ({ m | board = Board.sweep x y m.board }, Cmd.none)
    (_,Lose x y) -> ({ m | finished=True, board = Board.sweep x y m.board }, Cmd.none)
    (_,Toggle x y) -> ({ m | board = Board.toggle x y m.board }, Cmd.none)

updateSettings: SettingsMsg -> Settings -> (Settings, Cmd Msg)
updateSettings msg settings =
  let z t = Maybe.withDefault 0 <| String.toInt t
  in case msg of
    Bombs t ->  ({ settings | bombs = z t }, Cmd.none)
    Height t ->  ({ settings | height = z t }, Cmd.none)
    Seed t ->  ({ settings | seed = z t }, Cmd.none)
    Width t ->  ({ settings | width = z t }, Cmd.none)
    TimeRequest -> (settings, Task.perform SeedTime Time.now)

-- EVENTS
onRightClick: msg -> Attribute msg
onRightClick message =
  preventDefaultOn "contextmenu" (Json.map (\m->(m,True)) (Json.succeed message))

-- VIEW

view : Model -> Html Msg
view model =
  let (flags,bombs) = flagBombCount model.board.squares
  in div []
    [ Html.map Change (viewSettings model.settings)
    , div []
      [ button [onClick (Set beginner)] [text "Beginner"]
      , button [onClick (Set intermediate)] [text "Intermediate"]
      , button [onClick (Set expert)] [text "Expert"]
      ]
    , button [ onClick Reset ] [ text <| (String.fromInt flags)++"/"++(String.fromInt bombs)++" Reset" ]
    , viewBoard model.board
    ]

viewSettings: Settings -> Html SettingsMsg
viewSettings g =
  div []
    [ div [] [text "bombs", input [value (String.fromInt g.bombs), onInput Bombs, type_ "number"][]]
    , div [] [text "height", input [value (String.fromInt g.height), onInput Height, type_ "number"][]]
    , div []
      [text "seed"
      , input [value (String.fromInt g.seed), onInput Seed, type_ "number"][]
      , button [onClick TimeRequest][text "Roll"]
      ]
    , div [] [text "width", input [value (String.fromInt g.width), onInput Width, type_ "number"][]]
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
  [ style "background-color" "lightgray"
  , style "border-style" "solid"
  , style "border-color" "gray"
  ]

lost: List (Attribute msg) -> List (Html msg) -> Html msg
lost attrs = base <| attrs++
  [ style "background-color" "red"
  , style "border-style" "solid"
  , style "border-color" "red"
  ]

