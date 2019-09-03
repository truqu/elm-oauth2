# Interacting with Facebook

Facebook has several quirks in its implementation. Therefore, in order to implement the _Implicit Flow_
correctly, one needs to provide custom parsers to accomodate with Facebook specific format. Step-by-step:

No 'token\_type' is returned, so we have to provide a default one as `Just "Bearer"`

```elm
tokenParser : Query.Parser (Maybe OAuth.Token)
tokenParser =
    Query.map (OAuth.makeToken (Just "Bearer"))
        (Query.string "access_token")
```

In case of error, no 'error' field is returned, but instead we find a field named 'error\_code'

```elm
errorParser : Query.Parser (Maybe OAuth.ErrorCode)
errorParser =
    Query.map (Maybe.map OAuth.errorCodeFromString)
        (Query.string "error_code")
```

Similarly, no 'error_description' is part of the error response, but instead we find an 'error\_message':

```elm
authorizationErrorParser : OAuth.ErrorCode -> Query.Parser OAuth.Implicit.AuthorizationError
authorizationErrorParser errorCode =
    Query.map3 (OAuth.Implicit.AuthorizationError errorCode)
        (Query.string "error_message")
        (Query.string "error_uri")
        (Query.string "state")
```

In addition, parameters are returned as query parameters instead of a fragments, and _sometimes_, a noise fragment is present in the response. 
So, as a work-around, one can patch the `Url` to make it compliant with the original RFC specification as follows:

```elm
patchUrl : Url -> Url
patchUrl url =
    if url.fragment == Just "_=_" || url.fragment == Nothing then
            { url | fragment = url.query  }

        _ ->
            url
```

All-in-all, the `OAuth.Implicit.parseTokenWith` function can be used to put everything together
and parse redirect OAuth urls from Facebook authorization server:

```elm
let parsers = 
      { tokenParser = tokenParser
      , errorParser = errorParser
      , authorizationSuccessParser = OAuth.Implicit.defaultAuthorizationSuccessParser
      , authorizationErrorParser = authorizationErrorParser
      }

parseTokenWith parsers (patchUrl url) == _ : AuthorizationResult
```

:tada:
