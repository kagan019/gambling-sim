module ShapePoker exposing (Analytics(..), AnalyticsData, BoardState(..), Color, Decision(..), DecisionAsComparable, InvalidDecision(..), Loser(..), Option(..), Player(..), PlayerData, Player_(..), Strategy(..), UIState, ValidDecision(..), ViewMsg(..), Weight, allDecisions, allOptions, allStates, availableDecisions, boardStateToComparable, checkDecision, compareDecisions, compareOptions, compareStates, decisionBoxes, decisionToComparable, decisionToOptions, easyDecision, improve, improveLoserStrategy, initCmd, initUIState, initialPlayers, invalidateDecision, inverseStates, newGameCmd, newGameTask, optionToComparable, phantomDecision, play, randomPlayer, randomToTask, reward, shapes, updateView, validateDecision, viewDecision, viewGameContent, viewOption, viewStrategy, viewWinRatioBar, weightToString)

import Array exposing (Array)
import Dict exposing (Dict)
import Random exposing (Generator)
import Set exposing (Set)
import Svg exposing (Svg, g)
import Svg.Attributes exposing (..)
import Svg.Events exposing (onClick)
import Task exposing (Task)
import Time
import Combinatorics


-- init


initCmd msg =
    Random.generate msg initialPlayers


newGameCmd msg players =
    Random.generate msg (play 100 players.playerA players.playerB)


newGameTask players =
    randomToTask (play 100 players.playerA players.playerB)


randomToTask : Generator a -> Task Never a
randomToTask generator =
    Time.now
        |> Task.map (Tuple.first << Random.step generator << Random.initialSeed << Time.posixToMillis)


type Analytics
    = ALost AnalyticsData
    | BLost AnalyticsData
    | Tie AnalyticsData


type Loser
    = ALost_
    | BLost_
    | Tie_


type alias AnalyticsData =
    { aWinningsThisSession : Int
    , bWinningsThisSession : Int
    , aLossesByPlay : Dict DecisionAsComparable Int
    , bLossesByPlay : Dict DecisionAsComparable Int
    }


