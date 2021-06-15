module OAuth.ClientCredentials exposing (makeTokenRequest, Authentication, Credentials)

{-| The client can request an access token using only its client
credentials (or other supported means of authentication) when the client is requesting access to
the protected resources under its control, or those of another resource owner that have been
previously arranged with the authorization server (the method of which is beyond the scope of
this specification).

There's only one step in this process:

  - The client authenticates itself directly using credentials it owns.

After this step, the client owns a `Token` that can be used to authorize any subsequent
request.


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



--
-- Authenticate
--


{-| Request configuration for a ClientCredentials authentication

  - credentials (_REQUIRED_):
    Credentials needed for `Basic` authentication.

  - url (_REQUIRED_):
    The token endpoint to contact the authorization server.

  - scope (_OPTIONAL_):
    The scope of the access request.

-}
type alias Authentication =
    { credentials : Credentials
    , url : Url
    , scope : List String
    }


{-| Describes a couple of client credentials used for Basic authentication

      { clientId = "<my-client-id>"
      , secret = "<my-client-secret>"
      }

-}
type alias Credentials =
    { clientId : String, secret : String }


{-| Builds the request components required to get a token from client credentials

    let req : Http.Request TokenResponse
        req = makeTokenRequest toMsg authentication |> Http.request

-}
makeTokenRequest : (Result Http.Error (Internal.AuthenticationSuccess Internal.Default) -> msg) -> Authentication -> RequestParts msg
makeTokenRequest toMsg { credentials, scope, url } =
    let
        body =
            [ Builder.string "grant_type" "client_credentials" ]
                |> urlAddList "scope" scope
                |> Builder.toQuery
                |> String.dropLeft 1

        headers =
            makeHeaders <|
                Just
                    { clientId = credentials.clientId
                    , secret = credentials.secret
                    }
    in
    makeRequest defaultDecoder toMsg url headers body


{-| Builds the request components required to get a token from client credentials, but also includes a decoder for the extra fields

    let req : Http.Request TokenResponse
        req = makeTokenRequest extraFieldsDecoder toMsg authentication |> Http.request

-}
makeCustomTokenRequest : Json.Decoder extraFields -> (Result Http.Error (Internal.AuthenticationSuccess extraFields) -> msg) -> Authentication -> RequestParts msg
makeCustomTokenRequest extraFieldsDecoder toMsg { credentials, scope, url } =
    let
        body =
            [ Builder.string "grant_type" "client_credentials" ]
                |> urlAddList "scope" scope
                |> Builder.toQuery
                |> String.dropLeft 1

        headers =
            makeHeaders <|
                Just
                    { clientId = credentials.clientId
                    , secret = credentials.secret
                    }
    in
    makeRequest extraFieldsDecoder toMsg url headers body
