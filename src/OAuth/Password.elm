module OAuth.Password exposing (Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts, makeTokenRequest, authenticationErrorDecoder)

{-| The resource owner password credentials grant type is suitable in
cases where the resource owner has a trust relationship with the
client, such as the device operating system or a highly privileged
application. The authorization server should take special care when
enabling this grant type and only allow it when other flows are not
viable.

There's only one step in this process:

  - The client authenticates itself directly using the resource owner (user) credentials

After this step, the client owns an `access_token` that can be used to authorize any subsequent
request.


## Authenticate

@docs Authentication, Credentials, AuthenticationSuccess, AuthenticationError, RequestParts, makeTokenRequest, authenticationErrorDecoder

-}

import Internal as Internal exposing (..)
import Json.Decode as Json
import OAuth exposing (ErrorCode(..), errorCodeFromString)
import Url exposing (Url)
import Url.Builder as Builder


{-| Request configuration for a Password authentication

    let authentication =
          { credentials = Just
              -- Optional, unless required by the resource provider
              { clientId = "<my-client-id>"
              , secret = "<my-client-secret>"
              }
          -- Resource owner's password
          , password = "<user-password>"
          -- Scopes requested, can be empty
          , scope = ["read:whatever"]
          -- Token endpoint of the resource provider
          , url = "<token-endpoint>"
          -- Resource owner's username
          , username = "<user-username>"
          }

-}
type alias Authentication =
    { credentials : Maybe Credentials
    , password : String
    , scope : List String
    , url : Url
    , username : String
    }


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


{-| Builds a the request components required to get a token from the resource owner (user) credentials

    let req : Http.Request TokenResponse
        req = makeTokenRequest authentication |> Http.request

-}
makeTokenRequest : Authentication -> RequestParts AuthenticationSuccess
makeTokenRequest { credentials, password, scope, url, username } =
    let
        body =
            [ Builder.string "grant_type" "password"
            , Builder.string "username" username
            , Builder.string "password" password
            ]
                |> urlAddList "scope" scope
                |> Builder.toQuery
                |> String.dropLeft 1

        headers =
            makeHeaders credentials
    in
    makeRequest url headers body