play : Int -> PlayerData -> PlayerData -> Generator Analytics
play times playerA_ playerB_ =
    let
        randomAAndBHiddenKnowledge =
            Random.uniform Circle [ Square, Triangle ]
                |> Random.andThen
                    (\opt ->
                        let
                            gen2 =
                                case opt of
                                    Circle ->
                                        Random.uniform Square [ Triangle ]

                                    Square ->
                                        Random.uniform Circle [ Triangle ]

                                    Triangle ->
                                        Random.uniform Circle [ Square ]
                        in
                        gen2
                            |> Random.map
                                (\opt2 ->
                                    ( opt, opt2 )
                                )
                    )

        randomListOfGenerator length generator =
            List.range 1 length
                |> List.map (always generator)
                |> List.foldl
                    (\randlist randstate ->
                        Random.map2
                            (\list state ->
                                list :: state
                            )
                            randlist
                            randstate
                    )
                    (Random.constant [])

        startAnalysis =
            { aWinningsThisSession = 0
            , bWinningsThisSession = 0
            , aLossesByPlay =
                allDecisions
                    |> List.map
                        (\dec ->
                            ( decisionToComparable dec, 0 )
                        )
                    |> Dict.fromList
            , bLossesByPlay =
                allDecisions
                    |> List.map
                        (\dec ->
                            ( decisionToComparable dec, 0 )
                        )
                    |> Dict.fromList
            }

        initialSetup pa pb analysis =
            { playerA = pa
            , playerB = pb
            , gameHistory = Set.empty
            , turn = 0
            , lastDecision = Nothing
            , currentState = Nothing
            , analysis = analysis
            }

        incrementTurn ({ turn } as game) =
            { game | turn = turn + 1 }

        nextState newDec lastDec turn =
            case modBy 2 turn of
                0 ->
                    State newDec lastDec

                _ ->
                    State lastDec newDec

        makeDecision decision ({ gameHistory, lastDecision, turn, currentState } as game) =
            case lastDecision of
                Nothing ->
                    { game
                        | lastDecision = Just decision
                        , turn = 1
                    }

                Just dec ->
                    let
                        newState =
                            nextState decision dec turn
                        
                        newHistory = 
                            Set.insert (boardStateToComparable newState) gameHistory
                    in
                    { game
                        | gameHistory = newHistory
                        , lastDecision = Just dec
                        , currentState = Just newState
                        , turn = turn + 1
                    }

        wouldEndGameIfPlayed decision ({ gameHistory, lastDecision, turn } as game) =
            case lastDecision of
                Nothing ->
                    False

                Just dec ->
                    Set.member
                        (boardStateToComparable (nextState decision dec turn))
                        gameHistory

        assignHiddenKnowlege pa pb alys =
            Random.map
                (\( aknow, bknow ) ->
                    initialSetup
                        { pa | hiddenKnowlege = aknow }
                        { pb | hiddenKnowlege = bknow } 
                        alys
                )
                randomAAndBHiddenKnowledge

        strategies plr =
            case plr.strategy of
                AStrategy start strat ->
                    ( Just start, strat )

                BStrategy strat ->
                    ( Nothing, strat )

        getStrategy ({ lastDecision } as game) =
            case lastDecision of
                Nothing ->
                    startStrategy game

                Just dec ->
                    strategies (determinePlayer game)
                        |> Tuple.second
                        |> Dict.map
                            -- for now
                            (\k list ->
                                list
                                    |> List.map
                                        (\( w1, w2, c ) ->
                                            ( w1, c )
                                        )
                            )
                        |> Dict.get (decisionToComparable dec)

        startStrategy { playerA } =
            strategies playerA
                |> Tuple.first

        determinePlayer { playerA, playerB, turn } =
            case modBy 2 turn of
                0 ->
                    playerA

                _ ->
                    playerB

        playGame game =
            let
                dumbStrategy =
                    -- dumb because its a silent killer
                    Maybe.withDefault [ ( 0, Double Square Triangle ) ] (getStrategy game)

                dumbLastDecision =
                    -- dumb for the same reason
                    Maybe.withDefault (easyDecision Square Triangle) game.lastDecision
            in
            Random.weighted ( 0, Double Square Triangle ) dumbStrategy
                |> Random.andThen
                    (\decision ->
                        let
                            nextGameState =
                                makeDecision decision game
                        
                        in
                        if 
                            compare 
                                ( decisionToComparable decision ) 
                                ( decisionToComparable 
                                    dumbLastDecision
                                ) 
                            == EQ 
                        then
                            playGame game
                        else
                            if wouldEndGameIfPlayed decision game then
                                Random.constant nextGameState

                            else        
                                playGame nextGameState
                            
                    )

        analyze ({ playerA, playerB, analysis, currentState } as game) =
            let
                (State aDec bDec) =
                    -- silent killer
                    Maybe.withDefault (State (Double Circle Square) (Double Square Triangle)) currentState

                correctDecision =
                    easyDecision playerA.hiddenKnowlege playerB.hiddenKnowlege

                aReward =
                    reward aDec correctDecision

                bReward =
                    reward bDec correctDecision

                rewarded =
                    { analysis
                        | aWinningsThisSession =
                            analysis.aWinningsThisSession + aReward
                        , bWinningsThisSession =
                            analysis.bWinningsThisSession + bReward
                    }

                tickLosses dictA dictB =
                    case compare rewarded.aWinningsThisSession rewarded.bWinningsThisSession of
                        LT ->
                            -- a lost
                            ( Dict.update
                                (decisionToComparable aDec)
                                (Maybe.map
                                    (\v ->
                                        v + 1
                                    )
                                )
                                dictA
                            , dictB
                            )

                        EQ ->
                            -- tie
                            ( Dict.update
                                (decisionToComparable aDec)
                                (Maybe.map
                                    (\v ->
                                        v + 1
                                    )
                                )
                                dictA
                            , Dict.update
                                (decisionToComparable bDec)
                                (Maybe.map
                                    (\v ->
                                        v + 1
                                    )
                                )
                                dictB
                            )

                        GT ->
                            -- b lost
                            ( dictA
                            , Dict.update
                                (decisionToComparable bDec)
                                (Maybe.map
                                    (\v ->
                                        v + 1
                                    )
                                )
                                dictB
                            )
                            

                ( dictAUpdated, dictBUpdated ) =
                    tickLosses rewarded.aLossesByPlay rewarded.bLossesByPlay

                rewardedUpdated =
                    { rewarded
                        | aLossesByPlay = dictAUpdated
                        , bLossesByPlay = dictBUpdated
                    }
            in
            { game
                | analysis = rewardedUpdated
            }

        finalize analysis =
            case compare analysis.aWinningsThisSession analysis.bWinningsThisSession of
                LT ->
                    -- a lost
                    ALost analysis

                EQ ->
                    -- tie
                    Tie analysis

                GT ->
                    -- b lost
                    BLost analysis

        
        playNextGame { playerA, playerB, analysis } =
            assignHiddenKnowlege playerA playerB analysis
                |> Random.andThen playGame
        

        playNRngGames n randomGame =
            List.foldl 
                (<|)
                randomGame
                (List.repeat n ((Random.andThen playNextGame) >> (Random.map analyze)))
        
    in
    assignHiddenKnowlege playerA_ playerB_ startAnalysis
        |> playNRngGames times
        |> Random.map (.analysis >> finalize)


