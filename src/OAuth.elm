module OAuth exposing
    ( use
    , Authorization, Authentication(..), Credentials, ResponseType(..), showResponseType
    , ResponseToken, ResponseCode, Token(..), Err, ParseErr(..), ErrCode(..), showToken, showErrCode, errCodeFromString, errDecoder
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


## Use a token

@docs use


## Requests

@docs Authorization, Authentication, Credentials, ResponseType, showResponseType


## Responses

@docs ResponseToken, ResponseCode, Token, Err, ParseErr, ErrCode, showToken, showErrCode, errCodeFromString, errDecoder

-}

import Http
import Json.Decode as Json


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

    -- AuthorizationCode
    let req = OAuth.AuthorizationCode
          { credentials =
              -- Only the clientId is required. Specify a secret
              -- if a Basic OAuth is required by the resource
              -- provider
              { clientId = "<my-client-id>"
              , secret = ""
              }
          -- Authorization code from the authorization result
          , code = "<authorization-code>"
          -- Token endpoint of the resource provider
          , url = "<token-endpoint>"
          -- Redirect Uri to your webserver
          , redirectUri = "<my-web-server>"
          -- Scopes requested, can be empty
          , scope = ["read:whatever"]
          -- A state, echoed back by the resource provider
          , state = Just "whatever"
          }

    -- ClientCredentials
    let req = OAuth.ClientCredentials
          { credentials =
              -- Credentials passed along via Basic auth
              { clientId = "<my-client-id>"
              , secret = "<my-client-secret>"
              }
          -- Token endpoint of the resource provider
          , url = "<token-endpoint>"
          -- Scopes requested, can be empty
          , scope = ["read:whatever"]
          -- A state, echoed back by the resource provider
          , state = Just "whatever"
          }

    -- Password
    let req = OAuth.Password
          { credentials = Just
              -- Optional, unless required by the resource provider
              { clientId = "<my-client-id>"
              , secret = "<my-client-secret>"
              }
          -- Resource owner's password
          , password = "<user-password>"
          -- Scopes requested, can be empty
          , scope = ["read:whatever"]
          -- A state, echoed back by the resource provider
          , state = Just "whatever"
          -- Token endpoint of the resource provider
          , url = "<token-endpoint>"
          -- Resource owner's username
          , username = "<user-username>"
          }

    -- Refresh
    let req = OAuth.Refresh
          -- Optional, unless required by the resource provider
          { credentials = Nothing
          -- Scopes requested, can be empty
          , scope = ["read:whatever"]
          -- A refresh token previously delivered
          , token = OAuth.Bearer "abcdef1234567890"
          -- Token endpoint of the resource provider
          , url = "<token-endpoint>"
          }

-}
type Authentication
    = AuthorizationCode
        { credentials : Credentials
        , code : String
        , redirectUri : String
        , scope : List String
        , state : Maybe String
        , url : String
        }
    | ClientCredentials
        { credentials : Credentials
        , scope : List String
        , state : Maybe String
        , url : String
        }
    | Password
        { credentials : Maybe Credentials
        , password : String
        , scope : List String
        , state : Maybe String
        , url : String
        , username : String
        }
    | Refresh
        { credentials : Maybe Credentials
        , token : Token
        , scope : List String
        , url : String
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


{-| The response obtained as a result of an authentication (implicit or not)

  - expiresIn (_RECOMMENDED_):
    The lifetime in seconds of the access token. For example, the value "3600" denotes that the
    access token will expire in one hour from the time the response was generated. If omitted, the
    authorization server SHOULD provide the expiration time via other means or document the default
    value.

  - refreshToken (_OPTIONAL_):
    The refresh token, which can be used to obtain new access tokens using the same authorization
    grant as described in [Section 6](https://tools.ietf.org/html/rfc6749#section-6).

  - scope (_OPTIONAL, if identical to the scope requested; otherwise, REQUIRED_):
    The scope of the access token as described by [Section 3.3](https://tools.ietf.org/html/rfc6749#section-3.3).

  - state (_REQUIRED if `state` was present in the authentication request_):
    The exact value received from the client

  - token (_REQUIRED_):
    The access token issued by the authorization server.

-}
type alias ResponseToken =
    { expiresIn : Maybe Int
    , refreshToken : Maybe Token
    , scope : List String
    , state : Maybe String
    , token : Token
    }


{-| The response obtained as a result of an authorization

  - code (_REQUIRED_):
    The authorization code generated by the authorization server. The authorization code MUST expire
    shortly after it is issued to mitigate the risk of leaks. A maximum authorization code lifetime of
    10 minutes is RECOMMENDED. The client MUST NOT use the authorization code more than once. If an
    authorization code is used more than once, the authorization server MUST deny the request and
    SHOULD revoke (when possible) all tokens previously issued based on that authorization code. The
    authorization code is bound to the client identifier and redirection URI.

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias ResponseCode =
    { code : String
    , state : Maybe String
    }


{-| Describes errors coming from attempting to parse a url after an OAuth redirection

  - Empty: means there were nothing (related to OAuth 2.0) to parse
  - OAuthErr: a successfully parsed OAuth 2.0 error
  - Missing: means the OAuth provider didn't with all the required parameters for the given grant type.
  - Invalid: means the OAuth provider did reply with an invalid parameter for the given grant type.
  - FailedToParse: means that the given URL is badly constructed

-}
type ParseErr
    = Empty
    | OAuthErr Err
    | Missing (List String)
    | Invalid (List String)
    | FailedToParse


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

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias Err =
    { error : ErrCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


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
type ErrCode
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
-}
showToken : Token -> String
showToken (Bearer t) =
    "Bearer " ++ t


{-| Gets the `String` representation of an `ErrCode`.
-}
showErrCode : ErrCode -> String
showErrCode err =
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

        Unknown ->
            "unknown"


{-| Attempts to parse a `String` into an `ErrCode` code. Will parse to `Unknown` when the string
isn't recognized.
-}
errCodeFromString : String -> ErrCode
errCodeFromString str =
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


{-| A json decoder for response error carried by the `Result Http.Error OAuth.ResponseToken` result of
an http call.
-}
errDecoder : Json.Decoder Err
errDecoder =
    Json.map4
        (\error errorUri errorDescription state ->
            { error = error
            , errorUri = errorUri
            , errorDescription = errorDescription
            , state = state
            }
        )
        (Json.map errCodeFromString <| Json.field "error" Json.string)
        (Json.maybe <| Json.field "error_uri" Json.string)
        (Json.maybe <| Json.field "error_description" Json.string)
        (Json.maybe <| Json.field "state" Json.string)
