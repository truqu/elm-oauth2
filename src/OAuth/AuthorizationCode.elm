module OAuth.AuthorizationCode exposing
    ( makeAuthorizationUrl, Authorization, parseCode, AuthorizationResult, AuthorizationError, AuthorizationSuccess, AuthorizationCode
    , makeTokenRequest, Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts
    , defaultAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder
    , makeAuthorizationUrlWith, AuthorizationResultWith(..)
    , makeTokenRequestWith
    , defaultExpiresInDecoder, defaultScopeDecoder, lenientScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder
    , parseCodeWith, Parsers, defaultParsers, defaultCodeParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser
    )

{-| The authorization code grant type is used to obtain both access
tokens and refresh tokens and is optimized for confidential clients.
Since this is a redirection-based flow, the client must be capable of
interacting with the resource owner's user-agent (typically a web
browser) and capable of receiving incoming requests (via redirection)
from the authorization server.

       +---------+                                +--------+
       |         |---(A)- Auth Redirection ------>|        |
       |         |                                |  Auth  |
       | Browser |                                | Server |
       |         |                                |        |
       |         |<--(B)- Redirection Callback ---|        |
       +---------+          (w/ Auth Code)        +--------+
         ^     |                                    ^    |
         |     |                                    |    |
        (A)   (B)                                   |    |
         |     |                                    |    |
         |     v                                    |    |
       +---------+                                  |    |
       |         |----(C)---- Auth Code ------------+    |
       | Elm App |                                       |
       |         |                                       |
       |         |<---(D)------ Access Token ------------+
       +---------+       (w/ Optional Refresh Token)

  - (A) The client initiates the flow by directing the resource owner's
    user-agent to the authorization endpoint.

  - (B) Assuming the resource owner grants access, the authorization
    server redirects the user-agent back to the client including an
    authorization code and any local state provided by the client
    earlier.

  - (C) The client requests an access token from the authorization
    server's token endpoint by including the authorization code
    received in the previous step.

  - (D) The authorization server authenticates the client and validates
    the authorization code. If valid, the authorization server responds
    back with an access token and, optionally, a refresh token.

After those steps, the client owns a `Token` that can be used to authorize any subsequent
request.


## Authorize

@docs makeAuthorizationUrl, Authorization, parseCode, AuthorizationResult, AuthorizationError, AuthorizationSuccess, AuthorizationCode


## Authenticate

@docs makeTokenRequest, Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts


## JSON Decoders

@docs defaultAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder


## Custom Decoders & Parsers (advanced)


### Authorize

@docs makeAuthorizationUrlWith, AuthorizationResultWith


### Authenticate

@docs makeTokenRequestWith


### Json Decoders

@docs defaultExpiresInDecoder, defaultScopeDecoder, lenientScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder


### Query Parsers

@docs parseCodeWith, Parsers, defaultParsers, defaultCodeParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser

-}

import Dict as Dict exposing (Dict)
import Http
import Internal as Internal exposing (..)
import Json.Decode as Json
import OAuth exposing (ErrorCode, GrantType(..), ResponseType(..), Token, errorCodeFromString, grantTypeToString)
import Url exposing (Url)
import Url.Builder as Builder
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query



--
-- Authorize
--


{-| Request configuration for an authorization (Authorization Code & Implicit flows)

  - clientId (_REQUIRED_):
    The client identifier issues by the authorization server via an off-band mechanism.

  - url (_REQUIRED_):
    The authorization endpoint to contact the authorization server.

  - redirectUri (_OPTIONAL_):
    After completing its interaction with the resource owner, the authorization
    server directs the resource owner's user-agent back to the client via this
    URL. May be already defined on the authorization server itself.

  - scope (_OPTIONAL_):
    The scope of the access request.

  - state (_RECOMMENDED_):
    An opaque value used by the client to maintain state between the request
    and callback. The authorization server includes this value when redirecting
    the user-agent back to the client. The parameter SHOULD be used for preventing
    cross-site request forgery.

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
type alias AuthorizationError =
    { error : ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
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
type alias AuthorizationSuccess =
    { code : AuthorizationCode
    , state : Maybe String
    }


{-| A simple type alias to ease readability of type signatures
-}
type alias AuthorizationCode =
    String


{-| Describes errors coming from attempting to parse a url after an OAuth redirection

  - Empty: means there were nothing (related to OAuth 2.0) to parse
  - Error: a successfully parsed OAuth 2.0 error
  - Success: a successfully parsed token and response

-}
type alias AuthorizationResult =
    AuthorizationResultWith AuthorizationError AuthorizationSuccess


{-| A parameterized 'AuthorizationResult'. See 'parseCodeWith'.
-}
type AuthorizationResultWith error success
    = Empty
    | Error error
    | Success success


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.
-}
makeAuthorizationUrl : Authorization -> Url
makeAuthorizationUrl =
    makeAuthorizationUrlWith Code Dict.empty


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Returns `AuthorizationResult Empty` when there's nothing

-}
parseCode : Url -> AuthorizationResult
parseCode =
    parseCodeWith defaultParsers



