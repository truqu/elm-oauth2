module Extra.Maybe exposing (andThen2)

{-| Extra helpers for `Maybe`

@docs andThen2

-}


andThen2 : (a -> b -> Maybe c) -> Maybe a -> Maybe b -> Maybe c
andThen2 fn ma mb =
    Maybe.andThen identity (Maybe.map2 fn ma mb)
