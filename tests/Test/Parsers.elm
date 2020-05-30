module Test.Parsers exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import OAuth exposing (tokenFromString)
import OAuth.Implicit as Implicit
import Test exposing (..)
import Url exposing (Protocol(..), Url)
import Url.Parser.Query as Query


suite : Test
suite =
    describe "parseTokenWith"
        [ test "example #1" <|
            \_ ->
                let
                    url =
                        { fragment =
                            Just <|
                                String.join "&"
                                    [ "access_token=eyJ0ePPjuBg"
                                    , "token_type=bearer"
                                    , "expires_in=3600"
                                    , "state=z31j7AMHBiAHySvY8PvtcA=="
                                    ]
                        , host = "localhost"
                        , path = "/dashboard"
                        , port_ = Just 4200
                        , protocol = Http
                        , query = Nothing
                        }

                    result =
                        Implicit.parseTokenWith Implicit.defaultParsers url
                in
                case result of
                    Implicit.Success authorization ->
                        Expect.all
                            [ \{ token } ->
                                Just token
                                    |> Expect.equal (tokenFromString "Bearer=eyJ0ePPjuBg")
                            , \{ refreshToken } ->
                                refreshToken |> Expect.equal Nothing
                            , \{ expiresIn } ->
                                expiresIn
                                    |> Expect.equal (Just 3600)
                            , \{ scope } ->
                                scope
                                    |> Expect.equal []
                            , \{ state } ->
                                state
                                    |> Expect.equal (Just "z31j7AMHBiAHySvY8PvtcA==")
                            ]
                            authorization

                    _ ->
                        Expect.fail "Expected parser to succeed"
        ]