--
-- Authenticate
--


{-| Request configuration for an AuthorizationCode authentication

  - credentials (_REQUIRED_):
    Only the clientId is required. Specify a secret if a Basic OAuth
    is required by the resource provider.

  - code (_REQUIRED_):
    Authorization code from the authorization result

  - url (_REQUIRED_):
    Token endpoint of the resource provider

  - redirectUri (_REQUIRED_):
    Redirect Uri to your webserver used in the authorization step, provided
    here for verification.

-}
type alias Authentication =
    { credentials : Credentials
    , code : String
    , redirectUri : Url
    , url : Url
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
type alias AuthenticationError =
    { error : ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    }


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


{-| Describes at least a `clientId` and if define, a complete set of credentials
with the `secret`. The secret is so-to-speak optional and depends on whether the
authorization server you interact with requires a 'Basic' authentication on top of
the authentication request. Provides it if you need to do so.

      { clientId = "<my-client-id>"
      , secret = Just "<my-client-secret>"
      }

-}
type alias Credentials =
    { clientId : String
    , secret : Maybe String
    }


{-| Builds a the request components required to get a token from an authorization code

    let req : Http.Request AuthenticationSuccess
        req = makeTokenRequest toMsg authentication |> Http.request

-}
makeTokenRequest : (Result Http.Error AuthenticationSuccess -> msg) -> Authentication -> RequestParts msg
makeTokenRequest =
    makeTokenRequestWith AuthorizationCode defaultAuthenticationSuccessDecoder Dict.empty



--
-- Custom Decoders & Parsers (advanced)
--


{-| Like 'makeAuthorizationUrl', but gives you the ability to specify a custom response type
and extra fields to be set on the query.

    makeAuthorizationUrl : Authorization -> Url
    makeAuthorizationUrl =
        makeAuthorizationUrlWith Code Dict.empty

For example, to interact with a service implementing `OpenID+Connect` you may require a different
token type and an extra query parameter as such:

    makeAuthorizationUrlWith
        (CustomResponse "code+id_token")
        (Dict.fromList [ ( "resource", "001" ) ])
        authorization

-}
makeAuthorizationUrlWith : ResponseType -> Dict String String -> Authorization -> Url
makeAuthorizationUrlWith responseType extraFields { clientId, url, redirectUri, scope, state } =
    Internal.makeAuthorizationUrl
        responseType
        extraFields
        { clientId = clientId
        , url = url
        , redirectUri = redirectUri
        , scope = scope
        , state = state
        }


{-| Like 'makeTokenRequest', but gives you the ability to specify custom grant type and extra
fields to be set on the query.

    makeTokenRequest : (Result Http.Error AuthenticationSuccess -> msg) -> Authentication -> RequestParts msg
    makeTokenRequest =
        makeTokenRequestWith
            AuthorizationCode
            defaultAuthenticationSuccessDecoder
            Dict.empty

-}
makeTokenRequestWith : GrantType -> Json.Decoder success -> Dict String String -> (Result Http.Error success -> msg) -> Authentication -> RequestParts msg
makeTokenRequestWith grantType decoder extraFields toMsg { credentials, code, url, redirectUri } =
    let
        body =
            [ Builder.string "grant_type" (grantTypeToString grantType)
            , Builder.string "client_id" credentials.clientId
            , Builder.string "redirect_uri" (makeRedirectUri redirectUri)
            , Builder.string "code" code
            ]
                |> urlAddExtraFields extraFields
                |> Builder.toQuery
                |> String.dropLeft 1

        headers =
            makeHeaders <|
                case credentials.secret of
                    Nothing ->
                        Nothing

                    Just secret ->
                        Just { clientId = credentials.clientId, secret = secret }
    in
    makeRequest decoder toMsg url headers body


{-| Like `parseCode`, but gives you the ability to provide your own custom parsers.

    parseCode : Url -> AuthorizationResultWith AuthorizationError AuthorizationSuccess
    parseCode =
        parseCodeWith defaultParsers

-}
parseCodeWith : Parsers error success -> Url -> AuthorizationResultWith error success
parseCodeWith { codeParser, errorParser, authorizationSuccessParser, authorizationErrorParser } url_ =
    let
        url =
            { url_ | path = "/" }
    in
    case Url.parse (Url.top <?> Query.map2 Tuple.pair codeParser errorParser) url of
        Just ( Just code, _ ) ->
            parseUrlQuery url Empty (Query.map Success <| authorizationSuccessParser code)

        Just ( _, Just error ) ->
            parseUrlQuery url Empty (Query.map Error <| authorizationErrorParser error)

        _ ->
            Empty


{-| Parsers used in the 'parseCode' function.

  - codeParser: looks for a 'code' string
  - errorParser: looks for an 'error' to build a corresponding `ErrorCode`
  - authorizationSuccessParser: selected when the `tokenParser` succeeded to parse the remaining parts
  - authorizationErrorParser: selected when the `errorParser` succeeded to parse the remaining parts

-}
type alias Parsers error success =
    { codeParser : Query.Parser (Maybe String)
    , errorParser : Query.Parser (Maybe ErrorCode)
    , authorizationSuccessParser : String -> Query.Parser success
    , authorizationErrorParser : ErrorCode -> Query.Parser error
    }


{-| Default parsers according to RFC-6749
-}
defaultParsers : Parsers AuthorizationError AuthorizationSuccess
defaultParsers =
    { codeParser = defaultCodeParser
    , errorParser = defaultErrorParser
    , authorizationSuccessParser = defaultAuthorizationSuccessParser
    , authorizationErrorParser = defaultAuthorizationErrorParser
    }


{-| Default 'code' parser according to RFC-6749
-}
defaultCodeParser : Query.Parser (Maybe String)
defaultCodeParser =
    Query.string "code"


{-| Default 'error' parser according to RFC-6749
-}
defaultErrorParser : Query.Parser (Maybe ErrorCode)
defaultErrorParser =
    errorParser errorCodeFromString


{-| Default response success parser according to RFC-6749
-}
defaultAuthorizationSuccessParser : String -> Query.Parser AuthorizationSuccess
defaultAuthorizationSuccessParser code =
    Query.map (AuthorizationSuccess code)
        stateParser


{-| Default response error parser according to RFC-6749
-}
defaultAuthorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
defaultAuthorizationErrorParser =
    authorizationErrorParser


{-| Json decoder for a positive response. You may provide a custom response decoder using other decoders
from this module, or some of your own craft.

    defaultAuthenticationSuccessDecoder : Decoder AuthenticationSuccess
    defaultAuthenticationSuccessDecoder =
        D.map4 AuthenticationSuccess
            tokenDecoder
            refreshTokenDecoder
            expiresInDecoder
            scopeDecoder

-}
defaultAuthenticationSuccessDecoder : Json.Decoder AuthenticationSuccess
defaultAuthenticationSuccessDecoder =
    Internal.authenticationSuccessDecoder


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
    Internal.authenticationErrorDecoder defaultErrorDecoder


{-| Json decoder for an 'expire' timestamp
-}
defaultExpiresInDecoder : Json.Decoder (Maybe Int)
defaultExpiresInDecoder =
    Internal.expiresInDecoder


{-| Json decoder for a 'scope'
-}
defaultScopeDecoder : Json.Decoder (List String)
defaultScopeDecoder =
    Internal.scopeDecoder


{-| Json decoder for a 'scope', allowing comma- or space-separated scopes
-}
lenientScopeDecoder : Json.Decoder (List String)
lenientScopeDecoder =
    Internal.lenientScopeDecoder


{-| Json decoder for an 'access\_token'
-}
defaultTokenDecoder : Json.Decoder Token
defaultTokenDecoder =
    Internal.tokenDecoder


{-| Json decoder for a 'refresh\_token'
-}
defaultRefreshTokenDecoder : Json.Decoder (Maybe Token)
defaultRefreshTokenDecoder =
    Internal.refreshTokenDecoder


{-| Json decoder for 'error' field
-}
defaultErrorDecoder : Json.Decoder ErrorCode
defaultErrorDecoder =
    Internal.errorDecoder errorCodeFromString


{-| Json decoder for 'error\_description' field
-}
defaultErrorDescriptionDecoder : Json.Decoder (Maybe String)
defaultErrorDescriptionDecoder =
    Internal.errorDescriptionDecoder


{-| Json decoder for 'error\_uri' field
-}
defaultErrorUriDecoder : Json.Decoder (Maybe String)
defaultErrorUriDecoder =
    Internal.errorUriDecoder
