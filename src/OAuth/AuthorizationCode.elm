module OAuth.AuthorizationCode
    exposing
        ( authorize
        , authenticate
        , parse
        )

import OAuth exposing (..)
import Navigation as Navigation
import Internal as Internal
import QueryString as QS
import Http as Http


authorize : Authorization -> Cmd msg
authorize =
    Internal.authorize


authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate


parse : Navigation.Location -> Result ParseError Response
parse { search } =
    let
        qs =
            QS.parse search

        gets =
            flip (QS.one QS.string) qs
    in
        case ( gets "code", gets "error" ) of
            ( Just code, _ ) ->
                Internal.parseAuthorizationCode
                    code
                    (gets "state")

            ( _, Just error ) ->
                Internal.parseError
                    error
                    (gets "error_description")
                    (gets "error_uri")
                    (gets "state")

            _ ->
                Result.Err Empty
