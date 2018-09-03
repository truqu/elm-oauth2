module Internal exposing (AuthenticationError, AuthenticationSuccess, Authorization, AuthorizationError, RequestParts, ResponseType(..), TokenString, TokenType, authenticationErrorDecoder, authenticationSuccessDecoder, authorizationErrorParser, decoderFromJust, decoderFromResult, errorDecoder, errorDescriptionDecoder, errorDescriptionParser, errorParser, errorUriDecoder, errorUriParser, expiresInDecoder, expiresInParser, extractTokenString, lenientScopeDecoder, makeAuthUrl, makeHeaders, makeRedirectUri, makeRefreshToken, makeRequest, makeToken, maybeAndThen2, parseUrlQuery, protocolToString, refreshTokenDecoder, responseTypeToString, scopeDecoder, scopeParser, spaceSeparatedListParser, stateDecoder, stateParser, tokenDecoder, tokenParser, urlAddList, urlAddMaybe)

import Base64
import Http as Http
import Json.Decode as Json
import OAuth exposing (..)
import Url exposing (Protocol(..), Url)
import Url.Builder as Builder exposing (QueryParameter)
import Url.Parser as Url
import Url.Parser.Query as Query


{-| Parts required to build a request. This record is given to `Http.request` in order
to create a new request and may be adjusted at will.
-}
type alias RequestParts a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Expect a
    , timeout : Maybe Float
    , withCredentials : Bool
    }


{-| Request configuration for an authorization (Authorization Code & Implicit flows)
-}
type alias Authorization =
    { clientId : String
    , url : Url
    , redirectUri : Url
    , scope : List String
    , state : Maybe String
    }


