module OAuth.AuthorizationCode exposing
    ( authorize, parse
    , authenticate, authenticateWithOpts
    )

{-| The authorization code grant type is used to obtain both access
tokens and refresh tokens and is optimized for confidential clients.
Since this is a redirection-based flow, the client must be capable of
interacting with the resource owner's user-agent (typically a web
browser) and capable of receiving incoming requests (via redirection)
from the authorization server.

This is a 3-step process:

  - The client asks for an authorization to the OAuth provider: the user is redirected.
  - The provider redirects the user back and the client parses the request query parameters from the url.
  - The client authenticate itself using the authorization code found in the previous step.

After those steps, the client owns an `access_token` that can be used to authorize any subsequent
request.


## Authorize

@docs authorize, parse


## Authenticate

@docs authenticate, authenticateWithOpts

-}

import Browser.Navigation as Navigation
import Http as Http
import Internal as Internal
import OAuth exposing (..)
import OAuth.Decode exposing (..)
import Url exposing (Url)
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.

In this case, use `Code` as a `responseType`

-}
authorize : Authorization -> Cmd msg
authorize =
    Internal.authorize


{-| Authenticate the client using the authorization code obtained from the authorization.

In this case, use the `AuthorizationCode` constructor.

-}
authenticate : Authentication -> Http.Request ResponseToken
authenticate =
    Internal.authenticate identity


{-| Authenticate the client using the authorization code obtained from the authorization, passing
additional custom options. Use with care.

In this case, use the `AuthorizationCode` constructor.

-}
authenticateWithOpts : AdjustRequest ResponseToken -> Authentication -> Http.Request ResponseToken
authenticateWithOpts fn =
    Internal.authenticate fn


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Fails with a `ParseErr Empty` when there's nothing

-}
parse : Url -> Result ParseErr ResponseCode
parse url_ =
    let
        url =
            { url_ | path = "/" }

        tokenTypeParser =
            Url.top
                <?> Query.map2 Tuple.pair (Query.string "code") (Query.string "error")

        authorizationCodeParser code =
            Url.query <|
                Query.map (Internal.parseAuthorizationCode code) (Query.string "state")

        errorParser error =
            Url.query <|
                Query.map3 (Internal.parseError error)
                    (Query.string "error_description")
                    (Query.string "error_url")
                    (Query.string "state")
    in
    case Url.parse tokenTypeParser url of
        Just ( Just code, _ ) ->
            Maybe.withDefault (Result.Err FailedToParse) <| Url.parse (authorizationCodeParser code) url

        Just ( _, Just error ) ->
            Maybe.withDefault (Result.Err FailedToParse) <| Url.parse (errorParser error) url

        _ ->
            Result.Err Empty
