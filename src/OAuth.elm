module OAuth
    exposing
        ( Authorization
        , Authentication(..)
        , Credentials
        , ParseError(..)
        , ResponseType(..)
        , Response(..)
        , Token(..)
        , errorFromString
        , showResponseType
        , showToken
        )

import Http
import Time exposing (Time)


type alias Authorization =
    { clientId : String
    , endpoint : String
    , redirectUri : String
    , responseType : ResponseType
    , scope : List String
    , state : Maybe String
    }


type Authentication
    = AuthorizationCode
        { clientId : String
        , code : String
        , endpoint : String
        , redirectUri : String
        , scope : List String
        , secret : Maybe String
        , state : Maybe String
        }
    | ClientCredentials
        { clientId : String
        , endpoint : String
        , scope : List String
        , secret : String
        , state : Maybe String
        }
    | Password
        { credentials : Maybe Credentials
        , endpoint : String
        , password : String
        , scope : List String
        , state : Maybe String
        , username : String
        }


type alias Credentials =
    { clientId : String, secret : String }


type ParseError
    = Empty
    | Missing (List String)
    | Invalid (List String)


type ResponseType
    = AuthorizationCodeR
    | TokenR


type Response
    = Token
        { expiresIn : Maybe Int
        , refreshToken : Maybe Token
        , scope : List String
        , state : Maybe String
        , token : Token
        }
    | Code
        { code : String
        , state : Maybe String
        }
    | Err
        { error : Error
        , errorDescription : String
        , errorUri : String
        , state : Maybe String
        }


type Error
    = InvalidRequest
    | UnauthorizedClient
    | AccessDenied
    | UnsupportedResponseType
    | InvalidScope
    | ServerError
    | TemporarilyUnavailable
    | Unknown


type Token
    = Bearer String


request :
    Token
    ->
        { method : String
        , headers : List Http.Header
        , url : String
        , body : Http.Body
        , expect : Http.Expect a
        , timeout : Maybe Time
        , withCredentials : Bool
        }
    -> Http.Request a
request token ({ headers } as req) =
    Http.request { req | headers = (Http.header "Authorization" (showToken token) :: headers) }


showResponseType : ResponseType -> String
showResponseType r =
    case r of
        AuthorizationCodeR ->
            "code"

        TokenR ->
            "token"


showToken : Token -> String
showToken (Bearer t) =
    "Bearer " ++ t


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
