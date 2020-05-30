module Internal exposing (AuthenticationError, AuthenticationSuccess, Authorization, AuthorizationError, RequestParts, ResponseType(..), authenticationErrorDecoder, authenticationSuccessDecoder, authorizationErrorParser, decoderFromJust, decoderFromResult, errorDecoder, errorDescriptionDecoder, errorDescriptionParser, errorParser, errorUriDecoder, errorUriParser, expiresInDecoder, expiresInParser, extractTokenString, lenientScopeDecoder, makeAuthorizationUrl, makeHeaders, makeRedirectUri, makeRequest, parseUrlQuery, protocolToString, refreshTokenDecoder, responseTypeToString, scopeDecoder, scopeParser, spaceSeparatedListParser, stateParser, tokenDecoder, tokenParser, urlAddList, urlAddMaybe)

import Base64.Encode as Base64
import Http as Http
import Json.Decode as Json
import OAuth exposing (..)
import Url exposing (Protocol(..), Url)
import Url.Builder as Builder exposing (QueryParameter)
import Url.Parser as Url
import Url.Parser.Query as Query



--
-- Json Decoders
--


{-| Json decoder for a response. You may provide a custom response decoder using other decoders
from this module, or some of your own craft.
-}
authenticationSuccessDecoder : Json.Decoder AuthenticationSuccess
authenticationSuccessDecoder =
    Json.map4 AuthenticationSuccess
        tokenDecoder
        refreshTokenDecoder
        expiresInDecoder
        scopeDecoder


authenticationErrorDecoder : Json.Decoder e -> Json.Decoder (AuthenticationError e)
authenticationErrorDecoder errorCodeDecoder =
    Json.map3 AuthenticationError
        errorCodeDecoder
        errorDescriptionDecoder
        errorUriDecoder


{-| Json decoder for an expire timestamp
-}
expiresInDecoder : Json.Decoder (Maybe Int)
expiresInDecoder =
    Json.maybe <| Json.field "expires_in" Json.int


{-| Json decoder for a scope
-}
scopeDecoder : Json.Decoder (List String)
scopeDecoder =
    Json.map (Maybe.withDefault []) <| Json.maybe <| Json.field "scope" (Json.list Json.string)


{-| Json decoder for a scope, allowing comma- or space-separated scopes
-}
lenientScopeDecoder : Json.Decoder (List String)
lenientScopeDecoder =
    Json.map (Maybe.withDefault []) <|
        Json.maybe <|
            Json.field "scope" <|
                Json.oneOf
                    [ Json.list Json.string
                    , Json.map (String.split ",") Json.string
                    ]


{-| Json decoder for an access token
-}
tokenDecoder : Json.Decoder Token
tokenDecoder =
    Json.andThen (decoderFromJust "missing or invalid 'access_token' / 'token_type'") <|
        Json.map2 makeToken
            (Json.field "token_type" Json.string |> Json.map Just)
            (Json.field "access_token" Json.string |> Json.map Just)


{-| Json decoder for a refresh token
-}
refreshTokenDecoder : Json.Decoder (Maybe Token)
refreshTokenDecoder =
    Json.andThen (decoderFromJust "missing or invalid 'refresh_token' / 'token_type'") <|
        Json.map2 makeRefreshToken
            (Json.field "token_type" Json.string)
            (Json.field "refresh_token" Json.string |> Json.maybe)


{-| Json decoder for 'error' field
-}
errorDecoder : (String -> a) -> Json.Decoder a
errorDecoder errorCodeFromString =
    Json.map errorCodeFromString <| Json.field "error" Json.string


{-| Json decoder for 'error\_description' field
-}
errorDescriptionDecoder : Json.Decoder (Maybe String)
errorDescriptionDecoder =
    Json.maybe <| Json.field "error_description" Json.string


{-| Json decoder for 'error\_uri' field
-}
errorUriDecoder : Json.Decoder (Maybe String)
errorUriDecoder =
    Json.maybe <| Json.field "error_uri" Json.string


{-| Combinator for JSON decoders to extract values from a `Maybe` or fail
with the given message (when `Nothing` is encountered)
-}
decoderFromJust : String -> Maybe a -> Json.Decoder a
decoderFromJust msg =
    Maybe.map Json.succeed >> Maybe.withDefault (Json.fail msg)


{-| Combinator for JSON decoders to extact values from a `Result _ _` or fail
with an appropriate message
-}
decoderFromResult : Result String a -> Json.Decoder a
decoderFromResult res =
    case res of
        Err msg ->
            Json.fail msg

        Ok a ->
            Json.succeed a



--
-- Query Parsers
--


authorizationErrorParser : e -> Query.Parser (AuthorizationError e)
authorizationErrorParser errorCode =
    Query.map3 (AuthorizationError errorCode)
        errorDescriptionParser
        errorUriParser
        stateParser


tokenParser : Query.Parser (Maybe Token)
tokenParser =
    Query.map2 makeToken
        (Query.string "token_type")
        (Query.string "access_token")


