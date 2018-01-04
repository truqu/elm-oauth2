module Internal exposing (..)

import OAuth exposing (..)
import OAuth.Decode exposing (..)
import Http as Http
import QueryString as QS
import Navigation as Navigation
import Base64


authorize : Authorization -> Cmd msg
authorize { clientId, url, redirectUri, responseType, scope, state } =
    let
        qs =
            QS.empty
                |> QS.add "client_id" clientId
                |> QS.add "redirect_uri" redirectUri
                |> QS.add "response_type" (showResponseType responseType)
                |> qsAddList "scope" scope
                |> qsAddMaybe "state" state
                |> QS.render
    in
        Navigation.load (url ++ qs)


authenticate : AdjustRequest ResponseToken -> Authentication -> Http.Request ResponseToken
authenticate adjust authentication =
    case authentication of
        AuthorizationCode { credentials, code, redirectUri, scope, state, url } ->
            let
                body =
                    QS.empty
                        |> QS.add "grant_type" "authorization_code"
                        |> QS.add "client_id" credentials.clientId
                        |> QS.add "redirect_uri" redirectUri
                        |> QS.add "code" code
                        |> qsAddList "scope" scope
                        |> qsAddMaybe "state" state
                        |> QS.render
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
                    QS.empty
                        |> QS.add "grant_type" "client_credentials"
                        |> qsAddList "scope" scope
                        |> qsAddMaybe "state" state
                        |> QS.render
                        |> String.dropLeft 1

                headers =
                    authHeader (Just { clientId = credentials.clientId, secret = credentials.secret })
            in
                makeRequest adjust url headers body

        Password { credentials, password, scope, state, url, username } ->
            let
                body =
                    QS.empty
                        |> QS.add "grant_type" "password"
                        |> QS.add "username" username
                        |> QS.add "password" password
                        |> qsAddList "scope" scope
                        |> qsAddMaybe "state" state
                        |> QS.render
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
                    QS.empty
                        |> QS.add "grant_type" "refresh_token"
                        |> QS.add "refresh_token" refreshToken
                        |> qsAddList "scope" scope
                        |> QS.render
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
        |> Maybe.andThen Result.toMaybe
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
    case ( Maybe.map String.toLower mTokenType, mExpiresIn ) of
        ( Just "bearer", mExpiresIn ) ->
            Ok <|
                { expiresIn = mExpiresIn
                , refreshToken = Nothing
                , scope = scope
                , state = state
                , token = Bearer accessToken
                }

        ( Just _, _ ) ->
            Result.Err <| Invalid [ "token_type" ]

        ( Nothing, _ ) ->
            Result.Err <| Missing [ "token_type" ]


parseIDToken : String -> Result ParseErr ResponseToken
parseIDToken idToken =
    case String.split "." idToken of
        [ part0, part1, signature ] ->
            case base64Decode part1 of
                Ok payload ->
                    case decodeJWTPayloadString payload of
                        Ok token ->
                            Result.Ok { token | token = Bearer idToken }

                        Err err ->
                            Result.Err <| Invalid [ "jwt part1: " ++ err ]

                Err err ->
                    Result.Err <| Invalid [ "jwt part1: " ++ err ]

        _ ->
            Result.Err <| Invalid [ "id_token" ]


parseAuthorizationCode : String -> Maybe String -> Result a ResponseCode
parseAuthorizationCode code state =
    Ok <|
        { code = code
        , state = state
        }


qsAddList : String -> List String -> QS.QueryString -> QS.QueryString
qsAddList param xs qs =
    case xs of
        [] ->
            qs

        _ ->
            QS.add param (String.join " " xs) qs


qsAddMaybe : String -> Maybe String -> QS.QueryString -> QS.QueryString
qsAddMaybe param ms qs =
    case ms of
        Nothing ->
            qs

        Just s ->
            QS.add param s qs


base64Decode : String -> Result String String
base64Decode data =
    case Base64.decode data of
        Ok payload ->
            -- The payload may have an extra "\0" char due to base64 decode
            if not (String.endsWith "}" payload) then
                Ok <| String.dropRight 1 payload
            else
                Ok payload

        Err err ->
            Result.Err err
