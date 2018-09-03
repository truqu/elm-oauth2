module OAuth.Refresh exposing (Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts, makeTokenRequest, authenticationErrorDecoder)

{-| If the authorization server issued a refresh token to the client, the
client may make a refresh request to the token endpoint to obtain a new access token
(and refresh token) from the authorization server.

There's only one step in this process:

    - The client authenticates itself directly using the previously obtained refresh token

After this step, the client owns a fresh `access_token` and possibly, a new `refresh_token`. Both
can be used in subsequent requests.


## Authenticate

@docs Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts, makeTokenRequest, authenticationErrorDecoder

-}

import Internal as Internal exposing (..)
import Json.Decode as Json
import OAuth exposing (ErrorCode(..), Token, errorCodeFromString)
import Url exposing (Url)
import Url.Builder as Builder


{-| Request configuration for a Refresh authentication

    let authentication =
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
type alias Authentication =
    { credentials : Maybe Credentials
    , token : Token
    , scope : List String
    , url : Url
    }


{-| Describes a couple of client credentials used for Basic authentication

      { clientId = "<my-client-id>"
      , secret = "<my-client-secret>"
      }

-}
type alias Credentials =
    { clientId : String, secret : String }


type alias AuthenticationSuccess =
    Internal.AuthenticationSuccess


type alias AuthenticationError =
    Internal.AuthenticationError ErrorCode


type alias RequestParts a =
    Internal.RequestParts a


authenticationErrorDecoder : Json.Decoder AuthenticationError
authenticationErrorDecoder =
    Internal.authenticationErrorDecoder (errorDecoder errorCodeFromString)


{-| Builds a the request components required to refresh a token

    let req : Http.Request TokenResponse
        req = makeTokenRequest reqParts |> Http.request

-}
makeTokenRequest : Authentication -> RequestParts AuthenticationSuccess
makeTokenRequest { credentials, scope, token, url } =
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
    makeRequest url headers body
