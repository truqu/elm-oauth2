module OAuth.Decode exposing (..)

{-| This module exposes decoders and helpers to fine tune some requests when necessary.

This might come in handy for provider that doesn't exactly implement the OAuth 2.0 RFC
(like the API v3 of GitHub). With these utilities, one should hopefully be able to adjust
requests made to the Authorization Server and cope with implementation quirks.


## Type Utilities

@docs RequestParts, AdjustRequest


## Json Decoders

@docs responseDecoder, expiresInDecoder, scopeDecoder, lenientScopeDecoder, stateDecoder, accessTokenDecoder, refreshTokenDecoder, jwtPayloadDecoder, decodeJWTPayloadString


## Constructors

@docs makeToken, makeResponseToken

-}

import OAuth exposing (..)
import Json.Decode as Json
import Http as Http
import Time exposing (Time)


{-| Parts required to build a request. This record is given to `Http.request` in order
to create a new request and may be adjusted at will.
-}
type alias RequestParts a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Expect a
    , timeout : Maybe Time
    , withCredentials : Bool
    }


{-| Alias for the behavior passed to some function in order to adjust Http Request before they get
sent

For instance,

    adjustRequest : AdjustRequest ResponseToken
    adjustRequest req =
        { req | headers = [ Http.header "Accept" ("application/json") ] :: req.headers }

-}
type alias AdjustRequest a =
    RequestParts a -> RequestParts a


{-| Json decoder for a response. You may provide a custom response decoder using other decoders
from this module, or some of your own craft.

For instance,

    myScopeDecoder : Json.Decoder (Maybe (List String))
    myScopeDecoder =
        Json.maybe <|
            Json.oneOf
                [ Json.field "scope" (Json.map (String.split ",") Json.string) ]

    myResponseDecoder : Json.Decoder ResponseToken
    myResponseDecoder =
        Json.map5 makeResponseToken
            accessTokenDecoder
            expiresInDecoder
            refreshTokenDecoder
            myScopeDecoder
            stateDecoder

-}
responseDecoder : Json.Decoder ResponseToken
responseDecoder =
    Json.map5 makeResponseToken
        accessTokenDecoder
        expiresInDecoder
        refreshTokenDecoder
        scopeDecoder
        stateDecoder


{-| Json decoder for an expire timestamp
-}
expiresInDecoder : Json.Decoder (Maybe Int)
expiresInDecoder =
    Json.maybe <| Json.field "expires_in" Json.int


{-| Json decoder for a scope
-}
scopeDecoder : Json.Decoder (Maybe (List String))
scopeDecoder =
    Json.maybe <| Json.field "scope" (Json.list Json.string)


{-| Json decoder for a scope, allowing comma- or space-separated scopes
-}
lenientScopeDecoder : Json.Decoder (Maybe (List String))
lenientScopeDecoder =
    Json.maybe <|
        Json.field "scope" <|
            Json.oneOf
                [ Json.list Json.string
                , Json.map (String.split ",") Json.string
                ]


{-| Json decoder for a state
-}
stateDecoder : Json.Decoder (Maybe String)
stateDecoder =
    Json.maybe <| Json.field "state" Json.string


{-| Json decoder for an access token
-}
accessTokenDecoder : Json.Decoder Token
accessTokenDecoder =
    let
        mtoken =
            Json.map2 makeToken
                (Json.field "access_token" Json.string |> Json.map Just)
                (Json.field "token_type" Json.string)

        failUnless =
            Maybe.map Json.succeed >> Maybe.withDefault (Json.fail "can't decode token")
    in
        Json.andThen failUnless mtoken


{-| Json decoder for a refresh token
-}
refreshTokenDecoder : Json.Decoder (Maybe Token)
refreshTokenDecoder =
    Json.map2 makeToken
        (Json.maybe <| Json.field "refresh_token" Json.string)
        (Json.field "token_type" Json.string)


{-| Create a ResponseToken record from various parameters
-}
makeResponseToken : Token -> Maybe Int -> Maybe Token -> Maybe (List String) -> Maybe String -> ResponseToken
makeResponseToken token expiresIn refreshToken scope state =
    { token = token
    , expiresIn = expiresIn
    , refreshToken = refreshToken
    , scope = Maybe.withDefault [] scope
    , state = state
    }


{-| Create a Token from a value and token type. Note that only bearer token are supported
-}
makeToken : Maybe String -> String -> Maybe Token
makeToken mtoken tokenType =
    case ( mtoken, String.toLower tokenType ) of
        ( Just token, "bearer" ) ->
            Just <| Bearer token

        _ ->
            Nothing


{-| A json decoder for JWT
-}
jwtPayloadDecoder : Json.Decoder ResponseToken
jwtPayloadDecoder =
    Json.maybe (Json.field "exp" Json.int)
        |> Json.andThen
            (\exp -> Json.succeed <| ResponseToken exp Nothing [] Nothing (Bearer ""))


{-| Parse a json JWT payload
-}
decodeJWTPayloadString : String -> Result String ResponseToken
decodeJWTPayloadString =
    Json.decodeString jwtPayloadDecoder
