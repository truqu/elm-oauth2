# Interacting with GitHub

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

As a consequence, `elm-oauth2` provides a way to work around this implementation quirks by adjusting the 
authentication request before it gets sent. To achieve this, one may use the various decoders
now exposed in each module to craft a custom decoding function. By default, `elm-oauth2` uses `defaultScopeDecoder`
which strictly requires the scope to be space-separated. For Github, one must instead use the `lenientScopeDecoder` 
which will work for both comma-separated and space-separated scopes. 

Here's a small example of how to work around GitHub's API v3 implementation:

```elm
adjustRequest : Http.Request AuthenticationSuccess -> Http.Request AuthenticationSuccess
adjustRequest req =
    let
        headers =
            Http.header "Accept" ("application/json") :: req.headers

        expect =
            Http.expectJson AuthenticationSuccess <| Json.map4 
              defaultTokenDecoder
              defaultRefreshTokenDecoder
              defaultExpiresInDecoder
              lenientScopeDecoder
    in
        { req | headers = headers, expect = expect }


getToken : String -> Cmd AuthenticationSuccess
getToken code =
    let
        req =
          adjustRequest <| 
            OAuth.AuthorizationCode.makeTokenRequest AuthenticationSuccess <|
                OAuth.AuthorizationCode
                    { credentials = { clientId = clientId, secret = Nothing }
                    , code = code
                    , redirectUri = redirectUri
                    , scope = scope
                    , state = state
                    , url = tokenEndpoint
                    }
    in
        Http.send handleResponse (Http.request req)
```
