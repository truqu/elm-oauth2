module OAuth
    exposing
        ( Authorization
        , Authentication(..)
        , Credentials
        , Error(..)
        , ParseError(..)
        , ResponseType(..)
        , Response(..)
        , Token(..)
        , errorFromString
        , showResponseType
        , showToken
        , use
        )

{-| Utility library to manage client-side OAuth 2.0 authentications

The library contains a main OAuth module exposing types used accross other modules. In practice,
you'll only need tu use one of the additional modules:

  - OAuth.AuthorizationCode: The authorization code grant type is used to obtain both access tokens
    and refresh tokens via a redirection-based flow and is optimized for confidential clients [4.1](<https://tools.ietf.org/html/rfc6749#section-4.1>

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

In practice, you most probably want to use the *OAuth.Implicit* module which is the most commonly
used.


## Use a token

@docs use


## Requests

@docs Authorization, Authentication, Credentials, ResponseType, showResponseType


## Responses

@docs Response, Token, ParseError, Error, showToken, errorFromString

-}

import Http


{-| Request configuration for an authorization (Authorization Code & Implicit flows)
-}
type alias Authorization =
    { clientId : String
    , url : String
    , redirectUri : String
    , responseType : ResponseType
    , scope : List String
    , state : Maybe String
    }


{-| Request configuration for an authentication (Authorization Code, Password & Client Credentials
flows)
-}
type Authentication
    = AuthorizationCode
        { clientId : String
        , code : String
        , url : String
        , redirectUri : String
        , scope : List String
        , secret : Maybe String
        , state : Maybe String
        }
    | ClientCredentials
        { credentials : Credentials
        , url : String
        , scope : List String
        , state : Maybe String
        }
    | Password
        { credentials : Maybe Credentials
        , url : String
        , password : String
        , scope : List String
        , state : Maybe String
        , username : String
        }


{-| Describes a couple of client credentials used for Basic authentication
-}
type alias Credentials =
    { clientId : String, secret : String }


{-| Describes the desired type of response to an authorization. Use `Code` to ask for an
authorization code and continue with the according flow. Use `Token` to do an implicit
authentication and directly retrieve a `Token` from the authorization.
-}
type ResponseType
    = Code
    | Token


{-| The response obtained as a result of an authorization or authentication. `OkCode` can only be
encountered after an authorization.
-}
type Response
    = OkToken
        { expiresIn : Maybe Int
        , refreshToken : Maybe Token
        , scope : List String
        , state : Maybe String
        , token : Token
        }
    | OkCode
        { code : String
        , state : Maybe String
        }
    | Err
        { error : Error
        , errorDescription : String
        , errorUri : String
        , state : Maybe String
        }


{-| Describes errors coming from attempting to parse a url after an OAuth redirection

  - Empty: means there were nothing (related to OAuth 2.0) to parse
  - Missing: means the OAuth provider didn't with all the required parameters for the given grant type.
  - Invalid: means the OAuth provider did reply with an invalid parameter for the given grant type.

-}
type ParseError
    = Empty
    | Missing (List String)
    | Invalid (List String)


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

  - Unknown: The server returned an unknown error code.

-}
type Error
    = InvalidRequest
    | UnauthorizedClient
    | AccessDenied
    | UnsupportedResponseType
    | InvalidScope
    | ServerError
    | TemporarilyUnavailable
    | Unknown


{-| Describes the type of access token to use.

  - Bearer: Utilized by simply including the access token string in the request
    [rfc6750](https://tools.ietf.org/html/rfc6750)

  - Mac: Not yet supported.

-}
type Token
    = Bearer String


{-| Use a token to authenticate a request.

NOTE: This method is highly likely to change in the future with the introduction of `Mac` tokens

-}
use : Token -> List Http.Header -> List Http.Header
use token =
    (::) (Http.header "Authorization" (showToken token))


{-| Gets the `String` representation of a `ResponseType`.
-}
showResponseType : ResponseType -> String
showResponseType r =
    case r of
        Code ->
            "code"

        Token ->
            "token"


{-| Gets the `String` representation of a `Token`.

NOTE: This method is highly likely to change in the future with the introduction of `Mac` tokens

-}
showToken : Token -> String
showToken (Bearer t) =
    "Bearer " ++ t


{-| Attempt to parse a `String` into an `Error` code. Will parse to `Unknown` when the string
isn't recognized.
-}
errorFromString : String -> Error
errorFromString str =
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
            Unknown
