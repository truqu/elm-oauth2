module OAuth.Password exposing (makeTokenRequest, makeCustomTokenRequest, Authentication, Credentials)

{-| The resource owner password credentials grant type is suitable in
cases where the resource owner has a trust relationship with the
client, such as the device operating system or a highly privileged
application. The authorization server should take special care when
enabling this grant type and only allow it when other flows are not
viable.

There's only one step in this process:

  - The client authenticates itself directly using the resource owner (user) credentials

After this step, the client owns a `Token` that can be used to authorize any subsequent
request.


## Authenticate

@docs makeTokenRequest, makeCustomTokenRequest, Authentication, Credentials

-}

import Http
import Internal as Internal exposing (..)
import Json.Decode as Json
import Url exposing (Url)
import Url.Builder as Builder


{-| Request configuration for a Password authentication

  - credentials (_RECOMMENDED_):
    Credentials needed for `Basic` authentication, if needed by the
    authorization server.

  - url (_REQUIRED_):
    The token endpoint to contact the authorization server.

  - scope (_OPTIONAL_):
    The scope of the access request.

  - password (_REQUIRED_):
    Resource owner's password

  - username (_REQUIRED_):
    Resource owner's username

-}
type alias Authentication =
    { credentials : Maybe Credentials
    , url : Url
    , scope : List String
    , username : String
    , password : String
    }


{-| Describes at least a `clientId` and if defined, a complete set of credentials
with the `secret`. Optional but may be required by the authorization server you
interact with to perform a 'Basic' authentication on top of the authentication request.

      { clientId = "<my-client-id>"
      , secret = "<my-client-secret>"
      }

-}
type alias Credentials =
    { clientId : String, secret : String }


{-| Builds the request components required to get a token in exchange of the resource owner (user) credentials

    let req : Http.Request TokenResponse
        req = makeTokenRequest toMsg authentication |> Http.request

-}
makeTokenRequest : (Result Http.Error (Internal.AuthenticationSuccess Internal.Default) -> msg) -> Authentication -> RequestParts msg
makeTokenRequest toMsg { credentials, password, scope, url, username } =
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
    makeRequest defaultDecoder toMsg url headers body


{-| Builds the request components required to get a token from client credentials, but also includes a decoder for the extra fields

    let req : Http.Request TokenResponse
        req = makeTokenRequest extraFieldsDecoder toMsg authentication |> Http.request

-}
makeCustomTokenRequest : Json.Decoder extraFields -> (Result Http.Error (Internal.AuthenticationSuccess extraFields) -> msg) -> Authentication -> RequestParts msg
makeCustomTokenRequest extraFieldsDecoder toMsg { credentials, password, scope, url, username } =
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
    makeRequest extraFieldsDecoder toMsg url headers body
