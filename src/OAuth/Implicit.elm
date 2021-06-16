module OAuth.Implicit exposing
    ( makeAuthorizationUrl, parseToken, Authorization, AuthorizationResult(..), AuthorizationSuccess
    , defaultFields, extraFields
    , parseTokenWith, Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser, customAuthorizationSuccessParser
    )

{-| The implicit grant type is used to obtain access tokens (it does not
support the issuance of refresh tokens) and is optimized for public clients known to operate a
particular redirection URI. These clients are typically implemented in a browser using a
scripting language such as JavaScript.

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

@docs makeAuthorizationUrl, parseToken, Authorization, AuthorizationResult, AuthorizationSuccess


## Helpers

@docs defaultFields, extraFields


## Custom Parsers (advanced)

@docs parseTokenWith, Parsers, defaultParsers, defaultTokenParser, defaultErrorParser, defaultAuthorizationSuccessParser, defaultAuthorizationErrorParser, customAuthorizationSuccessParser

-}

import Internal exposing (authorizationErrorParser, errorParser, expiresInParser, parseUrlQuery, scopeParser, stateParser, tokenParser)
import OAuth exposing (AuthorizationError, Default, ErrorCode(..), Token, errorCodeFromString)
import Url exposing (Protocol(..), Url)
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query



--
-- Authorize
--


{-| Request configuration for an authorization

  - clientId (_REQUIRED_):
    The client identifier issues by the authorization server via an off-band mechanism.

  - url (_REQUIRED_):
    The authorization endpoint to contact the authorization server.

  - redirectUri (_OPTIONAL_):
    After completing its interaction with the resource owner, the authorization
    server directs the resource owner's user-agent back to the client via this
    URL. May be already defined on the authorization server itself.

  - scope (_OPTIONAL_):
    The scope of the access request.

  - state (_RECOMMENDED_):
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
type AuthorizationSuccess extraFields
    = AuthorizationSuccess DefaultFields extraFields


type alias DefaultFields =
    { token : Token
    , refreshToken : Maybe Token
    , expiresIn : Maybe Int
    , scope : List String
    , state : Maybe String
    }


{-| Describes errors coming from attempting to parse a url after an OAuth redirection

  - Empty: means there were nothing (related to OAuth 2.0) to parse
  - Error: a successfully parsed OAuth 2.0 error
  - Success: a successfully parsed token and response

-}
type AuthorizationResult extraFields
    = Empty
    | Error AuthorizationError
    | Success (AuthorizationSuccess extraFields)


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.
-}
makeAuthorizationUrl : Authorization -> Url
makeAuthorizationUrl { clientId, url, redirectUri, scope, state } =
    Internal.makeAuthorizationUrl
        Internal.Token
        { clientId = clientId
        , url = url
        , redirectUri = redirectUri
        , scope = scope
        , state = state
        , codeChallenge = Nothing
        }


{-| Parses the location looking for parameters in the 'fragment' set by the
authorization server after redirecting the resource owner (user).

Returns `ParseResult Empty` when there's nothing or an invalid Url is passed

-}
parseToken : Url -> AuthorizationResult Default
parseToken =
    parseTokenWith defaultParsers



--
-- Helpers
--


defaultFields : AuthorizationSuccess extraFields -> DefaultFields
defaultFields (AuthorizationSuccess defaultFields_ _) =
    defaultFields_


extraFields : AuthorizationSuccess extraFields -> extraFields
extraFields (AuthorizationSuccess _ extraFields_) =
    extraFields_



--
-- Authorize (Advanced)
--


{-| See 'parseToken', but gives you the ability to provide your own custom parsers.

This is especially useful when interacting with authorization servers that don't quite
implement the OAuth2.0 specifications.

-}
parseTokenWith : Parsers extraFields -> Url -> AuthorizationResult extraFields
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
type alias Parsers extraFields =
    { tokenParser : Query.Parser (Maybe Token)
    , errorParser : Query.Parser (Maybe ErrorCode)
    , authorizationSuccessParser : Token -> Query.Parser (AuthorizationSuccess extraFields)
    , authorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
    }


{-| Default parsers according to RFC-6749
-}
defaultParsers : Parsers Default
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
defaultAuthorizationSuccessParser : Token -> Query.Parser (AuthorizationSuccess Default)
defaultAuthorizationSuccessParser accessToken =
    Query.map AuthorizationSuccess
        (defaultFieldsParser accessToken)
        |> Query.map (\authorizationSuccess -> authorizationSuccess OAuth.Default)


{-| Custom response success parser
-}
customAuthorizationSuccessParser : Query.Parser extraFields -> Token -> Query.Parser (AuthorizationSuccess extraFields)
customAuthorizationSuccessParser extraFieldsParser accessToken =
    Query.map2 AuthorizationSuccess
        (defaultFieldsParser accessToken)
        extraFieldsParser


{-| Default fields parser
-}
defaultFieldsParser : Token -> Query.Parser DefaultFields
defaultFieldsParser accessToken =
    Query.map3 (DefaultFields accessToken Nothing)
        expiresInParser
        scopeParser
        stateParser


{-| Default response error parser according to RFC-6749
-}
defaultAuthorizationErrorParser : ErrorCode -> Query.Parser AuthorizationError
defaultAuthorizationErrorParser =
    authorizationErrorParser