reward : Decision ValidDecision -> Decision ValidDecision -> Int
reward (Double dec1 dec2) (Double cor1 cor2) =
    case ( compareOptions dec1 cor1, compareOptions dec2 cor2 ) of
        ( EQ, EQ ) ->
            3

        ( EQ, _ ) ->
            1

        ( _, EQ ) ->
            1

        _ ->
            -- should never happen
            0



-- Player


type alias PlayerData =
    { strategy : Strategy
    , hiddenKnowlege : Option
    , winnings : Int
    }


type Player
    = A PlayerData
    | B PlayerData


type Player_
    = A_
    | B_


initialPlayers : Generator { playerA : PlayerData, playerB : PlayerData }
initialPlayers =
    Random.map2
        (\a b ->
            { playerA = a
            , playerB = b
            }
        )
        (randomPlayer A_)
        (randomPlayer B_)


randomPlayer : Player_ -> Generator PlayerData
randomPlayer player =
    let
        normalizeWeights list =
            let
                sum =
                    List.sum list
            in
            list
                |> List.map
                    (\unnormalizedWeight ->
                        unnormalizedWeight / sum
                    )

        listOfRandomWeights =
            Random.list (List.length allDecisions) (Random.float 0 1)
                |> Random.map normalizeWeights
                    

        listOfRandomlyWeightedDecisions =
            listOfRandomWeights
                |> Random.map
                    (\list ->
                        List.map2
                            (\decision weight ->
                                ( weight, decision )
                            )
                            allDecisions
                            list
                    )

        randomListOfGenerator length generator =
            List.range 1 length
                |> List.map (always generator)
                |> List.foldl
                    (\randlist randstate ->
                        Random.map2
                            (\list state ->
                                list :: state
                            )
                            randlist
                            randstate
                    )
                    (Random.constant [])

        listOfListOfRandomWeights =
            randomListOfGenerator
                (List.length allDecisions)
                listOfRandomWeights

        listOfListOfRandomlyWeightedDecisions =
            randomListOfGenerator
                (List.length allDecisions)
                listOfRandomlyWeightedDecisions

        strategyDict =
            let
                allComprDecisions =
                    allDecisions
                        |> List.map decisionToComparable

                doubleWeightedDecList weightedDecList weightList =
                    List.map2
                        (\( weight1, dec ) weight2 ->
                            ( weight1, weight2, dec )
                        )
                        weightedDecList
                        weightList
            in
            Random.map2
                (\listOfListDec listOfListWeights ->
                    List.map3
                        (\comprDec list1 list2 ->
                            let
                                dwdl =
                                    doubleWeightedDecList list1 list2

                                dwdlPruningDoublePlays =
                                    dwdl 
                                        |> List.map
                                            ( \ ((w1, w2, dec) as v) ->
                                                case compare comprDec (decisionToComparable dec) of
                                                    EQ ->
                                                        (0, 0, dec)
                                                    _ ->
                                                        v
                                            )
                                
                                
                                normalizedDwdlPruningDoublePlays =
                                    let
                                        sum1 =
                                            List.sum <|
                                                List.map
                                                    ( \ (f, s, t) -> f )
                                                    dwdlPruningDoublePlays

                                        sum2 =
                                            List.sum <|
                                                List.map
                                                    ( \ (f, s, t) -> s )
                                                    dwdlPruningDoublePlays
                                    in
                                    dwdlPruningDoublePlays
                                        |> List.map
                                            ( \ (w1, w2, dec) -> (w1 / sum1, w2 / sum2, dec) ) 
                            in
                            ( comprDec, normalizedDwdlPruningDoublePlays )
                        )
                        allComprDecisions
                        listOfListDec
                        listOfListWeights
                        |> Dict.fromList
                )
                listOfListOfRandomlyWeightedDecisions
                listOfListOfRandomWeights

        --deprecated
        randomAAndBHiddenKnowledge =
            Random.uniform Circle [ Square, Triangle ]
                |> Random.andThen
                    (\opt ->
                        let
                            gen2 =
                                case opt of
                                    Circle ->
                                        Random.uniform Square [ Triangle ]

                                    Square ->
                                        Random.uniform Circle [ Triangle ]

                                    Triangle ->
                                        Random.uniform Circle [ Square ]
                        in
                        gen2
                            |> Random.map
                                (\opt2 ->
                                    ( opt, opt2 )
                                )
                    )

        --deprecated
        randomAHiddenKnowlege =
            randomAAndBHiddenKnowledge
                |> Random.map Tuple.first

        --deprecated
        randomBHiddenKnowlege =
            randomAAndBHiddenKnowledge
                |> Random.map Tuple.second

        exampleStratA = 
            AStrategy
                [ (0, easyDecision Circle Square)
                , (0, easyDecision Circle Triangle)
                , (1, easyDecision Square Triangle)
                ] <|
                Dict.fromList
                    [ ( [0, 1]
                      , [ (0, 0, easyDecision Circle Square)
                        , (0, 0, easyDecision Circle Triangle)
                        , (1, 1, easyDecision Square Triangle)
                        ]
                      )
                    , ( [0, 2]
                      , [ (0, 0, easyDecision Circle Square)
                        , (0, 0, easyDecision Circle Triangle)
                        , (1, 1, easyDecision Square Triangle)
                        ]
                      )
                    , ( [1, 2]
                      , [ (0, 0, easyDecision Circle Square)
                        , (1, 1, easyDecision Circle Triangle)
                        , (0, 0, easyDecision Square Triangle)
                        ]
                      )
                    ]

        exampleStratB =
            BStrategy <|
                Dict.fromList
                    [ ( [0, 1]
                      , [ (0, 0, easyDecision Circle Square)
                        , (1, 1, easyDecision Circle Triangle)
                        , (0, 0, easyDecision Square Triangle)
                        ]
                      )
                    , ( [0, 2]
                      , [ (0, 0, easyDecision Circle Square)
                        , (0, 0, easyDecision Circle Triangle)
                        , (1, 1, easyDecision Square Triangle)
                        ]
                      )
                    , ( [1, 2]
                      , [ (0, 0, easyDecision Circle Square)
                        , (1, 1, easyDecision Circle Triangle)
                        , (0, 0, easyDecision Square Triangle)
                        ]
                      )
                    ]
    in
    case player of
        A_ ->
            Random.map3
                (\astrat weightedDecisions know ->
                    { strategy =
                        --exampleStratA{-
                        AStrategy
                            weightedDecisions
                            astrat--}
                    , hiddenKnowlege = Square
                    , winnings = 0
                    }
                )
                strategyDict
                listOfRandomlyWeightedDecisions
                randomAHiddenKnowlege --ignored

        B_ ->
            Random.map2
                (\bstrat know ->
                    { strategy =
                        --exampleStratB{-
                        BStrategy
                            bstrat--}
                    , hiddenKnowlege = Triangle
                    , winnings = 0
                    }
                )
                strategyDict
                randomBHiddenKnowlege --ignored



