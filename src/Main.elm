--external modules


module Main exposing (Model, Msg(..), Settings, SettingsMsg(..), base, beginner, blank, bombBoard, expert, flagBombCount, init, intermediate, lost, main, newBoard, onRightClick, row, swept, unswept, update, updateSettings, view, viewBoard, viewRow, viewSettings, viewSquare)

--internal modules

import Array exposing (Array)
import Board exposing (Board, Content(..), Square, Tile(..))
import Browser
import Html exposing (Attribute, Html, button, div, input, span, text)
import Html.Attributes exposing (style, type_, value)
import Html.Events exposing (onClick, onInput, preventDefaultOn)
import Json.Decode as Json
import Random exposing (Seed, initialSeed)
import Task
import Time exposing (Posix, posixToMillis)


main =
    Browser.element { init = init, update = update, view = view, subscriptions = \a -> Sub.none }



-- MODEL


bombBoard : Int -> Seed -> Board -> Board
bombBoard bombs seed board =
    let
        ( x, tmpSeed ) =
            Random.step (Random.int 0 <| Board.maxX board) seed

        ( y, nextSeed ) =
            Random.step (Random.int 0 <| Board.maxY board) tmpSeed
    in
    if 0 == bombs then
        board

    else
        case Board.square x y board of
            ( _, Bomb ) ->
                bombBoard bombs nextSeed board

            ( _, _ ) ->
                bombBoard (bombs - 1) nextSeed (Board.bomb x y board)


flagBombCount : Array Square -> ( Int, Int )
flagBombCount a =
    let
        counter : Square -> ( Int, Int ) -> ( Int, Int )
        counter s ( f, b ) =
            case s of
                ( Flagged, Bomb ) ->
                    ( f + 1, b + 1 )

                ( _, Bomb ) ->
                    ( f, b + 1 )

                ( Flagged, _ ) ->
                    ( f + 1, b )

                ( _, _ ) ->
                    ( f, b )
    in
    Array.foldl counter ( 0, 0 ) a


type alias Settings =
    { seed : Int
    , width : Int
    , height : Int
    , bombs : Int
    }


beginner : Int -> Settings
beginner s =
    { seed = s, width = 9, height = 9, bombs = 10 }


intermediate : Int -> Settings
intermediate s =
    { seed = s, width = 16, height = 16, bombs = 40 }


expert : Int -> Settings
expert s =
    { seed = s, width = 30, height = 16, bombs = 99 }


newBoard : Settings -> Board
newBoard g =
    let
        empty =
            Board.empty g.width g.height
    in
    bombBoard g.bombs (initialSeed g.seed) empty