errorParser : (String -> e) -> Query.Parser (Maybe e)
errorParser errorCodeFromString =
    Query.map (Maybe.map errorCodeFromString)
        (Query.string "error")


expiresInParser : Query.Parser (Maybe Int)
expiresInParser =
    Query.int "expires_in"


scopeParser : Query.Parser (List String)
scopeParser =
    spaceSeparatedListParser "scope"


stateParser : Query.Parser (Maybe String)
stateParser =
    Query.string "state"


errorDescriptionParser : Query.Parser (Maybe String)
errorDescriptionParser =
    Query.string "error_description"


errorUriParser : Query.Parser (Maybe String)
errorUriParser =
    Query.string "error_uri"


spaceSeparatedListParser : String -> Query.Parser (List String)
spaceSeparatedListParser param =
    Query.map
        (\s ->
            case s of
                Nothing ->
                    []

                Just str ->
                    String.split " " str
        )
        (Query.string param)


urlAddList : String -> List String -> List QueryParameter -> List QueryParameter
urlAddList param xs qs =
    qs
        ++ (case xs of
                [] ->
                    []

                _ ->
                    [ Builder.string param (String.join " " xs) ]
           )


urlAddMaybe : String -> Maybe String -> List QueryParameter -> List QueryParameter
urlAddMaybe param ms qs =
    qs
        ++ (case ms of
                Nothing ->
                    []

                Just s ->
                    [ Builder.string param s ]
           )



--
-- Smart Constructors
--


makeAuthorizationUrl : ResponseType -> Authorization -> Url
makeAuthorizationUrl responseType { clientId, url, redirectUri, scope, state, codeChallenge } =
    let
        query =
            [ Builder.string "client_id" clientId
            , Builder.string "redirect_uri" (makeRedirectUri redirectUri)
            , Builder.string "response_type" (responseTypeToString responseType)
            ]
                |> urlAddList "scope" scope
                |> urlAddMaybe "state" state
                |> urlAddMaybe "code_challenge" codeChallenge
                |> urlAddMaybe "code_challenge_method"
                    (Maybe.map (always "S256") codeChallenge)
                |> Builder.toQuery
                |> String.dropLeft 1
    in
    case url.query of
        Nothing ->
            { url | query = Just query }

        Just baseQuery ->
            { url | query = Just (baseQuery ++ "&" ++ query) }


makeRequest : (Result Http.Error AuthenticationSuccess -> msg) -> Url -> List Http.Header -> String -> RequestParts msg
makeRequest toMsg url headers body =
    { method = "POST"
    , headers = headers
    , url = Url.toString url
    , body = Http.stringBody "application/x-www-form-urlencoded" body
    , expect = Http.expectJson toMsg authenticationSuccessDecoder
    , timeout = Nothing
    , tracker = Nothing
    }


makeHeaders : Maybe { clientId : String, secret : String } -> List Http.Header
makeHeaders credentials =
    credentials
        |> Maybe.map (\{ clientId, secret } -> Base64.encode <| Base64.string <| (clientId ++ ":" ++ secret))
        |> Maybe.map (\s -> [ Http.header "Authorization" ("Basic " ++ s) ])
        |> Maybe.withDefault []


makeRedirectUri : Url -> String
makeRedirectUri url =
    String.concat
        [ protocolToString url.protocol
        , "://"
        , url.host
        , Maybe.withDefault "" (Maybe.map (\i -> ":" ++ String.fromInt i) url.port_)
        , url.path
        , Maybe.withDefault "" (Maybe.map (\q -> "?" ++ q) url.query)
        ]



--
-- String utilities
--


{-| Gets the `String` representation of a `ResponseType`.
-}
responseTypeToString : ResponseType -> String
responseTypeToString r =
    case r of
        Code ->
            "code"

        Token ->
            "token"


{-| Gets the `String` representation of an `Protocol`
-}
protocolToString : Protocol -> String
protocolToString protocol =
    case protocol of
        Http ->
            "http"

        Https ->
            "https"



--
-- Utils
--


parseUrlQuery : Url -> a -> Query.Parser a -> a
parseUrlQuery url def parser =
    Maybe.withDefault def <| Url.parse (Url.query parser) url


{-| Extracts the intrinsic value of a `Token`. Careful with this, we don't have
access to the `Token` constructors, so it's a bit Houwje-Touwje
-}
extractTokenString : Token -> String
extractTokenString =
    tokenToString >> String.dropLeft 7


{-| Describes the desired type of response to an authorization. Use `Code` to ask for an
authorization code and continue with the according flow. Use `Token` to do an implicit
authentication and directly retrieve a `Token` from the authorization.
-}
type ResponseType
    = Code
    | Token



--
-- Record Alias Re-Definition
--


type alias RequestParts a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Expect a
    , timeout : Maybe Float
    , tracker : Maybe String
    }


type alias Authorization =
    { clientId : String
    , url : Url
    , redirectUri : Url
    , scope : List String
    , state : Maybe String
    , codeChallenge : Maybe String
    }


type alias AuthorizationError e =
    { error : e
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


type alias AuthenticationSuccess =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    }


type alias AuthenticationError e =
    { error : e
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }
