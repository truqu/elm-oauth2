module OAuth.AuthorizationCode
    exposing
        ( authorize
        , authenticate
        , parse
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
        | Authorize
        | Login (Result Http.Error OAuth.Response)

    main : Program Never Model Msg
    main =
        Navigation.program
            (always Nop)
            { init = init
            , update = update
            , view = view
            , subscriptions = (\_ -> Sub.none)
            }

    init : Navigation.Location -> ( Model, Cmd Msg )
    init location =
        case OAuth.AuthorizationCode.parse location of
            Err OAuth.Empty ->
                {} ! []

            Ok (OAuth.OkCode { code }) ->
                let
                    req =
                        OAuth.AuthorizationCode.authenticate <|
                            OAuth.AuthorizationCode
                                { credentials = { clientId = "<my-client-id>", secret = "" }
                                , code = code
                                , redirectUri = "<my-web-server>"
                                , scope = []
                                , state = Nothing
                                , url = "<token-endpoint>"
                                }
                in
                    {}
                        ! [ Http.send Login req
                          , Navigation.modifyUrl (location.origin ++ location.pathname)
                          ]

            Ok (OAuth.Err err) ->
                Debug.log "GOT ERROR" err |> \_ -> {} ! []

            Ok res ->
                Debug.log "UNEXPECTED ANSWER" res |> \_ -> {} ! []

            Err err ->
                Debug.log "PARSE ERROR" err |> \_ -> {} ! []

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            Nop ->
                model ! []

            Authorize ->
                model
                    ! [ OAuth.AuthorizationCode.authorize
                            { clientId = "<my-client-id>"
                            , redirectUri = "<my-web-server>"
                            , responseType = OAuth.Code
                            , scope = []
                            , state = Nothing
                            , url = "<authorization-endpoint>"
                            }
                      ]

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
            [ button [ onClick Authorize ] [ text "LOGIN" ] ]


## Authorize

@docs authorize, parse


## Authenticate

@docs authenticate

-}

import OAuth exposing (..)
import Navigation as Navigation
import Internal as Internal
import QueryString as QS
import Http as Http


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
authenticate : Authentication -> Http.Request Response
authenticate =
    Internal.authenticate


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Fails with `Empty` when there's nothing

-}
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
