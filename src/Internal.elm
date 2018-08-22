module Internal exposing
    ( authHeader
    , authenticate
    , authorize
    , makeRequest
    , parseAuthorizationCode
    , parseError
    , parseToken
    , qsSpaceSeparatedList
    , urlAddList
    , urlAddMaybe
    )

import Base64
import Browser.Navigation as Navigation
import Http as Http
import OAuth exposing (..)
import OAuth.Decode exposing (..)
import Url.Builder as Url exposing (QueryParameter)
import Url.Parser.Query as Query


authorize : Authorization -> Cmd msg
authorize { clientId, url, redirectUri, responseType, scope, state } =
    let
        qs =
            [ Url.string "client_id" clientId
            , Url.string "redirect_uri" redirectUri
            , Url.string "response_type" (showResponseType responseType)
            ]
                |> urlAddList "scope" scope
                |> urlAddMaybe "state" state
                |> Url.toQuery
    in
    Navigation.load (url ++ qs)


authenticate : AdjustRequest ResponseToken -> Authentication -> Http.Request ResponseToken
authenticate adjust authentication =
    case authentication of
        AuthorizationCode { credentials, code, redirectUri, scope, state, url } ->
            let
                body =
                    [ Url.string "grant_type" "authorization_code"
                    , Url.string "client_id" credentials.clientId
                    , Url.string "redirect_uri" redirectUri
                    , Url.string "code" code
                    ]
                        |> urlAddList "scope" scope
                        |> urlAddMaybe "state" state
                        |> Url.toQuery
                        |> String.dropLeft 1

                headers =
                    authHeader <|
                        if String.isEmpty credentials.secret then
                            Nothing

                        else
                            Just credentials
            in
            makeRequest adjust url headers body

        ClientCredentials { credentials, scope, state, url } ->
            let
                body =
                    [ Url.string "grant_type" "client_credentials" ]
                        |> urlAddList "scope" scope
                        |> urlAddMaybe "state" state
                        |> Url.toQuery
                        |> String.dropLeft 1

                headers =
                    authHeader (Just { clientId = credentials.clientId, secret = credentials.secret })
            in
            makeRequest adjust url headers body

        Password { credentials, password, scope, state, url, username } ->
            let
                body =
                    [ Url.string "grant_type" "password"
                    , Url.string "username" username
                    , Url.string "password" password
                    ]
                        |> urlAddList "scope" scope
                        |> urlAddMaybe "state" state
                        |> Url.toQuery
                        |> String.dropLeft 1

                headers =
                    authHeader credentials
            in
            makeRequest adjust url headers body

        Refresh { credentials, scope, token, url } ->
            let
                refreshToken =
                    case token of
                        Bearer t ->
                            t

                body =
                    [ Url.string "grant_type" "refresh_token"
                    , Url.string "refresh_token" refreshToken
                    ]
                        |> urlAddList "scope" scope
                        |> Url.toQuery
                        |> String.dropLeft 1

                headers =
                    authHeader credentials
            in
            makeRequest adjust url headers body


makeRequest : AdjustRequest ResponseToken -> String -> List Http.Header -> String -> Http.Request ResponseToken
makeRequest adjust url headers body =
    let
        requestParts =
            { method = "POST"
            , headers = headers
            , url = url
            , body = Http.stringBody "application/x-www-form-urlencoded" body
            , expect = Http.expectJson responseDecoder
            , timeout = Nothing
            , withCredentials = False
            }
    in
    requestParts
        |> adjust
        |> Http.request


authHeader : Maybe Credentials -> List Http.Header
authHeader credentials =
    credentials
        |> Maybe.map (\{ clientId, secret } -> Base64.encode (clientId ++ ":" ++ secret))
        |> Maybe.map (\s -> [ Http.header "Authorization" ("Basic " ++ s) ])
        |> Maybe.withDefault []


parseError : String -> Maybe String -> Maybe String -> Maybe String -> Result ParseErr a
parseError error errorDescription errorUri state =
    Result.Err <|
        OAuthErr
            { error = errCodeFromString error
            , errorDescription = errorDescription
            , errorUri = errorUri
            , state = state
            }


parseToken : String -> Maybe String -> Maybe Int -> List String -> Maybe String -> Result ParseErr ResponseToken
parseToken accessToken mTokenType mExpiresIn scope state =
    case Maybe.map String.toLower mTokenType of
        Just "bearer" ->
            Ok <|
                { expiresIn = mExpiresIn
                , refreshToken = Nothing
                , scope = scope
                , state = state
                , token = Bearer accessToken
                }

        Just _ ->
            Result.Err <| Invalid [ "token_type" ]

        Nothing ->
            Result.Err <| Missing [ "token_type" ]


parseAuthorizationCode : String -> Maybe String -> Result a ResponseCode
parseAuthorizationCode code state =
    Ok <|
        { code = code
        , state = state
        }


urlAddList : String -> List String -> List QueryParameter -> List QueryParameter
urlAddList param xs qs =
    qs
        ++ (case xs of
                [] ->
                    []

                _ ->
                    [ Url.string param (String.join " " xs) ]
           )


urlAddMaybe : String -> Maybe String -> List QueryParameter -> List QueryParameter
urlAddMaybe param ms qs =
    qs
        ++ (case ms of
                Nothing ->
                    []

                Just s ->
                    [ Url.string param s ]
           )


qsSpaceSeparatedList : String -> Query.Parser (List String)
qsSpaceSeparatedList param =
    Query.map (\s -> Maybe.withDefault "" s |> String.split " ") (Query.string param)
