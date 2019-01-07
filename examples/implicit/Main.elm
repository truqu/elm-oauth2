port module Main exposing (main)

import Browser exposing (application)
import Browser.Navigation as Navigation exposing (Key)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Json
import OAuth
import OAuth.Examples.Common exposing (..)
import OAuth.Implicit
import Url exposing (Url)


main : Program { randomBytes : String } Model Msg
main =
    application
        { init = init
        , view =
            view "Elm OAuth2 Example - Implicit Flow"
                { buttons =
                    [ viewSignInButton Google SignInRequested
                    , viewSignInButton Spotify SignInRequested
                    , viewSignInButton LinkedIn SignInRequested
                    ]
                , sideNote = sideNote
                , onSignOut = SignOutRequested
                }
        , update = update
        , subscriptions = always Sub.none
        , onUrlRequest = always NoOp
        , onUrlChange = always NoOp
        }



--
-- Msg
--


type
    Msg
    -- No Operation, terminal case
    = NoOp
      -- The 'sign-in' button has been hit
    | SignInRequested OAuthConfiguration
      -- The 'sign-out' button has been hit
    | SignOutRequested
      -- Got a response from the googleapis user info
    | GotUserInfo (Result Http.Error Profile)


getUserInfo : OAuthConfiguration -> OAuth.Token -> Cmd Msg
getUserInfo { profileEndpoint, profileDecoder } token =
    Http.request
        { method = "GET"
        , body = Http.emptyBody
        , headers = OAuth.useToken token []
        , tracker = Nothing
        , url = Url.toString profileEndpoint
        , expect = Http.expectJson GotUserInfo profileDecoder
        , timeout = Nothing
        }



--
-- Init
--


init : { randomBytes : String } -> Url -> Key -> ( Model, Cmd Msg )
init { randomBytes } origin _ =
    let
        model =
            makeInitModel randomBytes origin
    in
    case OAuth.Implicit.parseToken (queryAsFragment origin) of
        OAuth.Implicit.Empty ->
            ( model, Cmd.none )

        OAuth.Implicit.Success { token, state } ->
            if Maybe.map randomBytesFromState state /= Just model.state then
                ( { model | error = Just "'state' doesn't match, the request has likely been forged by an adversary!" }
                , Cmd.none
                )

            else
                case Maybe.andThen (Maybe.map configurationFor << oauthProviderFromState) state of
                    Nothing ->
                        ( { model | error = Just "Couldn't recover OAuthProvider from state" }
                        , Cmd.none
                        )

                    Just config ->
                        ( { model | token = Just token }
                        , getUserInfo config token
                        )

        OAuth.Implicit.Error { error, errorDescription } ->
            ( { model | error = Just <| errorResponseToString { error = error, errorDescription = errorDescription } }
            , Cmd.none
            )



--
-- Update
--


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        SignInRequested { clientId, authorizationEndpoint, provider, scope } ->
            let
                auth =
                    { clientId = clientId
                    , redirectUri = model.redirectUri
                    , scope = scope
                    , state = Just (makeState model.state provider)
                    , url = authorizationEndpoint
                    }
            in
            ( model
            , auth |> OAuth.Implicit.makeAuthUrl |> Url.toString |> Navigation.load
            )

        SignOutRequested ->
            ( model
            , Navigation.load (Url.toString model.redirectUri)
            )

        GotUserInfo res ->
            case res of
                Err err ->
                    ( { model | error = Just "Unable to fetch user profile ¯\\_(ツ)_/¯" }
                    , Cmd.none
                    )

                Ok profile ->
                    ( { model | profile = Just profile }
                    , Cmd.none
                    )



--
-- Side Note
--


sideNote : List (Html msg)
sideNote =
    [ h1 [] [ text "Implicit Flow" ]
    , p []
        [ text """
This simple demo gives an example on how to implement the OAuth-2.0
Implicit grant using Elm. This is the recommended way for most client
application as it doesn't expose any secret credentials to the end-user.
  """
        ]
    , p []
        [ text "A few interesting notes about this demo:"
        , br [] []
        , ul []
            [ li [ style "margin" "0.5em 0" ] [ text "This demo application requires basic scopes from the authorization servers in order to display your name and profile picture, illustrating the demo." ]
            , li [ style "margin" "0.5em 0" ] [ text "You can observe the URL in the browser navigation bar and requests made against the authorization servers!" ]
            , li [ style "margin" "0.5em 0" ] [ text "The LinkedIn implemention doesn't work as LinkedIn only supports the 'Authorization Code' grant. Though, the button is still here to show an example of error path." ]
            ]
        ]
    ]
