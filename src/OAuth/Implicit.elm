module OAuth.Implicit exposing
    ( makeAuthorizationUrl, Authorization, parseToken, AuthorizationResult, AuthorizationResultWith(..), AuthorizationError, AuthorizationSuccess
    , makeAuthorizationUrlWith, parseTokenWith, Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser
    )

{-| **⚠ (DEPRECATED) ⚠ You should probably look into [OAuth.AuthorizationCode](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-AuthorizationCode) instead.**

The implicit grant type is used to obtain access tokens (it does not
support the issuance of refresh tokens) and is optimized for public clients known to operate a
particular redirection URI. These clients are typically implemented in a browser using a
scripting language such as JavaScript.


## Quick Start

To get started, have a look at the [live-demo](https://truqu.github.io/elm-oauth2/auth0/implicit/) and its
corresponding [source
code](https://github.com/truqu/elm-oauth2/blob/master/examples/providers/auth0/implicit/Main.elm).


## Overview

       +---------+                                +--------+
       |         |---(A)- Auth Redirection ------>|        |
       |         |                                |  Auth  |
       | Browser |                                | Server |
       |         |                                |        |
       |         |<--(B)- Redirection Callback ---|        |
       +---------+        w/ Access Token         +--------+
         ^     |
         |     |
        (A)   (B)
         |     |
         |     v
       +---------+
       |         |
       | Elm App |
       |         |
       |         |
       +---------+

After those steps, the client owns a `Token` that can be used to authorize any subsequent
request.


## Authorize

@docs makeAuthorizationUrl, Authorization, parseToken, AuthorizationResult, AuthorizationResultWith, AuthorizationError, AuthorizationSuccess


## Custom Parsers (advanced)

@docs makeAuthorizationUrlWith, parseTokenWith, Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser

-}

import Dict as Dict exposing (Dict)
import Internal exposing (..)
import OAuth exposing (ErrorCode(..), ResponseType(..), Token, errorCodeFromString)
import Url exposing (Protocol(..), Url)
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query



--
-- Authorize
--


{-| Request configuration for an authorization

  - `clientId` (_REQUIRED_):
    The client identifier issues by the authorization server via an off-band mechanism.

  - `url` (_REQUIRED_):
    The authorization endpoint to contact the authorization server.

  - `redirectUri` (_OPTIONAL_):
    After completing its interaction with the resource owner, the authorization
    server directs the resource owner's user-agent back to the client via this
    URL. May be already defined on the authorization server itself.

  - `scope` (_OPTIONAL_):
    The scope of the access request.

  - `state` (_RECOMMENDED_):
    An opaque value used by the client to maintain state between the request
    and callback. The authorization server includes this value when redirecting
    the user-agent back to the client. The parameter SHOULD be used for preventing
    cross-site request forgery.

-}
type alias Authorization =
    { clientId : String
    , url : Url
    , redirectUri : Url
    , scope : List String
    , state : Maybe String
    }


{-| Describes an OAuth error as a result of an authorization request failure

  - `error` (_REQUIRED_):
    A single ASCII error code.

  - `errorDescription` (_OPTIONAL_)
    Human-readable ASCII text providing additional information, used to assist the client developer in
    understanding the error that occurred. Values for the `errorDescription` parameter MUST NOT
    include characters outside the set `%x20-21 / %x23-5B / %x5D-7E`.

  - `errorUri` (_OPTIONAL_):
    A URI identifying a human-readable web page with information about the error, used to
    provide the client developer with additional information about the error. Values for the
    `errorUri` parameter MUST conform to the URI-reference syntax and thus MUST NOT include
    characters outside the set `%x21 / %x23-5B / %x5D-7E`.

  - `state` (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationError =
    { error : ErrorCode
    , errorDescription : Maybe String
    , errorUri : Maybe String
    , state : Maybe String
    }


{-| The response obtained as a result of an authentication (implicit or not)

  - `token` (_REQUIRED_):
    The access token issued by the authorization server.

  - `refreshToken` (_OPTIONAL_):
    The refresh token, which can be used to obtain new access tokens using the same authorization
    grant as described in [Section 6](https://tools.ietf.org/html/rfc6749#section-6).

  - `expiresIn` (_RECOMMENDED_):
    The lifetime in seconds of the access token. For example, the value "3600" denotes that the
    access token will expire in one hour from the time the response was generated. If omitted, the
    authorization server SHOULD provide the expiration time via other means or document the default
    value.

  - `scope` (_OPTIONAL, if identical to the scope requested; otherwise, REQUIRED_):
    The scope of the access token as described by [Section 3.3](https://tools.ietf.org/html/rfc6749#section-3.3).

  - `state` (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationSuccess =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    , state : Maybe String
    }


{-| Describes errors coming from attempting to parse a url after an OAuth redirection.
-}
type alias AuthorizationResult =
    AuthorizationResultWith AuthorizationError AuthorizationSuccess


{-| A parameterized [`AuthorizationResult`](#AuthorizationResult), see [`parseTokenWith`](#parseTokenWith).

  - `Empty`: means there were nothing (related to OAuth 2.0) to parse
  - `Error`: a successfully parsed OAuth 2.0 error
  - `Success`: a successfully parsed token and response

-}
type AuthorizationResultWith error success
    = Empty
    | Error error
    | Success success


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.
-}
makeAuthorizationUrl : Authorization -> Url
makeAuthorizationUrl =
    makeAuthorizationUrlWith Token Dict.empty


{-| Parses the location looking for parameters in the fragment set by the
authorization server after redirecting the resource owner (user).

Returns `ParseResult Empty` when there's nothing or an invalid Url is passed

-}
parseToken : Url -> AuthorizationResult
parseToken =
    parseTokenWith defaultParsers



--
-- Custom Parsers (Advanced)
--


{-| Like [`makeAuthorizationUrl`](#makeAuthorizationUrl), but gives you the ability to specify a
custom response type and extra fields to be set on the query.

    makeAuthorizationUrl : Authorization -> Url
    makeAuthorizationUrl =
        makeAuthorizationUrlWith Token Dict.empty

For example, to interact with a service implementing `OpenID+Connect` you may require a different
token type and an extra query parameter as such:

    makeAuthorizationUrlWith
        (CustomResponse "token+id_token")
        (Dict.fromList [ ( "resource", "001" ) ])
        authorization

-}
makeAuthorizationUrlWith : ResponseType -> Dict String String -> Authorization -> Url
makeAuthorizationUrlWith responseType extraFields { clientId, url, redirectUri, scope, state } =
    Internal.makeAuthorizationUrl
        responseType
        extraFields
        { clientId = clientId
        , url = url
        , redirectUri = redirectUri
        , scope = scope
        , state = state
        }


{-| Like [`parseToken`](#parseToken), but gives you the ability to provide your own custom parsers.

This is especially useful when interacting with authorization servers that don't quite
implement the OAuth2.0 specifications.

    parseToken : Url -> AuthorizationResultWith AuthorizationError AuthorizationSuccess
    parseToken =
        parseTokenWith defaultParsers

-}
parseTokenWith : Parsers error success -> Url -> AuthorizationResultWith error success
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


{-| Parsers used in the [`parseToken`](#parseToken) function.

  - `tokenParser`: Looks for an `access_token` and `token_type` to build a `Token`
  - `errorParser`: Looks for an `error` to build a corresponding `ErrorCode`
  - `authorizationSuccessParser`: Selected when the `tokenParser` succeeded to parse the remaining parts
  - `authorizationErrorParser`: Selected when the `errorParser` succeeded to parse the remaining parts

-}
type alias Parsers error success =
    { tokenParser : Query.Parser (Maybe Token)
    , errorParser : Query.Parser (Maybe ErrorCode)
    , authorizationSuccessParser : Token -> Query.Parser success
    , authorizationErrorParser : ErrorCode -> Query.Parser error
    }


{-| Default parsers according to RFC-6749.
-}
defaultParsers : Parsers AuthorizationError AuthorizationSuccess
defaultParsers =
    { tokenParser = defaultTokenParser
    , errorParser = defaultErrorParser
    , authorizationSuccessParser = defaultAuthorizationSuccessParser
    , authorizationErrorParser = defaultAuthorizationErrorParser
    }


{-| Default `access_token` parser according to RFC-6749.
-}
defaultTokenParser : Query.Parser (Maybe Token)
defaultTokenParser =
    tokenParser


{-| Default `error` parser according to RFC-6749.
-}
defaultErrorParser : Query.Parser (Maybe ErrorCode)
defaultErrorParser =
    errorParser errorCodeFromString


{-| Default response success parser according to RFC-6749.
-}
defaultAuthorizationSuccessParser : Token -> Query.Parser AuthorizationSuccess
defaultAuthorizationSuccessParser accessToken =
    Query.map3 (AuthorizationSuccess accessToken Nothing)
        expiresInParser
        scopeParser
        stateParser


{-| Default response error parser according to RFC-6749.
-}
defaultAuthorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
defaultAuthorizationErrorParser =
    authorizationErrorParser
