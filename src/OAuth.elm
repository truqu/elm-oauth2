module OAuth exposing
    ( Token, useToken, tokenToString, tokenFromString
    , ErrorCode(..), errorCodeToString, errorCodeFromString
    , TokenType, TokenString, makeToken, makeRefreshToken
    , defaultAuthenticationSuccessDecoder, customAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder
    , defaultExpiresInDecoder, defaultScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder
    , RequestParts, AuthenticationSuccess(..), DefaultFields, Default(..), AuthenticationError, AuthorizationError
    , defaultFields, extraFields
    , lenientScopeDecoder
    )

{-| Utility library to manage client-side OAuth 2.0 authentications

The library contains a main OAuth module exposing types used accross other modules. In practice,
you'll only need to use one of the additional modules:

  - OAuth.AuthorizationCode: The authorization code grant type is used to obtain both access tokens
    and refresh tokens via a redirection-based flow and is optimized for confidential clients
    [4.1](https://tools.ietf.org/html/rfc6749#section-4.1).

  - OAuth.AuthorizationCode.PKCE: An extension of the original OAuth 2.0 specification to mitigate
    authorization code interception attacks through the use of Proof Key for Code Exchange (PKCE).

  - OAuth.Implicit: The implicit grant type is used to obtain access tokens (it does not support the
    issuance of refresh tokens) and is optimized for public clients known to operate a particular
    redirection URI [4.2](https://tools.ietf.org/html/rfc6749#section-4.2).

  - OAuth.Password: The resource owner password credentials grant type is suitable in cases where the
    resource owner has a trust relationship with the client, such as the device operating system or a
    highly privileged application [4.3](https://tools.ietf.org/html/rfc6749#section-4.3)

  - OAuth.ClientCredentials: The client can request an access token using only its client credentials
    (or other supported means of authentication) when the client is requesting access to the protected
    resources under its control, or those of another resource owner that have been previously arranged
    with the authorization server (the method of which is beyond the scope of this specification)
    [4.4](https://tools.ietf.org/html/rfc6749#section-4.3).

In practice, you most probably want to use the _OAuth.Implicit_ module which is the most commonly
used.


## Token

@docs Token, useToken, tokenToString, tokenFromString


## ErrorCode

@docs ErrorCode, errorCodeToString, errorCodeFromString


## Decoders & Parsers Utils (advanced)

@docs TokenType, TokenString, makeToken, makeRefreshToken


## JSON Decoders

@docs defaultAuthenticationSuccessDecoder, customAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder


## JSON Decoders (advanced)

@docs defaultExpiresInDecoder, defaultScopeDecoder, defaultLenientScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder


## Authenticate

@docs RequestParts, AuthenticationSuccess, DefaultFields, Default, AuthenticationError, AuthorizationError


## Helpers

@docs defaultFields, extraFields

-}

import Extra.Maybe as Maybe
import Http as Http
import Json.Decode as Json



--
-- Token
--


{-| Describes the type of access token to use.

  - Bearer: Utilized by simply including the access token string in the request
    [rfc6750](https://tools.ietf.org/html/rfc6750)

  - Mac: Not supported.

-}
type Token
    = Bearer String


{-| Alias for readability
-}
type alias TokenType =
    String


{-| Alias for readability
-}
type alias TokenString =
    String


{-| Use a token to authenticate a request.
-}
useToken : Token -> List Http.Header -> List Http.Header
useToken token =
    (::) (Http.header "Authorization" (tokenToString token))


{-| Create a token from two string representing a token type and
an actual token value. This is intended to be used in Json decoders
or Query parsers.

Returns `Nothing` when the token type is `Nothing`
, different from `Just "Bearer"` or when there's no token at all.

-}
makeToken : Maybe TokenType -> Maybe TokenString -> Maybe Token
makeToken =
    Maybe.andThen2 tryMakeToken


{-| See `makeToken`, with the subtle difference that a token value may or
may not be there.

Returns `Nothing` when the token type isn't `"Bearer"`.

Returns `Just Nothing` or `Just (Just token)` otherwise, depending on whether a token is
present or not.

-}
makeRefreshToken : TokenType -> Maybe TokenString -> Maybe (Maybe Token)
makeRefreshToken tokenType mToken =
    case ( mToken, Maybe.andThen2 tryMakeToken (Just tokenType) mToken ) of
        ( Nothing, _ ) ->
            Just Nothing

        ( _, Just token ) ->
            Just <| Just token

        _ ->
            Nothing


{-| Internal, attempt to make a Bearer token from a type and a token string
-}
tryMakeToken : TokenType -> TokenString -> Maybe Token
tryMakeToken tokenType token =
    case String.toLower tokenType of
        "bearer" ->
            Just (Bearer token)

        _ ->
            Nothing


{-| Get the `String` representation of a `Token` to be used in an 'Authorization' header
-}
tokenToString : Token -> String
tokenToString (Bearer t) =
    "Bearer " ++ t


{-| Parse a token from an 'Authorization' header string.

      tokenFromString (tokenToString token) == Just token

-}
tokenFromString : String -> Maybe Token
tokenFromString str =
    case ( String.left 6 str, String.dropLeft 7 str ) of
        ( "Bearer", t ) ->
            Just (Bearer t)

        _ ->
            Nothing



--
-- Error
--


{-| Describes an OAuth error response [4.1.2.1](https://tools.ietf.org/html/rfc6749#section-4.1.2.1)

  - InvalidRequest: The request is missing a required parameter, includes an invalid parameter value,
    includes a parameter more than once, or is otherwise malformed.

  - UnauthorizedClient: The client is not authorized to request an authorization code using this
    method.

  - AccessDenied: The resource owner or authorization server denied the request.

  - UnsupportedResponseType: The authorization server does not support obtaining an authorization code
    using this method.

  - InvalidScope: The requested scope is invalid, unknown, or malformed.

  - ServerError: The authorization server encountered an unexpected condition that prevented it from
    fulfilling the request. (This error code is needed because a 500 Internal Server Error HTTP status
    code cannot be returned to the client via an HTTP redirect.)

  - TemporarilyUnavailable: The authorization server is currently unable to handle the request due to
    a temporary overloading or maintenance of the server. (This error code is needed because a 503
    Service Unavailable HTTP status code cannot be returned to the client via an HTTP redirect.)

  - Custom: Encountered a 'free-string' or custom code not specified by the official RFC but returned
    by the authorization server.

-}
type ErrorCode
    = InvalidRequest
    | UnauthorizedClient
    | AccessDenied
    | UnsupportedResponseType
    | InvalidScope
    | ServerError
    | TemporarilyUnavailable
    | Custom String


{-| Get the `String` representation of an `ErrorCode`.
-}
errorCodeToString : ErrorCode -> String
errorCodeToString err =
    case err of
        InvalidRequest ->
            "invalid_request"

        UnauthorizedClient ->
            "unauthorized_client"

        AccessDenied ->
            "access_denied"

        UnsupportedResponseType ->
            "unsupported_response_type"

        InvalidScope ->
            "invalid_scope"

        ServerError ->
            "server_error"

        TemporarilyUnavailable ->
            "temporarily_unavailable"

        Custom str ->
            str


{-| Build a string back into an error code. Returns `Custom _`
when the string isn't recognized from the ones specified in the RFC
-}
errorCodeFromString : String -> ErrorCode
errorCodeFromString str =
    case str of
        "invalid_request" ->
            InvalidRequest

        "unauthorized_client" ->
            UnauthorizedClient

        "access_denied" ->
            AccessDenied

        "unsupported_response_type" ->
            UnsupportedResponseType

        "invalid_scope" ->
            InvalidScope

        "server_error" ->
            ServerError

        "temporarily_unavailable" ->
            TemporarilyUnavailable

        _ ->
            Custom str


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
    , tracker : Maybe String
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
type alias AuthorizationError =
    { error : ErrorCode
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
type AuthenticationSuccess extraFields
    = AuthenticationSuccess DefaultFields extraFields


type alias DefaultFields =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    }


{-| Placeholder used to mark the use of the default OAuth response as a result of an authorization.
Use this when you have no extra fields to decode from the Authorization Server.
-}
type Default
    = Default


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
type alias AuthenticationError =
    { error : ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }



--
-- Json Decoders
--


{-| Default Json decoder for a positive response.

    defaultAuthenticationSuccessDecoder : Decoder AuthenticationSuccess
    defaultAuthenticationSuccessDecoder =
        D.map4 AuthenticationSuccess
            tokenDecoder
            refreshTokenDecoder
            expiresInDecoder
            scopeDecoder

-}
defaultAuthenticationSuccessDecoder : Json.Decoder (AuthenticationSuccess Default)
defaultAuthenticationSuccessDecoder =
    authenticationSuccessDecoder defaultDecoder


defaultDecoder : Json.Decoder Default
defaultDecoder =
    Json.succeed Default


{-| Custom Json decoder for a positive response. You provide a custom response decoder for any extra fields using other decoders
from this module, or some of your own craft.

    extraFieldsDecoder : Decoder ExtraFields
    extraFieldsDecoder =
        D.map4 ExtraFields
            defaultTokenDecoder
            defaultRefreshTokenDecoder
            defaultExpiresInDecoder
            defaultScopeDecoder

-}
customAuthenticationSuccessDecoder : Json.Decoder extraFields -> Json.Decoder (AuthenticationSuccess extraFields)
customAuthenticationSuccessDecoder extraFieldsDecoder =
    authenticationSuccessDecoder extraFieldsDecoder


authenticationSuccessDecoder : Json.Decoder extraFields -> Json.Decoder (AuthenticationSuccess extraFields)
authenticationSuccessDecoder extraFieldsDecoder =
    Json.map2 AuthenticationSuccess
        defaultFieldsDecoder
        extraFieldsDecoder


defaultFieldsDecoder : Json.Decoder DefaultFields
defaultFieldsDecoder =
    Json.map4 DefaultFields
        defaultTokenDecoder
        defaultRefreshTokenDecoder
        defaultExpiresInDecoder
        defaultScopeDecoder


{-| Json decoder for an errored response.

    case res of
        Err (Http.BadStatus { body }) ->
            case Json.decodeString OAuth.AuthorizationCode.defaultAuthenticationErrorDecoder body of
                Ok { error, errorDescription } ->
                    doSomething

                _ ->
                    parserFailed

        _ ->
            someOtherError

-}
defaultAuthenticationErrorDecoder : Json.Decoder AuthenticationError
defaultAuthenticationErrorDecoder =
    authenticationErrorDecoder defaultErrorDecoder


authenticationErrorDecoder : Json.Decoder ErrorCode -> Json.Decoder AuthenticationError
authenticationErrorDecoder errorCodeDecoder =
    Json.map3 AuthenticationError
        errorCodeDecoder
        defaultErrorDescriptionDecoder
        defaultErrorUriDecoder


{-| Json decoder for an 'expire' timestamp
-}
defaultExpiresInDecoder : Json.Decoder (Maybe Int)
defaultExpiresInDecoder =
    Json.maybe <| Json.field "expires_in" Json.int


{-| Json decoder for a 'scope'
-}
defaultScopeDecoder : Json.Decoder (List String)
defaultScopeDecoder =
    Json.map (Maybe.withDefault []) <| Json.maybe <| Json.field "scope" (Json.list Json.string)


{-| Json decoder for a 'scope', allowing comma- or space-separated scopes
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


{-| Json decoder for an 'access\_token'
-}
defaultTokenDecoder : Json.Decoder Token
defaultTokenDecoder =
    Json.andThen (decoderFromJust "missing or invalid 'access_token' / 'token_type'") <|
        Json.map2 makeToken
            (Json.field "token_type" Json.string |> Json.map Just)
            (Json.field "access_token" Json.string |> Json.map Just)


{-| Json decoder for a 'refresh\_token'
-}
defaultRefreshTokenDecoder : Json.Decoder (Maybe Token)
defaultRefreshTokenDecoder =
    Json.andThen (decoderFromJust "missing or invalid 'refresh_token' / 'token_type'") <|
        Json.map2 makeRefreshToken
            (Json.field "token_type" Json.string)
            (Json.field "refresh_token" Json.string |> Json.maybe)


{-| Json decoder for 'error' field
-}
defaultErrorDecoder : Json.Decoder ErrorCode
defaultErrorDecoder =
    Json.map errorCodeFromString <| Json.field "error" Json.string


{-| Json decoder for 'error\_description' field
-}
defaultErrorDescriptionDecoder : Json.Decoder (Maybe String)
defaultErrorDescriptionDecoder =
    Json.maybe <| Json.field "error_description" Json.string


{-| Json decoder for 'error\_uri' field
-}
defaultErrorUriDecoder : Json.Decoder (Maybe String)
defaultErrorUriDecoder =
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
-- Helpers
--


defaultFields : AuthenticationSuccess extraFields -> DefaultFields
defaultFields (AuthenticationSuccess defaultFields_ _) =
    defaultFields_


extraFields : AuthenticationSuccess extraFields -> extraFields
extraFields (AuthenticationSuccess _ extraFields_) =
    extraFields_
