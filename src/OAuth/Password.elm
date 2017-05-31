module OAuth.Password
    exposing
        ( authenticate
        )

import OAuth exposing (..)
import Internal as Internal
import Http as Http


authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate
