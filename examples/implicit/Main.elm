module Main exposing (main)

import Browser exposing (application)
import Browser.Navigation as Navigation exposing (Key)
import Http
import OAuth
import OAuth.Examples.Common exposing (..)
import OAuth.Implicit
import Url exposing (Url)


main : Program () Model Msg
main =
    application
        { init = init
        , view = view "Elm OAuth2 Example - Implicit Flow" { onSignIn = SignInRequested }
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
    | SignInRequested
      -- Got a response from the googleapis user info
    | GotUserInfo (Result Http.Error Profile)


getUserInfo : Url -> OAuth.Token -> Cmd Msg
getUserInfo endpoint token =
    Http.send GotUserInfo <|
        Http.request
            { method = "GET"
            , body = Http.emptyBody
            , headers = OAuth.useToken token []
            , withCredentials = False
            , url = Url.toString endpoint
            , expect = Http.expectJson profileDecoder
            , timeout = Nothing
            }



--
-- Init
--


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ origin _ =
    let
        model =
            makeInitModel origin
    in
    case OAuth.Implicit.parseToken origin of
        OAuth.Implicit.Empty ->
            ( model, Cmd.none )

        OAuth.Implicit.Success { token } ->
            ( { model | token = Just token }
            , getUserInfo profileEndpoint token
            )

        OAuth.Implicit.Error { error } ->
            ( { model | error = Just <| OAuth.errorCodeToString error }
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

        SignInRequested ->
            let
                auth =
                    { clientId = clientId
                    , redirectUri = model.redirectUri
                    , scope = [ "email", "profile" ]
                    , state = Nothing
                    , url = authorizationEndpoint
                    }
            in
            ( model
            , auth |> OAuth.Implicit.makeAuthUrl |> Url.toString |> Navigation.load
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