{-| Describes an OAuth error as a result of an authorization request failure

  - error (_REQUIRED_):
    A single ASCII error code.

  - errorDescription (_OPTIONAL_)
    Human-readable ASCII text providing additional information, used to assist the client developer in
    understanding the error that occurred. Values for the `errorDescription` parameter MUST NOT
    include characters outside the set `%x20-21 / %x23-5B / %x5D-7E`.

  - errorUri (_OPTIONAL_):
    A URI identifying a human-readable web page with information about the error, used to
    provide the client developer with additional information about the error. Values for the
    `errorUri` parameter MUST conform to the URI-reference syntax and thus MUST NOT include
    characters outside the set `%x21 / %x23-5B / %x5D-7E`.

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationError e =
    { error : e
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


{-| The response obtained as a result of an authentication (implicit or not)

  - token (_REQUIRED_):
    The access token issued by the authorization server.

  - refreshToken (_OPTIONAL_):
    The refresh token, which can be used to obtain new access tokens using the same authorization
    grant as described in [Section 6](https://tools.ietf.org/html/rfc6749#section-6).

  - expiresIn (_RECOMMENDED_):
    The lifetime in seconds of the access token. For example, the value "3600" denotes that the
    access token will expire in one hour from the time the response was generated. If omitted, the
    authorization server SHOULD provide the expiration time via other means or document the default
    value.

  - scope (_OPTIONAL, if identical to the scope requested; otherwise, REQUIRED_):
    The scope of the access token as described by [Section 3.3](https://tools.ietf.org/html/rfc6749#section-3.3).

-}
type alias AuthenticationSuccess =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    }


{-| Describes an OAuth error as a result of a request failure

  - error (_REQUIRED_):
    A single ASCII error code.

  - errorDescription (_OPTIONAL_)
    Human-readable ASCII text providing additional information, used to assist the client developer in
    understanding the error that occurred. Values for the `errorDescription` parameter MUST NOT
    include characters outside the set `%x20-21 / %x23-5B / %x5D-7E`.

  - errorUri (_OPTIONAL_):
    A URI identifying a human-readable web page with information about the error, used to
    provide the client developer with additional information about the error. Values for the
    `errorUri` parameter MUST conform to the URI-reference syntax and thus MUST NOT include
    characters outside the set `%x21 / %x23-5B / %x5D-7E`.

-}
type alias AuthenticationError e =
    { error : e
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }


{-| Describes the desired type of response to an authorization. Use `Code` to ask for an
authorization code and continue with the according flow. Use `Token` to do an implicit
authentication and directly retrieve a `Token` from the authorization.
-}
type ResponseType
    = Code
    | Token



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


{-| Json decoder for a state
-}
stateDecoder : Json.Decoder (Maybe String)
stateDecoder =
    Json.maybe <| Json.field "state" Json.string


{-| Json decoder for an access token
-}
tokenDecoder : Json.Decoder Token
tokenDecoder =
    Json.andThen decoderFromResult <|
        Json.map2 makeToken
            (Json.field "token_type" Json.string |> Json.map Just)
            (Json.field "access_token" Json.string |> Json.map Just)


{-| Json decoder for a refresh token
-}
refreshTokenDecoder : Json.Decoder (Maybe Token)
refreshTokenDecoder =
    Json.andThen decoderFromResult <|
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



--
-- Query Parsers
--


authorizationErrorParser : e -> Query.Parser (AuthorizationError e)
authorizationErrorParser errorCode =
    Query.map3 (AuthorizationError errorCode)
        errorDescriptionParser
        errorUriParser
        stateParser


tokenParser : Query.Parser (Result String Token)
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
    Query.map (\s -> Maybe.withDefault "" s |> String.split " ") (Query.string param)



--
-- Smart Constructors
--


makeAuthUrl : ResponseType -> Authorization -> Url
makeAuthUrl responseType { clientId, url, redirectUri, scope, state } =
    let
        query =
            [ Builder.string "client_id" clientId
            , Builder.string "redirect_uri" (makeRedirectUri redirectUri)
            , Builder.string "response_type" (responseTypeToString responseType)
            ]
                |> urlAddList "scope" scope
                |> urlAddMaybe "state" state
                |> Builder.toQuery
                |> String.dropLeft 1
    in
    case url.query of
        Nothing ->
            { url | query = Just query }

        Just baseQuery ->
            { url | query = Just (baseQuery ++ "&" ++ query) }


makeRequest : Url -> List Http.Header -> String -> RequestParts AuthenticationSuccess
makeRequest url headers body =
    { method = "POST"
    , headers = headers
    , url = Url.toString url
    , body = Http.stringBody "application/x-www-form-urlencoded" body
    , expect = Http.expectJson authenticationSuccessDecoder
    , timeout = Nothing
    , withCredentials = False
    }


makeHeaders : Maybe { clientId : String, secret : String } -> List Http.Header
makeHeaders credentials =
    credentials
        |> Maybe.map (\{ clientId, secret } -> Base64.encode (clientId ++ ":" ++ secret))
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


type alias TokenType =
    String


type alias TokenString =
    String


makeToken : Maybe TokenType -> Maybe TokenString -> Result String Token
makeToken mTokenType mToken =
    let
        construct a b =
            tokenFromString (a ++ " " ++ b)
    in
    case maybeAndThen2 construct mTokenType mToken of
        Just token ->
            Ok <| token

        _ ->
            Err "missing or invalid combination of 'access_token' and 'token_type' field(s)"


makeRefreshToken : TokenType -> Maybe TokenString -> Result String (Maybe Token)
makeRefreshToken tokenType mToken =
    let
        construct a b =
            tokenFromString (a ++ " " ++ b)
    in
    case ( mToken, maybeAndThen2 construct (Just tokenType) mToken ) of
        ( Nothing, _ ) ->
            Ok <| Nothing

        ( _, Just token ) ->
            Ok <| Just token

        _ ->
            Err "missing or invalid combination of 'refresh_token' and 'token_type' field(s)"



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


maybeAndThen2 : (a -> b -> Maybe c) -> Maybe a -> Maybe b -> Maybe c
maybeAndThen2 fn ma mb =
    Maybe.andThen identity (Maybe.map2 fn ma mb)


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


parseUrlQuery : Url -> a -> Query.Parser a -> a
parseUrlQuery url def parser =
    Maybe.withDefault def <| Url.parse (Url.query parser) url


{-| Extracts the intrinsic value of a `Token`. Careful with this, we don't have
access to the `Token` constructors, so it's a bit Houwje-Touwje
-}
extractTokenString : Token -> String
extractTokenString =
    tokenToString >> String.dropLeft 7


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
