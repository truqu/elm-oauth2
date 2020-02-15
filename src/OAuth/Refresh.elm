module OAuth.Refresh exposing
    ( makeTokenRequest, Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts
    , defaultAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder
    , defaultExpiresInDecoder, defaultScopeDecoder, lenientScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder
    )

{-| If the authorization server issued a refresh token to the client, the
client may make a refresh request to the token endpoint to obtain a new access token
(and refresh token) from the authorization server.

There's only one step in this process:

  - The client authenticates itself directly using the previously obtained refresh token

After this step, the client owns a fresh access `Token` and possibly, a new refresh `Token`. Both
can be used in subsequent requests.


## Authenticate

@docs makeTokenRequest, Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts


## JSON Decoders

@docs defaultAuthenticationSuccessDecoder, defaultAuthenticationErrorDecoder


## JSON Decoders (advanced)

@docs defaultExpiresInDecoder, defaultScopeDecoder, lenientScopeDecoder, defaultTokenDecoder, defaultRefreshTokenDecoder, defaultErrorDecoder, defaultErrorDescriptionDecoder, defaultErrorUriDecoder

-}

import Http
import Internal as Internal exposing (..)
import Json.Decode as Json
import OAuth exposing (ErrorCode(..), Token, errorCodeFromString)
import Url exposing (Url)
import Url.Builder as Builder


{-| Request configuration for a Refresh authentication

  - credentials (_RECOMMENDED_):
    Credentials needed for `Basic` authentication, if needed by the
    authorization server.

  - url (_REQUIRED_):
    The token endpoint to contact the authorization server.

  - scope (_OPTIONAL_):
    The scope of the access request.

  - token (_REQUIRED_):
    Token endpoint of the resource provider

-}
type alias Authentication =
    { credentials : Maybe Credentials
    , url : Url
    , scope : List String
    , token : Token
    }


{-| Describes a couple of client credentials used for 'Basic' authentication

      { clientId = "<my-client-id>"
      , secret = "<my-client-secret>"
      }

-}
type alias Credentials =
    { clientId : String, secret : String }


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


{-| Builds the request components required to refresh a token

    let req : Http.Request TokenResponse
        req = makeTokenRequest toMsg reqParts |> Http.request

-}
makeTokenRequest : (Result Http.Error AuthenticationSuccess -> msg) -> Authentication -> RequestParts msg
makeTokenRequest toMsg { credentials, scope, token, url } =
    let
        body =
            [ Builder.string "grant_type" "refresh_token"
            , Builder.string "refresh_token" (extractTokenString token)
            ]
                |> urlAddList "scope" scope
                |> Builder.toQuery
                |> String.dropLeft 1

        headers =
            makeHeaders credentials
    in
    makeRequest toMsg url headers body



--
-- Json Decoders
--


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
            case Json.decodeString OAuth.ClientCredentials.defaultAuthenticationErrorDecoder body of
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