type alias Model =
    { settings : Settings
    , board : Board
    , finished : Bool
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        g =
            beginner 0
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    let
        g =
            m.settings
    in
    case ( m.finished, msg ) of
        ( _, SeedTime t ) ->
            let
                settings =
                    { g | seed = posixToMillis t }
            in
            ( { board = newBoard settings, finished = False, settings = settings }, Cmd.none )

        ( _, Set s ) ->
            let
                settings =
                    s g.seed
            in
            ( { board = newBoard settings, finished = False, settings = settings }, Cmd.none )

        ( _, Change s ) ->
            let
                ( ns, c ) =
                    updateSettings s g
            in
            ( { m | settings = ns }, c )

        ( _, Reset ) ->
            let
                invalid =
                    m.settings.width * m.settings.height < m.settings.bombs
            in
            if invalid then
                ( m, Cmd.none )

            else
                ( { m | board = newBoard m.settings, finished = False }, Cmd.none )

        ( True, _ ) ->
            ( m, Cmd.none )

        ( _, Sweep x y ) ->
            ( { m | board = Board.sweep x y m.board }, Cmd.none )

        ( _, Lose x y ) ->
            ( { m | finished = True, board = Board.sweep x y m.board }, Cmd.none )

        ( _, Toggle x y ) ->
            ( { m | board = Board.toggle x y m.board }, Cmd.none )


updateSettings : SettingsMsg -> Settings -> ( Settings, Cmd Msg )
updateSettings msg settings =
    let
        z t =
            if "" == t then
                0

            else
                Maybe.withDefault -1 <| String.toInt t
    in
    case msg of
        Bombs t ->
            if z t < 0 then
                ( settings, Cmd.none )

            else
                ( { settings | bombs = z t }, Cmd.none )

        Height t ->
            if z t < 0 then
                ( settings, Cmd.none )

            else
                ( { settings | height = z t }, Cmd.none )

        Seed t ->
            ( { settings | seed = z t }, Cmd.none )

        Width t ->
            if z t < 0 then
                ( settings, Cmd.none )

            else
                ( { settings | width = z t }, Cmd.none )

        TimeRequest ->
            ( settings, Task.perform SeedTime Time.now )



-- EVENTS


onRightClick : msg -> Attribute msg
onRightClick message =
    preventDefaultOn "contextmenu" (Json.map (\m -> ( m, True )) (Json.succeed message))



-- VIEW


view : Model -> Html Msg
view model =
    let
        ( flags, bombs ) =
            flagBombCount model.board.squares
    in
    div []
        [ Html.map Change (viewSettings model.settings)
        , div []
            [ button [ onClick (Set beginner) ] [ text "Beginner" ]
            , button [ onClick (Set intermediate) ] [ text "Intermediate" ]
            , button [ onClick (Set expert) ] [ text "Expert" ]
            ]
        , button [ onClick Reset ] [ text <| String.fromInt flags ++ "/" ++ String.fromInt bombs ++ " Reset" ]
        , viewBoard model.board
        ]


viewSettings : Settings -> Html SettingsMsg
viewSettings g =
    div []
        [ div [] [ text "bombs", input [ value (String.fromInt g.bombs), onInput Bombs, type_ "number" ] [] ]
        , div [] [ text "height", input [ value (String.fromInt g.height), onInput Height, type_ "number" ] [] ]
        , div []
            [ text "seed"
            , input [ value (String.fromInt g.seed), onInput Seed, type_ "number" ] []
            , button [ onClick TimeRequest ] [ text "🎲" ]
            ]
        , div [] [ text "width", input [ value (String.fromInt g.width), onInput Width, type_ "number" ] [] ]
        ]


viewBoard : Board -> Html Msg
viewBoard b =
    List.range 0 (Board.maxY b)
        |> List.map (viewRow b)
        |> div []


viewRow : Board -> Int -> Html Msg
viewRow b y =
    List.range 0 (Board.maxX b)
        |> List.map (viewSquare b y)
        |> row []


viewSquare : Board -> Int -> Int -> Html Msg
viewSquare b y x =
    case Board.square x y b of
        ( Plain, Bomb ) ->
            unswept [ onRightClick (Toggle x y), onClick (Lose x y) ] []

        ( Plain, _ ) ->
            unswept [ onRightClick (Toggle x y), onClick (Sweep x y) ] []

        ( Flagged, _ ) ->
            unswept [ onRightClick (Toggle x y) ] [ text "⚐" ]

        ( Question, _ ) ->
            unswept [ onRightClick (Toggle x y) ] [ text "?" ]

        ( Exposed, Neighbor 0 ) ->
            blank

        ( Exposed, Neighbor 1 ) ->
            swept "blue" 1

        ( Exposed, Neighbor 2 ) ->
            swept "green" 2

        ( Exposed, Neighbor 3 ) ->
            swept "red" 3

        ( Exposed, Neighbor 4 ) ->
            swept "purple" 4

        ( Exposed, Neighbor 5 ) ->
            swept "maroon" 5

        ( Exposed, Neighbor 6 ) ->
            swept "turquoise" 6

        ( Exposed, Neighbor n ) ->
            swept "black" n

        ( Exposed, Bomb ) ->
            lost [] [ text "💣" ]



-- STYLING


row : List (Attribute msg) -> List (Html msg) -> Html msg
row =
    div


base : List (Attribute msg) -> List (Html msg) -> Html msg
base attrs =
    span <|
        attrs
            ++ [ style "display" "inline-block"
               , style "width" "20px"
               , style "height" "20px"
               , style "border-width" "3px"
               , style "text-align" "center"
               , style "vertical-align" "top"
               , style "font-weight" "bold"
               ]


unswept : List (Attribute msg) -> List (Html msg) -> Html msg
unswept attrs =
    base <|
        attrs
            ++ [ style "background-color" "gray"
               , style "border-style" "outset"
               ]


blank : Html msg
blank =
    base
        [ style "background-color" "lightgray"
        , style "border-style" "solid"
        , style "border-color" "gray"
        ]
        []


swept : String -> Int -> Html msg
swept c n =
    base
        [ style "background-color" "lightgray"
        , style "border-style" "solid"
        , style "border-color" "gray"
        , style "color" c
        ]
        [ text <| String.fromInt n ]


lost : List (Attribute msg) -> List (Html msg) -> Html msg
lost attrs =
    base <|
        attrs
            ++ [ style "background-color" "red"
               , style "border-style" "solid"
               , style "border-color" "red"
               ]
