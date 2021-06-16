module OAuth.Refresh exposing (makeTokenRequest, makeCustomTokenRequest, Authentication, Credentials)

{-| If the authorization server issued a refresh token to the client, the
client may make a refresh request to the token endpoint to obtain a new access token
(and refresh token) from the authorization server.

There's only one step in this process:

  - The client authenticates itself directly using the previously obtained refresh token

After this step, the client owns a fresh access `Token` and possibly, a new refresh `Token`. Both
can be used in subsequent requests.


## Authenticate

@docs makeTokenRequest, makeCustomTokenRequest, Authentication, Credentials

-}

import Http
import Internal exposing (AuthenticationSuccess, defaultDecoder, extractTokenString, makeHeaders, makeRequest, urlAddList)
import Json.Decode as Json
import OAuth exposing (Default, ErrorCode(..), RequestParts, Token)
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


{-| Builds the request components required to refresh a token

    let req : Http.Request TokenResponse
        req = makeTokenRequest toMsg reqParts |> Http.request

-}
makeTokenRequest : (Result Http.Error (AuthenticationSuccess Default) -> msg) -> Authentication -> RequestParts msg
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
    makeRequest defaultDecoder toMsg url headers body


{-| Builds the request components required to get a token from client credentials, but also includes a decoder for the extra fields

    let req : Http.Request TokenResponse
        req = makeTokenRequest extraFieldsDecoder toMsg authentication |> Http.request

-}
makeCustomTokenRequest : Json.Decoder extraFields -> (Result Http.Error (AuthenticationSuccess extraFields) -> msg) -> Authentication -> RequestParts msg
makeCustomTokenRequest extraFieldsDecoder toMsg { credentials, scope, token, url } =
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
    makeRequest extraFieldsDecoder toMsg url headers body
