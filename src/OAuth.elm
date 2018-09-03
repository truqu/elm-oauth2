module OAuth exposing
    ( Token, useToken
    , ErrorCode(..), errorCodeToString, errorCodeFromString
    , tokenFromString, tokenToString
    )

{-| Utility library to manage client-side OAuth 2.0 authentications

The library contains a main OAuth module exposing types used accross other modules. In practice,
you'll only need tu use one of the additional modules:

  - OAuth.AuthorizationCode: The authorization code grant type is used to obtain both access tokens
    and refresh tokens via a redirection-based flow and is optimized for confidential clients
    [4.1](https://tools.ietf.org/html/rfc6749#section-4.1).

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

@docs Token, useToken, tokenToString. tokenFromString


## ErrorCode

@docs ErrorCode, errorCodeToString, errorCodeFromString

-}

import Http as Http



--
-- Token
--


{-| Describes the type of access token to use.

  - Bearer: Utilized by simply including the access token string in the request
    [rfc6750](https://tools.ietf.org/html/rfc6750)

  - Mac: Not yet supported.

-}
type Token
    = Bearer String


{-| Use a token to authenticate a request.
-}
useToken : Token -> List Http.Header -> List Http.Header
useToken token =
    (::) (Http.header "Authorization" (tokenToString token))



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



--
-- String Utilities
--


{-| Gets the `String` representation of a `Token` to be used in an 'Authorization' header
-}
tokenToString : Token -> String
tokenToString (Bearer t) =
    "Bearer " ++ t


{-| Gets the `String` representation of an `ErrorCode`.
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



--
-- (Smart) Constructors
--


tokenFromString : String -> Maybe Token
tokenFromString str =
    case ( String.left 6 str, String.dropLeft 7 str ) of
        ( "Bearer", t ) ->
            Just (Bearer t)

        _ ->
            Nothing


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
