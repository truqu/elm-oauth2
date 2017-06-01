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
request. A minimalistic setup goes like this:

    import OAuth
    import OAuth.AuthorizationCode
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
                        OAuth.Password.authenticate <|
                            OAuth.Password
                                { credentials = Nothing
                                , password = "<password>"
                                , scope = []
                                , state = Nothing
                                , username = "<username>"
                                , url = "<token-endpoint>"
                                }
                in
                    {} ! [ Http.send Login req ]

            Login res ->
                case res of
                    Ok (OAuth.OkToken token) ->
                        Debug.log "GOT TOKEN" token |> \_ -> model ! []

                    Ok res ->
                        Debug.log "UNEXPECTED ANSWER" res |> \_ -> model ! []

                    Err err ->
                        Debug.log "HTTP ERROR" err |> \_ -> model ! []

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

In this case, use the `Password` constructor.

-}
authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate
