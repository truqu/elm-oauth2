module OAuth.Implicit exposing (Authorization, AuthorizationResult(..), AuthorizationSuccess, AuthorizationError, makeAuthUrl, parseToken)

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

-}

import Internal exposing (..)
import OAuth exposing (ErrorCode(..), Token, errorCodeFromString)
import Url exposing (Protocol(..), Url)
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query



--
-- Authorize
--


type alias Authorization =
    Internal.Authorization


type alias AuthorizationError =
    Internal.AuthorizationError ErrorCode


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


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Fails with `ParseResult Empty` when there's nothing or an invalid Url is passed

-}
parseToken : Url -> AuthorizationResult
parseToken url_ =
    let
        url =
            { url_ | path = "/", query = url_.fragment, fragment = Nothing }
    in
    case Url.parse (Url.top <?> Query.map2 Tuple.pair tokenParser (errorParser errorCodeFromString)) url of
        Just ( Ok accessToken, _ ) ->
            parseUrlQuery url Empty (Query.map Success <| authorizationSuccessParser accessToken)

        Just ( _, Just error ) ->
            parseUrlQuery url Empty (Query.map Error <| authorizationErrorParser error)

        _ ->
            Empty


authorizationSuccessParser : Token -> Query.Parser AuthorizationSuccess
authorizationSuccessParser accessToken =
    Query.map3 (AuthorizationSuccess accessToken Nothing)
        expiresInParser
        scopeParser
        stateParser
