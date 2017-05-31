module OAuth.Implicit
    exposing
        ( authorize
        , parse
        )

import OAuth exposing (..)
import Navigation as Navigation
import Internal as Internal
import QueryString as QS


authorize : Authorization -> Cmd msg
authorize =
    Internal.authorize


parse : Navigation.Location -> Result ParseError Response
parse { hash } =
    let
        qs =
            QS.parse ("?" ++ String.dropLeft 1 hash)

        gets =
            flip (QS.one QS.string) qs

        geti =
            flip (QS.one QS.int) qs
    in
        case ( gets "access_token", gets "error" ) of
            ( Just accessToken, _ ) ->
                Internal.parseToken
                    accessToken
                    (gets "token_type")
                    (geti "expires_in")
                    (QS.all "scope" qs)
                    (gets "state")

            ( _, Just error ) ->
                Internal.parseError
                    error
                    (gets "error_description")
                    (gets "error_uri")
                    (gets "state")

            _ ->
                Result.Err Empty