-- Option


type Option
    = Circle
    | Square
    | Triangle


allOptions =
    [ Circle, Square, Triangle ]


optionToComparable option =
    case option of
        Circle ->
            0

        Square ->
            1

        Triangle ->
            2


compareOptions a b =
    compare (optionToComparable a) (optionToComparable b)



-- Decisions


type Decision validate
    = Double Option Option


allDecisions =
    [ Combinatorics.everyCombination 2 (Array.fromList allOptions)
        |> List.filterMap
            (\combination ->
                case List.sortWith compareOptions combination of
                    first :: second :: [] ->
                        Just (Double first second)

                    _ ->
                        Nothing
            )
    ]
        |> List.concat
        |> List.filterMap
            (\unvalidatedDecision ->
                Result.toMaybe (checkDecision unvalidatedDecision)
            )


decisionToOptions decision =
    case decision of
        Double a b ->
            [ a, b ]
                |> List.sortWith compareOptions


easyDecision : Option -> Option -> Decision ValidDecision
easyDecision a b =
    -- a and b must be different
    case ( a, b ) of
        ( Circle, _ ) ->
            Double a b

        ( _, Triangle ) ->
            Double a b

        _ ->
            easyDecision b a


type alias DecisionAsComparable =
    List Int


decisionToComparable : Decision a -> List Int
decisionToComparable decision =
    decisionToOptions decision
        |> List.map optionToComparable


