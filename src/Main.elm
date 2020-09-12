module Main exposing (main)

import Browser
import Browser.Events
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Svg exposing (Svg, g, svg, text, text_)
import Svg.Attributes exposing (fill, fontFamily, fontSize, height, width, x, y)
import Time

import ShapePoker

type Game
    = BeingPlayed Players
    | FinishedPlaying Players ShapePoker.Analytics
    | WaitingToBeGenerated

type alias Model =
    { game : Game
    , ui : ShapePoker.UIState
    }


type alias Players =
    { playerA : ShapePoker.PlayerData
    , playerB : ShapePoker.PlayerData
    }
    

type Msg
    = Begin Players
    | GamesComplete ShapePoker.Analytics
    | UI ShapePoker.ViewMsg

initialModel : Model
initialModel = 
    { game = WaitingToBeGenerated
    , ui = ShapePoker.initUIState
    }
    


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.game ) of
        ( Begin players, WaitingToBeGenerated ) ->
            ( { model | game = BeingPlayed players }, ShapePoker.newGameCmd GamesComplete players )

        ( Begin improvedPlayers, FinishedPlaying _ _ ) ->
            ( { model | game = BeingPlayed improvedPlayers }, ShapePoker.newGameCmd GamesComplete improvedPlayers )

        ( GamesComplete analytics, BeingPlayed lastPlayers ) ->
            ( { model | game = FinishedPlaying lastPlayers analytics }, Cmd.none )

        (UI viewmsg, _) ->
            ( { model | ui = ShapePoker.updateView viewmsg model.ui }, Cmd.none )

        _ ->
            (model, Cmd.none)


view : Model -> Html Msg
view model =
    case model.game of
        BeingPlayed players ->
            div []
                [ svg
                    [ width "20000"
                    , height "9000"
                    ]
                    (ShapePoker.viewGameContent players model.ui
                        |> List.map (Svg.map UI)
                    )
                ]

        FinishedPlaying lastPlayers analytics ->
            let
                improvedPlayers =
                    ShapePoker.improve analytics lastPlayers
            in
            div []
                [ svg
                    [ width "20000"
                    , height "9000"
                    ]
                    (ShapePoker.viewGameContent improvedPlayers model.ui
                        |> List.map (Svg.map UI)
                    )
                ]

        WaitingToBeGenerated ->
            div []
                [ Html.text "Loading. . ." ]

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.game of
        BeingPlayed players ->
            Sub.none
        
        WaitingToBeGenerated ->
            Sub.none
        
        FinishedPlaying lastPlayers analytics ->
            let
                improvedPlayers =
                    ShapePoker.improve analytics lastPlayers
            in
            Time.every (1000 / 60)
                <| always 
                    <| Begin improvedPlayers



main : Program () Model Msg
main =
    let
        documentView model =
            { title = "Shape Poker"
            , body = [ view model ]
            }
    in
    Browser.document
        { init = \_ -> ( initialModel, ShapePoker.initCmd Begin )
        , view = documentView
        , update = update
        , subscriptions = subscriptions
        }
