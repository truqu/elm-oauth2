module Main exposing (main)

import Browser exposing (application)
import Browser.Navigation as Navigation exposing (Key)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Json
import OAuth
import OAuth.AuthorizationCode
import OAuth.Examples.Common exposing (..)
import Url exposing (Url)


main : Program { randomBytes : String } Model Msg
main =
    application
        { init = init
        , view =
            view "Elm OAuth2 Example - AuthorizationCode Flow"
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
      -- Got a response from the googleapis token endpoint
    | GotAccessToken OAuthConfiguration (Result Http.Error OAuth.AuthorizationCode.AuthenticationSuccess)
      -- Got a response from the googleapis info endpoint
    | GotUserInfo (Result Http.Error Profile)


getUserInfo : OAuthConfiguration -> OAuth.Token -> Cmd Msg
getUserInfo { profileEndpoint, profileDecoder } token =
    Http.request
        { method = "GET"
        , body = Http.emptyBody
        , headers = OAuth.useToken token []
        , url = Url.toString profileEndpoint
        , expect = Http.expectJson GotUserInfo profileDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


getAccessToken : OAuthConfiguration -> Url -> String -> Cmd Msg
getAccessToken ({ clientId, secret, tokenEndpoint } as config) redirectUri code =
    Http.request <|
        OAuth.AuthorizationCode.makeTokenRequest
            (GotAccessToken config)
            { credentials =
                { clientId = clientId
                , secret = Just secret
                }
            , code = code
            , url = tokenEndpoint
            , redirectUri = redirectUri
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
    case OAuth.AuthorizationCode.parseCode origin of
        OAuth.AuthorizationCode.Success { code, state } ->
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
                        ( model
                        , getAccessToken config model.redirectUri code
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

        SignInRequested { scope, provider, clientId, authorizationEndpoint } ->
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
            , auth |> OAuth.AuthorizationCode.makeAuthUrl |> Url.toString |> Navigation.load
            )

        SignOutRequested ->
            ( model
            , Navigation.load (Url.toString model.redirectUri)
            )

        GotAccessToken config res ->
            case res of
                Err (Http.BadBody body) ->
                    case Json.decodeString OAuth.AuthorizationCode.defaultAuthenticationErrorDecoder body of
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
                    ( { model | error = Just "Unable to retrieve token: HTTP request failed. CORS is likely disabled on the authorization server." }
                    , Cmd.none
                    )

                Ok { token } ->
                    ( { model | token = Just token }
                    , getUserInfo config token
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



--
-- Side Note
--


sideNote : List (Html msg)
sideNote =
    [ h1 [] [ text "Authorization Code" ]
    , p []
        [ text """
This simple demo gives an example on how to implement the OAuth-2.0
Authorization Code grant using Elm. Keep in mind that this example
is fully written Elm whereas you'd likely to the 'authentication' step
server-side. Actually, most well-known authorization servers don't
enable CORS on the authentication endpoint, making it impossible to perform
this operation client-side.
  """
        ]
    , p []
        [ text "A few interesting notes about this demo:"
        , br [] []
        , ul []
            [ li [ style "margin" "0.5em 0" ] [ text "This demo application requires basic scopes from the authorization servers in order to display your name and profile picture, illustrating the demo." ]
            , li [ style "margin" "0.5em 0" ] [ text "You can observe the URL in the browser navigation bar and requests made against the authorization servers!" ]
            , li [ style "margin" "0.5em 0" ] [ text "None of the 'authentication' steps in this demo will work for it uses dummy secrets. Yet, it is still possible to do the 'authorization' step to retrieve an authorization code. You may try to submit this code via cURL to obtain an access token." ]
            ]
        ]
    ]