compareDecisions a b =
    compare (decisionToComparable a) (decisionToComparable b)


availableDecisions maybeLastDecision =
    case maybeLastDecision of
        Just last ->
            allDecisions
                |> List.filter (\decision -> compareDecisions decision last /= EQ)

        Nothing ->
            allDecisions


type ValidDecision
    = ValidDecision


type InvalidDecision
    = InvalidDecision


phantomDecision : Decision a -> Decision b
phantomDecision decision =
    case decision of
        Double f s ->
            Double f s


validateDecision : Decision a -> Result (Decision InvalidDecision) (Decision ValidDecision)
validateDecision decision =
    Ok (phantomDecision decision)


invalidateDecision : Decision a -> Result (Decision InvalidDecision) (Decision ValidDecision)
invalidateDecision decision =
    Err (phantomDecision decision)


checkDecision decision =
    case decision of
        Double op1 op2 ->
            case compareOptions op1 op2 of
                LT ->
                    validateDecision decision

                EQ ->
                    invalidateDecision decision

                GT ->
                    invalidateDecision decision



-- Board State


type BoardState
    = State (Decision ValidDecision) (Decision ValidDecision)


allStates =
    Combinatorics.everyCombination 2 (Array.fromList allDecisions)
        |> List.filterMap
            (\combination ->
                case combination of
                    a :: b :: [] ->
                        if compareDecisions a b == EQ then
                            Nothing

                        else
                            Just (State a b)

                    _ ->
                        Nothing
            )


inverseStates (State a b) state2 =
    boardStateToComparable (State b a) == boardStateToComparable state2


boardStateToComparable (State a b) =
    ( decisionToComparable a, decisionToComparable b )


compareStates statea stateb =
    compare (boardStateToComparable statea) (boardStateToComparable stateb)



-- Strategy


type Strategy
    = AStrategy (List ( Weight, Decision ValidDecision )) (Dict DecisionAsComparable (List ( Weight, Weight, Decision ValidDecision )))
    | BStrategy (Dict DecisionAsComparable (List ( Weight, Weight, Decision ValidDecision )))


type alias Weight =
    Float


weightToString weight =
    String.left 4 <| String.fromFloat weight


improve analytics players =
    let
        improvePlayer player analyticsData =
            { player | strategy = improveLoserStrategy 0.1 analyticsData player.strategy }

        addToWinnings amt player =
            { player
                | winnings = player.winnings + amt
            }
    in
    case analytics of
        ALost data ->
            { players
                | playerA = improvePlayer (addToWinnings data.aWinningsThisSession players.playerA) data.aLossesByPlay
                , playerB = addToWinnings data.bWinningsThisSession players.playerB
            }

        BLost data ->
            { players
                | playerA = addToWinnings data.aWinningsThisSession players.playerA
                , playerB = improvePlayer (addToWinnings data.bWinningsThisSession players.playerB) data.bLossesByPlay
            }

        Tie data ->
            { players
                | playerA = improvePlayer (addToWinnings data.aWinningsThisSession players.playerA) data.aLossesByPlay
                , playerB = improvePlayer (addToWinnings data.bWinningsThisSession players.playerB) data.bLossesByPlay
            }


improveLoserStrategy delta lossesByPlay loserStrategy =
    loserStrategy
    {-
        A few different algorithms could go here. 
            - One relies on tweaking `loserStrategy` by `delta` in order to improve the strategy's performance. The idea is to identify weaknesses in the opponent strategy and gradient-descent to that.
            - Another is to randomly create a new strategy. If that does better, analyze what moves in particular
              were more successful and adjust the statistics of the randomizer accordingly.
        Either strategy is interesting because it is not obvious whether either of them will always converge with
        2 opponents. What about with 3, 20, 400 opponents?
    -} 



-- View


type alias Color =
    String


