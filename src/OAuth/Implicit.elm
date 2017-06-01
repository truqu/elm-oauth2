module OAuth.Implicit
    exposing
        ( authorize
        , parse
        )

{-| The implicit grant type is used to obtain access tokens (it does not
support the issuance of refresh tokens) and is optimized for public clients known to operate a
particular redirection URI. These clients are typically implemented in a browser using a
scripting language such as JavaScript.

This is a 2-step process:

  - The client asks for an authorization and implicit authentication to the OAuth provider: the user is redirected.
  - The provider redirects the user back and the client parses the request query parameters from the url.

After those steps, the client owns an `access_token` that can be used to authorize any subsequent
request. A minimalistic setup goes like this:

    import OAuth
    import OAuth.AuthorizationCode
    import Navigation
    import Html exposing (..)
    import Html.Events exposing (..)

    type alias Model =
        {}

    type Msg
        = Nop
        | Authorize

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
        case OAuth.Implicit.parse location of
            Ok (OAuth.OkToken token) ->
                Debug.log "GOT TOKEN" token |> \_ -> model ! []

            Ok res ->
                Debug.log "UNEXPECTED ANSWER" res |> \_ -> model ! []

            Err err ->
                Debug.log "ERROR" err |> \_ -> model ! []

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            Nop ->
                model ! []

            Authorize ->
                model
                    ! [ OAuth.Implicit.authorize
                            { clientId = "<my-client-id>"
                            , redirectUri = "<my-web-server>"
                            , responseType = OAuth.Token
                            , scope = []
                            , state = Nothing
                            , url = "https://github.com/login/oauth/authorize"
                            }
                      ]

    view : Model -> Html Msg
    view _ =
        div []
            [ button [ onClick Authorize ] [ text "LOGIN" ] ]


## Authorize

@docs authorize, parse

-}

import OAuth exposing (..)
import Navigation as Navigation
import Internal as Internal
import QueryString as QS


{-| Redirects the resource owner (user) to the resource provider server using the specified
authorization flow.

In this case, use `Token` as a `responseType`

-}
authorize : Authorization -> Cmd msg
authorize =
    Internal.authorize


{-| Parse the location looking for a parameters set by the resource provider server after
redirecting the resource owner (user).

Fails with `Empty` when there's nothing

-}
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
