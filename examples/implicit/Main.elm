module Main exposing (main)

import Browser exposing (Document, application)
import Browser.Navigation as Navigation exposing (Key)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json
import OAuth
import OAuth.Implicit
import Url exposing (Protocol(..), Url)


main : Program () Model Msg
main =
    application
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        , onUrlRequest = always NoOp
        , onUrlChange = always NoOp
        }



-- Model


type alias Model =
    { oauth :
        { clientId : String
        , redirectUri : Url
        }
    , error : Maybe String
    , token : Maybe OAuth.Token
    , profile : Maybe Profile
    }


type alias Profile =
    { email : String
    , name : String
    , picture : String
    }


profileDecoder : Json.Decoder Profile
profileDecoder =
    Json.map3 Profile
        (Json.field "email" Json.string)
        (Json.field "name" Json.string)
        (Json.field "picture" Json.string)



-- Msg


type
    Msg
    -- No Operation, terminal case
    = NoOp
      -- The 'clientId' input has changed
    | ClientIdChanged String
      -- The 'clientId' input has been submitted
    | ClientIdSubmitted
      -- Got a response from the googleapis user info
    | GotUserInfo (Result Http.Error Profile)



-- init


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ origin navKey =
    let
        model =
            { oauth = { clientId = "", redirectUri = origin }
            , error = Nothing
            , token = Nothing
            , profile = Nothing
            }
    in
    case OAuth.Implicit.parse origin of
        Ok { token } ->
            ( { model | token = Just token }
            , getUserProfile profileEndpoint token
            )

        Err err ->
            ( { model | error = showParseErr err }
            , Cmd.none
            )


getUserProfile : Url -> OAuth.Token -> Cmd Msg
getUserProfile endpoint token =
    Http.send GotUserInfo <|
        Http.request
            { method = "GET"
            , body = Http.emptyBody
            , headers = OAuth.use token []
            , withCredentials = False
            , url = Url.toString endpoint
            , expect = Http.expectJson profileDecoder
            , timeout = Nothing
            }


showParseErr : OAuth.ParseErr -> Maybe String
showParseErr oauthErr =
    case oauthErr of
        OAuth.Empty ->
            Nothing

        OAuth.OAuthErr err ->
            Just <| OAuth.showErrCode err.error

        OAuth.FailedToParse ->
            Just "Failed to parse the origin URL"

        OAuth.Missing params ->
            Just <| "Missing expected parameter(s) from the response: " ++ String.join ", " params

        OAuth.Invalid params ->
            Just <| "Invalid parameter(s) from the response: " ++ String.join ", " params



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ oauth } as model) =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ClientIdChanged clientId ->
            let
                oauthBis =
                    { oauth | clientId = clientId }
            in
            ( { model | oauth = oauthBis }
            , Cmd.none
            )

        ClientIdSubmitted ->
            ( model
            , OAuth.Implicit.authorize
                { clientId = model.oauth.clientId
                , redirectUri = model.oauth.redirectUri
                , responseType = OAuth.Token
                , scope = [ "email", "profile" ]
                , state = Nothing
                , url = authorizationEndpoint
                }
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



-- view


view : Model -> Document Msg
view model =
    let
        content =
            case ( model.token, model.profile ) of
                ( Nothing, Nothing ) ->
                    viewForm model.oauth.clientId

                ( Just token, Nothing ) ->
                    viewFetching

                ( _, Just profile ) ->
                    viewProfile profile
    in
    { title = "Elm OAuth2 Example - Implicit Flow"
    , body = [ viewBody content model.error ]
    }


viewBody : Html Msg -> Maybe String -> Html Msg
viewBody content error =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "align-items" "center"
        , style "padding" "3em"
        ]
        [ h2
            [ style "display" "flex"
            , style "font-family" "Roboto, Arial, sans-serif"
            , style "color" "#141414"
            ]
            [ text "OAuth 2.0 Implicit Flow Example" ]
        , case error of
            Nothing ->
                div [ style "display" "none" ] []

            Just msg ->
                div
                    [ style "display" "block"
                    , style "width" "100%"
                    , style "position" "absolute"
                    , style "top" "0"
                    , style "padding" "1em"
                    , style "font-family" "Roboto Arial sans-serif"
                    , style "text-align" "center"
                    , style "background" "#e74c3c"
                    , style "color" "#ffffff"
                    ]
                    [ text msg ]
        , content
        ]


viewForm : String -> Html Msg
viewForm clientId =
    Html.form
        [ onSubmit ClientIdSubmitted
        , style "flex-direction" "column"
        ]
        [ input
            [ onInput ClientIdChanged
            , type_ "text"
            , placeholder "clientId"
            , value clientId
            , style "border" "none"
            , style "border-bottom" "1px solid #757575"
            , style "color" "#757575"
            , style "font" "1.5em"
            , style "font" "Roboto Arial"
            , style "outline" "none"
            , style "padding" "0.5em 1em"
            , style "text-align" "center"
            ]
            []
        , button
            [ style "background" "url('/elm-oauth2/examples/images/google.png') 1em center no-repeat"
            , style "background-size" "2em"
            , style "border" "none"
            , style "box-shadow" "rgba(0,0,0,0.25) 0px 2px 4px 0px"
            , style "color" "#757575"
            , style "font" "Roboto Arial"
            , style "margin" "1em"
            , style "outline" "none"
            , style "padding" "1em 1em 1em 3em"
            , style "text-align" "right"
            , onClick ClientIdSubmitted
            ]
            [ text "Sign in" ]
        ]


viewFetching : Html Msg
viewFetching =
    div
        [ style "color" "#757575"
        , style "font" "Roboto Arial"
        , style "text-align" "center"
        ]
        [ text "fetching profile..." ]


viewProfile : Profile -> Html Msg
viewProfile profile =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "align-items" "center"
        ]
        [ img
            [ src profile.picture
            , style "height" "150px"
            , style "margin" "1em"
            , style "width" "150px"
            ]
            []
        , text <| profile.name ++ " <" ++ profile.email ++ ">"
        ]



-- Constants / Google APIs endpoints


authorizationEndpoint : Url
authorizationEndpoint =
    { protocol = Https
    , host = "accounts.google.com"
    , path = "/o/oauth2/v2/auth/"
    , port_ = Nothing
    , query = Nothing
    , fragment = Nothing
    }


profileEndpoint : Url
profileEndpoint =
    { protocol = Https
    , host = "www.googleapis.com"
    , path = "/oauth2/v1/userinfo/"
    , port_ = Nothing
    , query = Nothing
    , fragment = Nothing
    }
