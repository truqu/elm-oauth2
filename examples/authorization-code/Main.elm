module Main exposing (main)

import Browser exposing (application)
import Browser.Navigation as Navigation exposing (Key)
import Http
import Json.Decode as Json
import OAuth
import OAuth.AuthorizationCode
import OAuth.Examples.Common exposing (..)
import Url exposing (Url)


main : Program () Model Msg
main =
    application
        { init = init
        , view = view "Elm OAuth2 Example - AuthorizationCode Flow" { onSignIn = SignInRequested }
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
      -- Got a response from the googleapis token endpoint
    | GotAccessToken (Result Http.Error OAuth.AuthorizationCode.AuthenticationSuccess)
      -- Got a response from the googleapis info endpoint
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


getAccessToken : Url -> Model -> String -> Cmd Msg
getAccessToken endpoint model code =
    Http.send GotAccessToken <|
        Http.request <|
            OAuth.AuthorizationCode.makeTokenRequest
                { credentials =
                    { clientId = clientId
                    , secret = Just clientSecret
                    }
                , code = code
                , url = endpoint
                , redirectUri = model.redirectUri
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
    case OAuth.AuthorizationCode.parseCode origin of
        OAuth.AuthorizationCode.Success { code, state } ->
            if state == Just model.state then
                ( model
                , getAccessToken tokenEndpoint model code
                )

            else
                ( { model | error = Just "Request has been forged along the way: state doesn't match" }
                , Cmd.none
                )

        OAuth.AuthorizationCode.Empty ->
            ( model, Cmd.none )

        OAuth.AuthorizationCode.Error err ->
            ( { model | error = Just (OAuth.errorCodeToString err.error) }
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
                    , state = Just model.state
                    , url = authorizationEndpoint
                    }
            in
            ( model
            , auth |> OAuth.AuthorizationCode.makeAuthUrl |> Url.toString |> Navigation.load
            )

        GotAccessToken res ->
            case res of
                Err (Http.BadStatus { body }) ->
                    case Json.decodeString OAuth.AuthorizationCode.authenticationErrorDecoder body of
                        Ok { error, errorDescription } ->
                            let
                                errMsg =
                                    "Unable to retrieve token: " ++ errorResponseToString { error = error, errorDescription = errorDescription }
                            in
                            ( { model | error = Just errMsg }
                            , Cmd.none
                            )

                        _ ->
                            ( { model | error = Just ("Unable to retrieve token: " ++ body) }
                            , Cmd.none
                            )

                Err _ ->
                    ( { model | error = Just "Unable to retrieve token: HTTP request failed." }
                    , Cmd.none
                    )

                Ok { token } ->
                    ( { model | token = Just token }
                    , getUserInfo profileEndpoint token
                    )

        GotUserInfo res ->
            case res of
                Err _ ->
                    ( { model | error = Just "Unable to retrieve user profile: HTTP request failed." }
                    , Cmd.none
                    )

                Ok profile ->
                    ( { model | profile = Just profile }
                    , Cmd.none
                    )
