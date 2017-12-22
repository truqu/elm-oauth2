Elm OAuth 2 [![](https://img.shields.io/badge/doc-elm-60b5cc.svg?style=flat-square)](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest)
=====

This package offers some utilities to implement a client-side [OAuth
2](https://tools.ietf.org/html/rfc6749) authorization in Elm. It
covers all 4 grant types: 

- [Implicit](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Implicit):
  The most commonly used. The token is obtained directly as a result of a user redirection to
  an OAuth provider.

- [Authorization Code](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-AuthorizationCode):
  The token is obtained as a result of an authentication, from a code obtained as a result of a
  user redirection to an OAuth provider.

- [Resource Owner Password Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Password):
  The token is obtained directly by exchanging the user credentials with an OAuth provider.

- [Client Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-ClientCredentials):
  The token is obtained directly by exchanging application credentials with an OAuth provider.

## Getting Started

The following parts is a walkthrough the first 2 flows. The last 2 are actually pretty
straightforward and can be seen (in terms of steps) as a subset of the Authorization Code flow.

### Installation

```
elm package install truqu/elm-oauth2
```

### Usage (Implicit Flow)

A complete example is available [here](https://truqu.github.io/elm-oauth2/examples/implicit)
(with the corresponding sources [here](https://github.com/truqu/elm-oauth2/tree/master/examples/implicit))


##### Imports
```elm
import OAuth
import OAuth.Implicit
```


##### Authorizing & Authenticating

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Authorize ->
            model
                ! [ OAuth.Implicit.authorize
                        { clientId = "clientId"
                        , redirectUri = "redirectUri"
                        , responseType = OAuth.Token -- Use the OAuth.Token response type
                        , scope = [ "whatever" ]
                        , state = Nothing
                        , url = "authorizationEndpoint"
                        }
                  ]
```

##### Parsing the token 

```elm
init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        model = {}
    in
        case OAuth.Implicit.parse location of
            -- A token has been parsed 
            Ok { token } ->
                { model | token = Just token } ! [] 

            -- Nothing to parse, unauthenticated
            Err OAuth.Empty ->
                model ! []

            -- An other type of error (invalid parsing or an actual OAuth error) 
            Err _ ->
                model ! []
```


##### Using the token

```elm
let
    req =
        Http.request
            { method = "GET"
            , body = Http.emptyBody
            , headers = OAuth.use token [] -- Add the token to the http headers
            , withCredentials = False
            , url = "whatever"
            , expect = Http.expectJson decoder
            , timeout = Nothing
            }
in
    { model | token = Just token } ! [ Http.send handleResponse req ]
```


### Usage (Authorization Code Flow)

A complete example is available
[here](https://truqu.github.io/elm-oauth2/examples/authorization_code)
(with the corresponding sources [here](https://github.com/truqu/elm-oauth2/tree/master/examples/authorization_code))


##### Imports
```elm
import OAuth
import OAuth.AuthorizationCode
```

##### Authorizing & Authenticating

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Authorize ->
            model
                ! [ OAuth.AuthorizationCode.authorize
                        { clientId = "clientId"
                        , redirectUri = "redirectUri"
                        , responseType = OAuth.Code -- Use the OAuth.Code response type
                        , scope = [ "whatever" ]
                        , state = Nothing
                        , url = "authorizationEndpoint"
                        }
                  ]

        Authenticate res ->
            case res of
                -- Http request didn't go through
                Err err ->
                  model ! []

                -- Token received from the server
                Ok { token } ->

```

##### Parsing the token

```elm
init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        model = {}
    in
        case OAuth.AuthorizationCode.parse location of
            -- A token has been parsed 
            Ok { code } ->
                let 
                    req =
                        OAuth.AuthorizationCode.authenticate <|
                            OAuth.AuthorizationCode
                                { credentials = { clientId = "clientId", secret = "secret" }
                                , code = code
                                , redirectUri = "redirectUri"
                                , scope = [ "whatever" ]
                                , state = Nothing
                                , url = "tokenEndpoint"
                                }
                in
                    model [ Http.send Authenticate req ]

            -- Nothing to parse, unauthenticated
            Err OAuth.Empty ->
                model ! []

            -- An other type of error (invalid parsing or an actual OAuth error) 
            Err _ ->
                model ! []
```


##### Using the token

```elm
let
    req =
        Http.request
            { method = "GET"
            , body = Http.emptyBody
            , headers = OAuth.use token [] -- Add the token to the http headers
            , withCredentials = False
            , url = "whatever"
            , expect = Http.expectJson decoder
            , timeout = Nothing
            }
in
    { model | token = Just token } ! [ Http.send handleResponse req ]
```

### TroubleShooting

##### Interacting with GitHub

GitHub API v3 supports the [Authorization Code Flow](https://developer.github.com/apps/building-oauth-apps/authorization-options-for-oauth-apps/#web-application-flow) 
in order to obtain access tokens for a registered application. However, the implementation 
presents a flaw which makes it not compliant with the official RFC:

- By default, GitHub's authorization server will respond with a `x-www-form-urlencoded` mime-type
  when trying to exchange the authorization code against an access token (instead of a
  `application/json` mime-type as specified in the official RFC).

- This behavior can be changed by providing an extra `Accept: application/json` header with the
  authenticate request. However, by doing so, GitHub's authorization server will encode the 
  `scope` of the response as a comma-separated list (instead of a space-separated list as
  specified in the official RFC).

Hence, this library provides a way to work around this implementation quirks by adjusting the 
authentication request before it gets sent. To achieve this, one may use the various decoders
now exposed in [OAuth.Decode](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Decode) 
to craft a custom transformation function for the `authenticateWithOpts` functions.

Here's a small example of how to work around GitHub's API v3 implementation:

```elm
lenientResponseDecoder : Json.Decoder ResponseToken
lenientResponseDecoder =
    Json.map5 OAuth.Decode.makeResponseToken
        OAuth.Decode.accessTokenDecoder
        OAuth.Decode.expiresInDecoder
        OAuth.Decode.refreshTokenDecoder
        OAuth.Decode.lenientScopeDecoder
        OAuth.Decode.stateDecoder


adjustRequest : AdjustRequest ResponseToken
adjustRequest req =
    let
        headers =
            [ Http.header "Accept" ("application/json") ] :: req.headers

        expect =
            Http.expectJson lenientResponseDecoder
    in
        { req | headers = headers, expect = expect }


getToken : String -> Cmd ResponseToken
getToken code =
    let
        req =
            OAuth.AuthorizationCode.authenticateWithOpts adjustRequest <|
                OAuth.AuthorizationCode
                    { credentials = { clientId = "clientId", secret = "secret" }
                    , code = code
                    , redirectUri = "redirectUri"
                    , scope = [ "whatever" ]
                    , state = Nothing
                    , url = "tokenEndpoint"
                    }
    in
        Http.send handleResponse req
```

## Changelog

[CHANGELOG.md](./CHANGELOG.md)

