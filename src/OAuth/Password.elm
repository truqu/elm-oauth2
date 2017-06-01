module OAuth.Password
    exposing
        ( authenticate
        )

{-| The resource owner password credentials grant type is suitable in
cases where the resource owner has a trust relationship with the
client, such as the device operating system or a highly privileged
application. The authorization server should take special care when
enabling this grant type and only allow it when other flows are not
viable.

There's only one step in this process:

  - The client authenticates itself directly using the resource owner (user) credentials

After this step, the client owns an `access_token` that can be used to authorize any subsequent
request.


## Authenticate

@docs authenticate

-}

import OAuth exposing (..)
import Internal as Internal
import Http as Http


{-| Authenticate the client using the authorization code obtained from the authorization.

In this case, use the `Password` constructor.

-}
authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate
