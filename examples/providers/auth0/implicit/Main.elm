port module Main exposing (main)

import Base64.Encode as Base64
import Browser exposing (Document, application)
import Browser.Navigation as Navigation exposing (Key)
import Bytes exposing (Bytes)
import Bytes.Encode as Bytes
import Delay exposing (TimeUnit(..), after)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json
import OAuth
import OAuth.Implicit as OAuth
import Url exposing (Protocol(..), Url)


main : Program (Maybe (List Int)) Model Msg
main =
    application
        { init =
            Maybe.map convertBytes >> init
        , update =
            update
        , subscriptions =
            always <| randomBytes GotRandomBytes
        , onUrlRequest =
            always NoOp
        , onUrlChange =
            always NoOp
        , view =
            view
                { title = "Auth0 - Flow: Implicit"
                , btnClass = class "btn-auth0"
                }
        }


{-| OAuth configuration.

Note that this demo also fetches basic user information with the obtained access token,
hence the user info endpoint and JSON decoder

-}
configuration : Configuration
configuration =
    { authorizationEndpoint =
        { defaultHttpsUrl | host = "elm-oauth2.eu.auth0.com", path = "/authorize" }
    , userInfoEndpoint =
        { defaultHttpsUrl | host = "elm-oauth2.eu.auth0.com", path = "/userinfo" }
    , userInfoDecoder =
        Json.map2 UserInfo
            (Json.field "name" Json.string)
            (Json.field "picture" Json.string)
    , clientId =
        "AbRrXEIRBPgkDrqR4RgdXuHoAd1mDetT"
    , scope =
        [ "openid", "profile" ]
    }



--
-- Model
--


type alias Model =
    { redirectUri : Url
    , flow : Flow
    }


{-| This demo evolves around the following state-machine\*

        +--------+
        |  Idle  |
        +--------+
             |
             | Redirect user for authorization
             |
             v
     +--------------+
     |  Authorized  | w/ Access Token
     +--------------+
             |
             | Fetch user info using the access token
             v
         +--------+
         |  Done  |
         +--------+

(\*) The 'Errored' state hasn't been represented here for simplicity.

-}
type Flow
    = Idle
    | Authorized OAuth.Token
    | Done UserInfo
    | Errored Error


type Error
    = ErrStateMismatch
    | ErrAuthorization OAuth.AuthorizationError
    | ErrHTTPGetUserInfo


type alias UserInfo =
    { name : String
    , picture : String
    }


type alias Configuration =
    { authorizationEndpoint : Url
    , userInfoEndpoint : Url
    , userInfoDecoder : Json.Decoder UserInfo
    , clientId : String
    , scope : List String
    }


{-| During the authentication flow, we'll run twice into the `init` function:

  - The first time, for the application very first run. And we proceed with the `Idle` state,
    waiting for the user (a.k.a you) to request a sign in.

  - The second time, after a sign in has been requested, the user is redirected to the
    authorization server and redirects the user back to our application, with an access
    token and other fields as query parameters.

When query params are present (and valid), we consider the user `Authorized`.

-}
init : Maybe { state : String } -> Url -> Key -> ( Model, Cmd Msg )
init mflags origin navigationKey =
    let
        redirectUri =
            { origin | query = Nothing, fragment = Nothing }

        clearUrl =
            Navigation.replaceUrl navigationKey (Url.toString redirectUri)
    in
    case OAuth.parseToken origin of
        OAuth.Empty ->
            ( { flow = Idle, redirectUri = redirectUri }
            , Cmd.none
            )

        -- It is important to set a `state` when making the authorization request
        -- and to verify it after the redirection. The state can be anything but its primary
        -- usage is to prevent cross-site request forgery; at minima, it should be a short,
        -- non-guessable string, generated on the fly.
        --
        -- We remember any previously generated state  state using the browser's local storage
        -- and give it back (if present) to the elm application upon start
        OAuth.Success { token, state } ->
            case mflags of
                Nothing ->
                    ( { flow = Errored ErrStateMismatch, redirectUri = redirectUri }
                    , clearUrl
                    )

                Just flags ->
                    if state /= Just flags.state then
                        ( { flow = Errored ErrStateMismatch, redirectUri = redirectUri }
                        , clearUrl
                        )

                    else
                        ( { flow = Authorized token, redirectUri = redirectUri }
                        , Cmd.batch
                            -- Artificial delay to make the live demo easier to follow.
                            -- In practice, the access token could be requested right here.
                            [ after 750 Millisecond UserInfoRequested
                            , clearUrl
                            ]
                        )

        OAuth.Error error ->
            ( { flow = Errored <| ErrAuthorization error, redirectUri = redirectUri }
            , clearUrl
            )



--
-- Msg
--


type Msg
    = NoOp
    | SignInRequested
    | GotRandomBytes (List Int)
    | GotAccessToken (Result Http.Error OAuth.AuthorizationSuccess)
    | UserInfoRequested
    | GotUserInfo (Result Http.Error UserInfo)
    | SignOutRequested


getUserInfo : Configuration -> OAuth.Token -> Cmd Msg
getUserInfo { userInfoDecoder, userInfoEndpoint } token =
    Http.request
        { method = "GET"
        , body = Http.emptyBody
        , headers = OAuth.useToken token []
        , url = Url.toString userInfoEndpoint
        , expect = Http.expectJson GotUserInfo userInfoDecoder
        , timeout = Nothing
        , tracker = Nothing
        }



{- On the JavaScript's side, we have:

   app.ports.genRandomBytes.subscribe(n => {
     const buffer = new Uint8Array(n);
     crypto.getRandomValues(buffer);
     const bytes = Array.from(buffer);
     localStorage.setItem("bytes", bytes);
     app.ports.randomBytes.send(bytes);
   });
-}


port genRandomBytes : Int -> Cmd msg


port randomBytes : (List Int -> msg) -> Sub msg



--
-- Update
--


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model.flow, msg ) of
        ( Idle, SignInRequested ) ->
            signInRequested model

        ( Idle, GotRandomBytes bytes ) ->
            gotRandomBytes model bytes

        ( Authorized token, UserInfoRequested ) ->
            userInfoRequested model token

        ( Authorized _, GotUserInfo userInfoResponse ) ->
            gotUserInfo model userInfoResponse

        ( Done _, SignOutRequested ) ->
            signOutRequested model

        _ ->
            noOp model


noOp : Model -> ( Model, Cmd Msg )
noOp model =
    ( model, Cmd.none )


signInRequested : Model -> ( Model, Cmd Msg )
signInRequested model =
    ( { model | flow = Idle }
    , genRandomBytes 16
    )


gotRandomBytes : Model -> List Int -> ( Model, Cmd Msg )
gotRandomBytes model bytes =
    let
        { state } =
            convertBytes bytes

        authorization =
            { clientId = configuration.clientId
            , redirectUri = model.redirectUri
            , scope = configuration.scope
            , state = Just state
            , url = configuration.authorizationEndpoint
            }
    in
    ( { model | flow = Idle }
    , authorization
        |> OAuth.makeAuthorizationUrl
        |> Url.toString
        |> Navigation.load
    )


userInfoRequested : Model -> OAuth.Token -> ( Model, Cmd Msg )
userInfoRequested model token =
    ( { model | flow = Authorized token }
    , getUserInfo configuration token
    )


gotUserInfo : Model -> Result Http.Error UserInfo -> ( Model, Cmd Msg )
gotUserInfo model userInfoResponse =
    case userInfoResponse of
        Err _ ->
            ( { model | flow = Errored ErrHTTPGetUserInfo }
            , Cmd.none
            )

        Ok userInfo ->
            ( { model | flow = Done userInfo }
            , Cmd.none
            )


signOutRequested : Model -> ( Model, Cmd Msg )
signOutRequested model =
    ( { model | flow = Idle }
    , Navigation.load (Url.toString model.redirectUri)
    )



--
-- View
--


type alias ViewConfiguration msg =
    { title : String
    , btnClass : Attribute msg
    }


view : ViewConfiguration Msg -> Model -> Document Msg
view ({ title } as config) model =
    { title = title
    , body = viewBody config model
    }


viewBody : ViewConfiguration Msg -> Model -> List (Html Msg)
viewBody config model =
    [ div [ class "flex", class "flex-column", class "flex-space-around" ] <|
        case model.flow of
            Idle ->
                div [ class "flex" ]
                    [ viewAuthorizationStep False
                    , viewStepSeparator False
                    , viewGetUserInfoStep False
                    ]
                    :: viewIdle config

            Authorized _ ->
                div [ class "flex" ]
                    [ viewAuthorizationStep True
                    , viewStepSeparator True
                    , viewGetUserInfoStep False
                    ]
                    :: viewAuthorized

            Done userInfo ->
                div [ class "flex" ]
                    [ viewAuthorizationStep True
                    , viewStepSeparator True
                    , viewGetUserInfoStep True
                    ]
                    :: viewUserInfo config userInfo

            Errored err ->
                div [ class "flex" ]
                    [ viewErroredStep
                    ]
                    :: viewErrored err
    ]


viewIdle : ViewConfiguration Msg -> List (Html Msg)
viewIdle { btnClass } =
    [ button
        [ onClick SignInRequested, btnClass ]
        [ text "Sign in" ]
    ]


viewAuthorized : List (Html Msg)
viewAuthorized =
    [ span [] [ text "Getting user info..." ]
    ]


viewUserInfo : ViewConfiguration Msg -> UserInfo -> List (Html Msg)
viewUserInfo { btnClass } { name, picture } =
    [ div [ class "flex", class "flex-column" ]
        [ img [ class "avatar", src picture ] []
        , p [] [ text name ]
        , div []
            [ button
                [ onClick SignOutRequested, btnClass ]
                [ text "Sign out" ]
            ]
        ]
    ]


viewErrored : Error -> List (Html Msg)
viewErrored error =
    [ span [ class "span-error" ] [ viewError error ] ]


viewError : Error -> Html Msg
viewError e =
    text <|
        case e of
            ErrStateMismatch ->
                "'state' doesn't match, the request has likely been forged by an adversary!"

            ErrAuthorization error ->
                oauthErrorToString { error = error.error, errorDescription = error.errorDescription }

            ErrHTTPGetUserInfo ->
                "Unable to retrieve user info: HTTP request failed."


viewAuthorizationStep : Bool -> Html Msg
viewAuthorizationStep isActive =
    viewStep isActive ( "Authorization", style "left" "-110%" )


viewGetUserInfoStep : Bool -> Html Msg
viewGetUserInfoStep isActive =
    viewStep isActive ( "Get User Info", style "left" "-135%" )


viewErroredStep : Html Msg
viewErroredStep =
    div
        [ class "step", class "step-errored" ]
        [ span [ style "left" "-50%" ] [ text "Errored" ] ]


viewStep : Bool -> ( String, Attribute Msg ) -> Html Msg
viewStep isActive ( step, position ) =
    let
        stepClass =
            class "step"
                :: (if isActive then
                        [ class "step-active" ]

                    else
                        []
                   )
    in
    div stepClass [ span [ position ] [ text step ] ]


viewStepSeparator : Bool -> Html Msg
viewStepSeparator isActive =
    let
        stepClass =
            class "step-separator"
                :: (if isActive then
                        [ class "step-active" ]

                    else
                        []
                   )
    in
    span stepClass []



--
-- Helpers
--


toBytes : List Int -> Bytes
toBytes =
    List.map Bytes.unsignedInt8 >> Bytes.sequence >> Bytes.encode


base64 : Bytes -> String
base64 =
    Base64.bytes >> Base64.encode


convertBytes : List Int -> { state : String }
convertBytes =
    toBytes >> base64 >> (\state -> { state = state })


oauthErrorToString : { error : OAuth.ErrorCode, errorDescription : Maybe String } -> String
oauthErrorToString { error, errorDescription } =
    let
        desc =
            errorDescription |> Maybe.withDefault "" |> String.replace "+" " "
    in
    OAuth.errorCodeToString error ++ ": " ++ desc


defaultHttpsUrl : Url
defaultHttpsUrl =
    { protocol = Https
    , host = ""
    , path = ""
    , port_ = Nothing
    , query = Nothing
    , fragment = Nothing
    }
