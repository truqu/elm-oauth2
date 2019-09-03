Elm OAuth 2 [![](https://img.shields.io/badge/package.elm--lang.org-5.0.1-60b5cc.svg?style=flat-square)](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest) 
=====

This package offers some utilities to implement a client-side [OAuth 2](https://tools.ietf.org/html/rfc6749) authorization in Elm. 
It covers all 4 grant types: 

- [Implicit (Recommended)](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Implicit):
  The most commonly used. The token is obtained directly as a result of a user redirection to
  an OAuth provider. The implicit grant type is used to obtain access tokens (it does not
  support the issuance of refresh tokens) and is optimized **FOR PUBLIC CLIENTS**.

- [Authorization Code](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-AuthorizationCode):
  The token is obtained as a result of an authentication, from a code obtained as a result of a
  user redirection to an OAuth provider. The authorization code grant type is used to obtain both access
   tokens and refresh tokens and is optimized **FOR CONFIDENTIAL CLIENTS** such as the device operating system 
   or a highly privileged application.

- [Resource Owner Password Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Password):
  The token is obtained directly by exchanging the user credentials with an OAuth provider. The resource owner password 
  credentials grant type is suitable in cases **WHERE THE RESOURCE OWNER HAS A TRUST RELATIONSHIP WITH THE CLIENT**.

- [Client Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-ClientCredentials):
  The token is obtained directly by exchanging application credentials with an OAuth provider. The client credentials
  grant type **MUST ONLY BE USED BY CONFIDENTIAL CLIENTS**.

## Getting Started

### Installation

```
elm install truqu/elm-oauth2
```

### Usage (Implicit Flow)

##### 0/ A few imports assumed 

```elm
import OAuth
import OAuth.Implicit
import Url exposing (Url)
import Browser.Navigation as Navigation exposing (Key)
```

##### 1/ A model ready to receive a token and a message to convey the sign-in request

```elm
type alias Model =
    { redirectUri : Url
    , error : Maybe String
    , token : Maybe OAuth.Token
    , state : String
    }

type Msg = SignInRequested { clientId : String, authorizationEndpoint : String }
```

##### 2/ Init parses the token from the URL if any, and defines a model

```elm
init : { randomBytes : String } -> Url -> Key -> ( Model, Cmd Msg )
init { randomBytes } origin _ =
    let
        model =
            { redirectUri = { origin | query = Nothing, fragment = Nothing }
            , error = Nothing
            , token = Nothing
            , state = randomBytes
            }
    in
    case OAuth.Implicit.parseToken origin of
        OAuth.Implicit.Empty ->
            ( model, Cmd.none )

        OAuth.Implicit.Success { token, state } ->
            if state /= Just model.state then
                ( { model | error = Just "'state' mismatch, request likely forged by an adversary!" }
                , Cmd.none
                )

            else
                ( { model | token = Just token }
                , getUserInfo config token
                )

        OAuth.Implicit.Error error ->
            ( { model | error = Just <| errorResponseToString error }
            , Cmd.none
            )
```

##### 3/ One replies to a sign-in request by redirecting the user to the authorization endpoint

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignInRequested { clientId, authorizationEndpoint } ->
            let
                auth =
                    { clientId = clientId
                    , redirectUri = model.redirectUri
                    , scope = []
                    , state = Just model.state 
                    , url = authorizationEndpoint
                    }
            in
            ( model
            , auth |> OAuth.Implicit.makeAuthorizationUrl |> Url.toString |> Navigation.load
            )
```

### Demo 

Complete examples are available [here](https://github.com/truqu/elm-oauth2/tree/master/examples). 
Resulting applications can be seen on the following links:

- [implicit grant](https://truqu.github.io/elm-oauth2/examples/implicit/)
- [authorization-code](https://truqu.github.io/elm-oauth2/examples/authorization-code/)

[![](https://raw.githubusercontent.com/truqu/elm-oauth2/master/.github/demo.png)](https://truqu.github.io/elm-oauth2/examples/implicit/)

### Guides

[![](https://raw.githubusercontent.com/truqu/elm-oauth2/master/guides/github/logo.png)](https://github.com/truqu/elm-oauth2/tree/master/guides/github)
[![](https://raw.githubusercontent.com/truqu/elm-oauth2/master/guides/facebook/logo.png)](https://github.com/truqu/elm-oauth2/tree/master/guides/facebook)

### Troubleshooting

[TROUBLESHOOTING.md](https://github.com/truqu/elm-oauth2/tree/master/TROUBLESHOOTING.md)

## Changelog

[CHANGELOG.md](https://github.com/truqu/elm-oauth2/tree/master/CHANGELOG.md)