viewWinRatioBar : PlayerData -> PlayerData -> Svg msg
viewWinRatioBar playerA playerB =
    let
        startX =
            40

        fullWidth =
            1375

        sum =
            List.sum <| List.map Tuple.first playersNumberOfWinsInASample

        coordinatesAndColors : List ( { x : Int, width : Int }, Color )
        coordinatesAndColors =
            playersNumberOfWinsInASample
                |> List.foldl
                    (\( wins, color_ ) ( listState, last ) ->
                        let
                            next =
                                { x = last.x + last.width
                                , width = round ((toFloat wins / toFloat sum) * fullWidth)
                                }
                        in
                        ( ( next, color_ ) :: listState
                        , next
                        )
                    )
                    ( [], { x = 0, width = startX } )
                |> Tuple.first
                |> List.reverse

        playersNumberOfWinsInASample =
            [ ( playerA.winnings, "firebrick" ), ( playerB.winnings, "mediumblue" ) ]

        viewCenterDivider =
            Svg.rect
                [ x (String.fromInt (startX + fullWidth // 2 - 3))
                , y "10"
                , width "3"
                , height "60"
                ]
                []

    in
    if sum <= 0 then
        g
            []
            [ Svg.rect
                [ x (String.fromInt startX)
                , y "20"
                , width (String.fromInt fullWidth)
                , height "40"
                ]
                []
            , viewCenterDivider
            ]

    else
        g
            []
            ((coordinatesAndColors
                |> List.map
                    (\( coord, color_ ) ->
                        Svg.rect
                            [ x (String.fromInt coord.x)
                            , y "20"
                            , width (String.fromInt coord.width)
                            , height "40"
                            , fill color_
                            , stroke "none"
                            ]
                            []
                    )
            ) ++ [ viewCenterDivider ])


shapes =
    let
        size =
            25
    in
    { square =
        \x_ y_ ->
            viewOption size x_ y_ Square
    , circle =
        \x_ y_ ->
            viewOption size x_ y_ Circle
    , triangle =
        \x_ y_ ->
            viewOption size x_ y_ Triangle
    }


viewOption : Int -> Int -> Int -> Option -> Svg msg
viewOption size x_ y_ option =
    let
        pointsFromList listOfCoords =
            points <|
                (listOfCoords
                    |> List.map (\( x, y ) -> String.fromInt x ++ "," ++ String.fromInt y)
                    |> String.join " "
                )
    in
    case option of
        Circle ->
            g
                []
                [ Svg.circle
                    [ cx (String.fromInt (x_ + size // 2))
                    , cy (String.fromInt (y_ + size // 2))
                    , r (String.fromInt (size // 2))
                    , fill "darkblue"
                    , stroke "none"
                    ]
                    []
                ]

        Square ->
            g
                []
                [ Svg.rect
                    [ x (String.fromInt x_)
                    , y (String.fromInt y_)
                    , width (String.fromInt size)
                    , height (String.fromInt size)
                    , fill "darkred"
                    , stroke "none"
                    ]
                    []
                ]

        Triangle ->
            g
                []
                [ Svg.polygon
                    [ fill "darkgreen"
                    , stroke "none"
                    , pointsFromList
                        [ ( 0 + x_, size + y_ )
                        , ( size // 2 + x_, 0 + y_ )
                        , ( size + x_, size + y_ )
                        ]
                    ]
                    []
                ]


viewDecision : Decision ValidDecision -> Int -> Int -> Svg msg
viewDecision decision x_ y_ =
    let
        neighborOffset =
            50

        optionToShape option =
            case option of
                Square ->
                    shapes.square

                Circle ->
                    shapes.circle

                Triangle ->
                    shapes.triangle
    in
    case decision of
        Double a b ->
            g
                []
                [ optionToShape a x_ y_
                , optionToShape b (x_ + neighborOffset) y_
                ]


decisionBoxes maybePlayer =
    let
        color_ =
            case maybePlayer of
                Just (A _) ->
                    "firebrick"

                Just (B _) ->
                    "mediumblue"

                Nothing ->
                    "black"

        startX =
            case maybePlayer of
                Just (A _) ->
                    600

                Just (B _) ->
                    1000

                Nothing ->
                    100

        eventProps i =
            case maybePlayer of
                Just (A _) ->
                    []

                Just (B _) ->
                    []

                Nothing ->
                    [ onClick (SelectDecisionIndex i) ]
    in
    [ [ Svg.rect
            [ x (String.fromInt startX)
            , y "200"
            , width "340"
            , height "300"
            , stroke color_
            , fill "none"
            ]
            []
      ]
    , allDecisions
        |> List.indexedMap
            (\i decision ->
                g
                    (eventProps i ++ [ style "border: 1px solid orange" ])
                    [ viewDecision decision (startX + 105) (220 + 103 * i) ]
            )
    ]
        |> List.concat


viewStrategy strategyIndex { strategy } =
    case strategy of
        AStrategy startStrat strat ->
            let
                comparableDecisionOfStrategyIndex =
                    allDecisions
                        |> Array.fromList
                        |> Array.get strategyIndex

                listOfWeights =
                    comparableDecisionOfStrategyIndex
                        |> Maybe.andThen
                            (\si ->
                                Dict.get (decisionToComparable si) strat
                            )
            in
            case listOfWeights of
                Just list ->
                    [ startStrat
                        |> List.indexedMap
                            (\i ( chanceIfWouldBeFirstMove, _ ) ->
                                Svg.text_
                                    [ x "340"
                                    , y (String.fromInt (243 + 103 * i))
                                    , fill "firebrick   "
                                    , fontFamily "sans-serif"
                                    , fontSize "22"
                                    ]
                                    [ Svg.text (weightToString chanceIfWouldBeFirstMove) ]
                            )
                    , list
                        |> List.indexedMap
                            (\i ( chanceIfWouldNotBeLastMove, chanceIfWouldBeLastMove, _ ) ->
                                [ Svg.text_
                                    [ x "610"
                                    , y (String.fromInt (243 + 103 * i))
                                    , fill "firebrick"
                                    , fontFamily "sans-serif"
                                    , fontSize "22"
                                    ]
                                    [ Svg.text (weightToString chanceIfWouldNotBeLastMove) ]
                                , Svg.text_
                                    [ x "850"
                                    , y (String.fromInt (243 + 103 * i))
                                    , fill "firebrick"
                                    , fontFamily "sans-serif"
                                    , fontSize "22"
                                    ]
                                    [ Svg.text (weightToString chanceIfWouldBeLastMove) ]
                                ]
                            )
                        |> List.concat
                    ]

                Nothing ->
                    []

        BStrategy strat ->
            let
                comparableDecisionOfStrategyIndex =
                    allDecisions
                        |> Array.fromList
                        |> Array.get strategyIndex

                listOfWeights =
                    comparableDecisionOfStrategyIndex
                        |> Maybe.andThen
                            (\si ->
                                Dict.get (decisionToComparable si) strat
                            )
            in
            case listOfWeights of
                Just list ->
                    list
                        |> List.indexedMap
                            (\i ( chanceIfWouldNotBeLastMove, chanceIfWouldBeLastMove, _ ) ->
                                [ Svg.text_
                                    [ x "1010"
                                    , y (String.fromInt (243 + 103 * i))
                                    , fill "mediumblue"
                                    , fontFamily "sans-serif"
                                    , fontSize "22"
                                    ]
                                    [ Svg.text (weightToString chanceIfWouldNotBeLastMove) ]
                                , Svg.text_
                                    [ x "1240"
                                    , y (String.fromInt (243 + 103 * i))
                                    , fill "mediumblue"
                                    , fontFamily "sans-serif"
                                    , fontSize "22"
                                    ]
                                    [ Svg.text (weightToString chanceIfWouldBeLastMove) ]
                                ]
                            )

                Nothing ->
                    []


viewGameContent players ui =
    [ [ viewWinRatioBar players.playerA players.playerB ]
    , [ Svg.text_
            [ x "400"
            , y "100"
            , fill "firebrick"
            , fontFamily "sans-serif"
            , fontSize "32"
            ]
            [ Svg.text "A" ]
      , Svg.text_
            [ x "1000"
            , y "100"
            , fill "mediumblue"
            , fontFamily "sans-serif"
            , fontSize "32"
            ]
            [ Svg.text "B" ]
      ]
    , [ Nothing, Just (A players.playerA), Just (B players.playerB) ]
        |> List.map decisionBoxes
        |> List.concat
    , [ players.playerA, players.playerB ]
        |> List.map (viewStrategy ui.selectedDecisionIndex)
        |> List.concat
        |> List.concat
    ]
        |> List.concat


updateView viewmsg ui =
    case viewmsg of
        SelectDecisionIndex index ->
            { ui | selectedDecisionIndex = index }


type alias UIState =
    { selectedDecisionIndex : Int
    }


initUIState =
    { selectedDecisionIndex = 0
    }


type ViewMsg
    = SelectDecisionIndex Int
