module Internal exposing (..)

import OAuth exposing (..)
import Http as Http
import QueryString as QS
import Navigation as Navigation
import Json.Decode as Json
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


authenticate : Authentication -> Http.Request ResponseToken
authenticate authentication =
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
                makeRequest url headers body

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
                makeRequest url headers body

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
                makeRequest url headers body

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
                makeRequest url headers body


makeRequest : String -> List Http.Header -> String -> Http.Request ResponseToken
makeRequest url headers body =
    Http.request
        { method = "POST"
        , headers = headers
        , url = url
        , body = Http.stringBody "application/x-www-form-urlencoded" body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }


authHeader : Maybe Credentials -> List Http.Header
authHeader credentials =
    credentials
        |> Maybe.map (\{ clientId, secret } -> Base64.encode (clientId ++ ":" ++ secret))
        |> Maybe.andThen Result.toMaybe
        |> Maybe.map (\s -> [ Http.header "Authorization" ("Basic " ++ s) ])
        |> Maybe.withDefault []
        -- GitHub requires this header, or it URL-encodes the result
        |> (::) (Http.header "accept" "application/json")



scopeDecoder : Json.Decoder (List String)
scopeDecoder =
    Json.oneOf
        [ Json.list Json.string
        -- GitHub returns a comma-separated string, instead of a list of strings.
        , Json.map (String.split ",") Json.string
        ]

decoder : Json.Decoder ResponseToken
decoder =
    Json.oneOf
        [ Json.map5
            (\token expiresIn refreshToken scope state ->
                { token = token
                , expiresIn = expiresIn
                , refreshToken = refreshToken
                , scope = Maybe.withDefault [] scope
                , state = state
                }
            )
            accessTokenDecoder
            (Json.maybe <| Json.field "expires_in" Json.int)
            refreshTokenDecoder
            (Json.maybe <| Json.field "scope" scopeDecoder)
            (Json.maybe <| Json.field "state" Json.string)
        ]


accessTokenDecoder : Json.Decoder Token
accessTokenDecoder =
    let
        mtoken =
            Json.map2 makeToken
                (Json.field "access_token" Json.string |> Json.map Just)
                (Json.field "token_type" Json.string)

        failUnless =
            Maybe.map Json.succeed >> Maybe.withDefault (Json.fail "can't decode token")
    in
        Json.andThen failUnless mtoken


refreshTokenDecoder : Json.Decoder (Maybe Token)
refreshTokenDecoder =
    Json.map2 makeToken
        (Json.maybe <| Json.field "refresh_token" Json.string)
        (Json.field "token_type" Json.string)


makeToken : Maybe String -> String -> Maybe Token
makeToken mtoken tokenType =
    case ( mtoken, String.toLower tokenType ) of
        ( Just token, "bearer" ) ->
            Just <| Bearer token

        _ ->
            Nothing


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
