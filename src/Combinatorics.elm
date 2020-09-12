module Combinatorics exposing (everyCombination)

import Array exposing (Array)


everyCombination howMany array =
    let
        lenArray =
            Array.length array

        listOfCombinationsOfNumbersZeroThroughN howMany_ n =
            case ( compare howMany_ 1, compare n 0 ) of
                ( LT, _ ) ->
                    []

                ( _, LT ) ->
                    []

                ( EQ, _ ) ->
                    List.range 0 n
                        |> List.map (\x -> [ x ])

                ( GT, _ ) ->
                    listOfCombinationsOfNumbersZeroThroughN (howMany_ - 1) (n - 1)
                        |> List.map (\combination -> n :: combination)
                        |> (++) (listOfCombinationsOfNumbersZeroThroughN howMany_ (n - 1))
    in
    listOfCombinationsOfNumbersZeroThroughN howMany (lenArray - 1)
        |> List.map
            (\combination ->
                combination
                    |> List.map (\i -> Array.get i array)
                    |> List.filterMap identity
            )
