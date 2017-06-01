module OAuth.ClientCredentials
    exposing
        ( authenticate
        )

{-| The client can request an access token using only its client
credentials (or other supported means of authentication) when the client is requesting access to
the protected resources under its control, or those of another resource owner that have been
previously arranged with the authorization server (the method of which is beyond the scope of
this specification).

There's only one step in this process:

  - The client authenticates itself directly using credentials it owns.

After this step, the client owns an `access_token` that can be used to authorize any subsequent
request. A minimalistic setup goes like this:

    import OAuth
    import OAuth.ClientCredentials
    import Navigation
    import Http
    import Html exposing (..)
    import Html.Events exposing (..)

    type alias Model =
        {}

    type Msg
        = Nop
        | Authenticate
        | Login (Result Http.Error OAuth.Response)

    main : Program Never Model Msg
    main =
        Navigation.program
            (always Nop)
            { init = (\_ -> {} ! [])
            , update = update
            , view = view
            , subscriptions = (\_ -> Sub.none)
            }

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            Nop ->
                model ! []

            Authenticate ->
                let
                    req =
                        OAuth.ClientCredentials.authenticate <|
                            OAuth.Password
                                { credentials = { clientId = "<my-client-id>", secret = "<my-client-secret>" }
                                , scope = []
                                , state = Nothing
                                , url = "<token-endpoint>"
                                }
                in
                    {} ! [ Http.send Login req ]

            Login res ->
                case res of
                    Ok (OAuth.OkToken token) ->
                        Debug.log "GOT TOKEN" token |> \_ -> {} ! []

                    Ok res ->
                        Debug.log "UNEXPECTED ANSWER" res |> \_ -> {} ! []

                    Err err ->
                        Debug.log "HTTP ERROR" err |> \_ -> {} ! []

    view : Model -> Html Msg
    view _ =
        div []
            [ button [ onClick Authenticate ] [ text "LOGIN" ] ]


## Authenticate

@docs authenticate

-}

import OAuth exposing (..)
import Internal as Internal
import Http as Http


{-| Authenticate the client using the authorization code obtained from the authorization.

In this case, use the `ClientCredentials` constructor.

-}
authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate
