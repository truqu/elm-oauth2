module OAuth.Implicit exposing (authorize, parse)

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

@docs authorize, parse

-}

import Browser.Navigation as Navigation
import Internal as Internal
import OAuth exposing (..)
import Url exposing (Protocol(..), Url)
import Url.Builder as Url
import Url.Parser as Url exposing ((<?>))
import Url.Parser.Query as Query


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.

In this case, use `Token` as a `responseType`

-}
authorize : Authorization -> Cmd msg
authorize =
    Internal.authorize


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Fails with `ParseErr Empty` when there's nothing

-}
parse : Url -> Result ParseErr ResponseToken
parse url_ =
    let
        url =
            { url_ | path = "/", query = url_.fragment, fragment = Nothing }

        tokenTypeParser =
            Url.top
                <?> Query.map2 Tuple.pair (Query.string "access_token") (Query.string "error")

        tokenParser accessToken =
            Url.query <|
                Query.map4 (Internal.parseToken accessToken)
                    (Query.string "token_type")
                    (Query.int "expires_in")
                    (Internal.qsSpaceSeparatedList "scope")
                    (Query.string "state")

        errorParser error =
            Url.query <|
                Query.map3 (Internal.parseError error)
                    (Query.string "error_description")
                    (Query.string "error_url")
                    (Query.string "state")
    in
    case Url.parse tokenTypeParser url of
        Just ( Just accessToken, _ ) ->
            Maybe.withDefault (Result.Err FailedToParse) <| Url.parse (tokenParser accessToken) url

        Just ( _, Just error ) ->
            Maybe.withDefault (Result.Err FailedToParse) <| Url.parse (errorParser error) url

        _ ->
            Result.Err Empty
