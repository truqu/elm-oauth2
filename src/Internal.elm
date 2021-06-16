module Internal exposing (Authorization, ResponseType(..), authorizationErrorParser, defaultDecoder, errorDescriptionParser, errorParser, errorUriParser, expiresInParser, extractTokenString, makeAuthorizationUrl, makeHeaders, makeRedirectUri, makeRequest, parseUrlQuery, protocolToString, responseTypeToString, scopeParser, spaceSeparatedListParser, stateParser, tokenParser, urlAddList, urlAddMaybe)

import Base64.Encode as Base64
import Http as Http
import Json.Decode as Json
import OAuth exposing (AuthenticationError, AuthenticationSuccess, AuthorizationError, Default, DefaultFields, ErrorCode, RequestParts, Token, customAuthenticationSuccessDecoder, makeToken, tokenToString)
import Url exposing (Protocol(..), Url)
import Url.Builder as Builder exposing (QueryParameter)
import Url.Parser as Url
import Url.Parser.Query as Query



--
-- Decoders
--


defaultDecoder : Json.Decoder Default
defaultDecoder =
    Json.succeed OAuth.Default



--
-- Query Parsers
--


authorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
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


makeRequest : Json.Decoder extraFields -> (Result Http.Error (AuthenticationSuccess extraFields) -> msg) -> Url -> List Http.Header -> String -> RequestParts msg
makeRequest extraFieldsDecoder toMsg url headers body =
    { method = "POST"
    , headers = headers
    , url = Url.toString url
    , body = Http.stringBody "application/x-www-form-urlencoded" body
    , expect = Http.expectJson toMsg (customAuthenticationSuccessDecoder extraFieldsDecoder)
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


type alias Authorization =
    { clientId : String
    , url : Url
    , redirectUri : Url
    , scope : List String
    , state : Maybe String
    , codeChallenge : Maybe String
    }
