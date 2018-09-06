module OAuth.Implicit exposing
    ( Authorization, AuthorizationResult(..), AuthorizationSuccess, AuthorizationError, makeAuthUrl, parseToken
    , parseTokenWith
    , Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser
    )

{-| The implicit grant type is used to obtain access tokens (it does not
support the issuance of refresh tokens) and is optimized for public clients known to operate a
particular redirection URI. These clients are typically implemented in a browser using a
scripting language such as JavaScript.

This is a 2-step process:

  - The client asks for an authorization and implicit authentication to the OAuth provider: the user is redirected.
  - The provider redirects the user back and the client parses the request query parameters from the url.

After those steps, the client owns an `access_token` that can be used to authorize any subsequent
request.


## Authorize

@docs Authorization, AuthorizationResult, AuthorizationSuccess, AuthorizationError, makeAuthUrl, parseToken


## Authorize (advanced)

@docs parseTokenWith


## Query Parsers

@docs Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser

-}

import Internal exposing (..)
import OAuth exposing (ErrorCode(..), Token, errorCodeFromString)
import Url exposing (Protocol(..), Url)
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query



--
-- Authorize
--


{-| Request configuration for an authorization
-}
type alias Authorization =
    { clientId : String
    , url : Url
    , redirectUri : Url
    , scope : List String
    , state : Maybe String
    }


{-| Describes an OAuth error as a result of an authorization request failure

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

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationError =
    { error : ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


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

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationSuccess =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    , state : Maybe String
    }


{-| Describes errors coming from attempting to parse a url after an OAuth redirection

  - Empty: means there were nothing (related to OAuth 2.0) to parse
  - Error: a successfully parsed OAuth 2.0 error
  - Success: a successfully parsed the response

-}
type AuthorizationResult
    = Empty
    | Error AuthorizationError
    | Success AuthorizationSuccess


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.
-}
makeAuthUrl : Authorization -> Url
makeAuthUrl =
    Internal.makeAuthUrl Internal.Token


{-| Parses the location looking for parameters in the 'fragment' set by the
authorization server after redirecting the resource owner (user).

Returns `ParseResult Empty` when there's nothing or an invalid Url is passed

-}
parseToken : Url -> AuthorizationResult
parseToken =
    parseTokenWith defaultParsers



--
-- Authorize (Advanced)
--


{-| See 'parseToken', but gives you the ability to provide your own custom parsers.

This is especially useful when interacting with authorization servers that don't quite
implement the OAuth2.0 specifications.

For instance, Facebook has several quirks in its implementation:

  - It doesn't return any 'token\_type'

```
    tokenParser : Query.Parser (Maybe OAuth.Token)
    tokenParser =
        Query.map (OAuth.makeToken (Just "Bearer"))
            (Query.string "access_token")
```

  - It doesn't return any 'error', but returns instead an 'error\_code'

```
    errorParser : Query.Parser (Maybe OAuth.ErrorCode)
    errorParser =
        Query.map (Maybe.map OAuth.errorCodeFromString)
          (Query.string "error_code")
```

  - It doesn't return an 'error\_description', but returns instead an 'error\_message'

```
    authorizationErrorParser : OAuth.ErrorCode -> Query.Parser OAuth.Implicit.AuthorizationError
    authorizationErrorParser errorCode =
        Query.map3 (OAuth.Implicit.AuthorizationError errorCode)
            (Query.string "error_message")
            (Query.string "error_uri")
            (Query.string "state")
```

  - It returns the parameters as query parameters instead of a fragment, and even sometimes add a noise fragment

```
    patchUrl : Url -> Url
    patchUrl url =
        if url.fragment == Just "_=_" || url.fragment == Nothing then
                { url | fragment = url.query  }

            _ ->
                url
```

-}
parseTokenWith : Parsers -> Url -> AuthorizationResult
parseTokenWith { tokenParser, errorParser, authorizationSuccessParser, authorizationErrorParser } url_ =
    let
        url =
            { url_ | path = "/", query = url_.fragment, fragment = Nothing }
    in
    case Url.parse (Url.top <?> Query.map2 Tuple.pair tokenParser errorParser) url of
        Just ( Just accessToken, _ ) ->
            parseUrlQuery url Empty (Query.map Success <| authorizationSuccessParser accessToken)

        Just ( _, Just error ) ->
            parseUrlQuery url Empty (Query.map Error <| authorizationErrorParser error)

        _ ->
            Empty



--
-- Query Parsers
--


{-| Parsers used in the 'parseToken' function.

  - tokenParser: Looks for an 'access\_token' and 'token\_type' to build a `Token`
  - errorParser: Looks for an 'error' to build a corresponding `ErrorCode`
  - authorizationSuccessParser: Selected when the `tokenParser` succeeded to parse the remaining parts
  - authorizationErrorParser: Selected when the `errorParser` succeeded to parse the remaining parts

-}
type alias Parsers =
    { tokenParser : Query.Parser (Maybe Token)
    , errorParser : Query.Parser (Maybe ErrorCode)
    , authorizationSuccessParser : Token -> Query.Parser AuthorizationSuccess
    , authorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
    }


{-| Default parsers according to RFC-6749
-}
defaultParsers : Parsers
defaultParsers =
    { tokenParser = defaultTokenParser
    , errorParser = defaultErrorParser
    , authorizationSuccessParser = defaultAuthorizationSuccessParser
    , authorizationErrorParser = defaultAuthorizationErrorParser
    }


{-| Default 'access\_token' parser according to RFC-6749
-}
defaultTokenParser : Query.Parser (Maybe Token)
defaultTokenParser =
    tokenParser


{-| Default 'error' parser according to RFC-6749
-}
defaultErrorParser : Query.Parser (Maybe ErrorCode)
defaultErrorParser =
    errorParser errorCodeFromString


{-| Default response success parser according to RFC-6749
-}
defaultAuthorizationSuccessParser : Token -> Query.Parser AuthorizationSuccess
defaultAuthorizationSuccessParser accessToken =
    Query.map3 (AuthorizationSuccess accessToken Nothing)
        expiresInParser
        scopeParser
        stateParser


{-| Default response error parser according to RFC-6749
-}
defaultAuthorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
defaultAuthorizationErrorParser =
    authorizationErrorParser
