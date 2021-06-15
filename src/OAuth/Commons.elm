module OAuth.Commons exposing (..)

import Internal
import Json.Decode as Json
import OAuth exposing (ErrorCode, Token, errorCodeFromString)


{-| Parts required to build a request. This record is given to `Http.request` in order
to create a new request and may be adjusted at will.
-}
type alias RequestParts a =
    Internal.RequestParts a


{-| Describes an OAuth error as a result of an authorization request failure

  - error (_REQUIRED_):
    A single ASCII error code.

  - errorDescription (_OPTIONAL_)
    Human-readable ASCII text providing additional information, used to assist the client developer in
    understanding the error that occurred. Values for the `errorDescription` parameter MUST NOT
    include characters outside the set `%x20-21 / %x23-5B / %x5D-7E`.

  - errorUri (_OPTIONAL_):
    A URI identifying a human-readable web page with information about the error, used to
    provide the client developer with additional information about the error. Values for the
    `errorUri` parameter MUST conform to the URI-reference syntax and thus MUST NOT include
    characters outside the set `%x21 / %x23-5B / %x5D-7E`.

  - state (_REQUIRED if `state` was present in the authorization request_):
    The exact value received from the client

-}
type alias AuthorizationError =
    Internal.AuthorizationError ErrorCode


{-| Placeholder used to mark the use of the default OAuth response as a result of an authorization.
Use this when you have no extra fields to decode from the Authorization Server.
-}
type alias Default =
    Internal.Default



-- ACCESSORS


defaultFields : Internal.AuthenticationSuccess extraFields -> Internal.DefaultFields
defaultFields authenticationSuccess =
    Internal.defaultFields authenticationSuccess


extraFields : Internal.AuthenticationSuccess extraFields -> extraFields
extraFields authenticationSuccess =
    Internal.extraFields authenticationSuccess



--
-- Json Decoders
--


{-| Default Json decoder for a positive response.

    defaultAuthenticationSuccessDecoder : Decoder AuthenticationSuccess
    defaultAuthenticationSuccessDecoder =
        D.map4 AuthenticationSuccess
            tokenDecoder
            refreshTokenDecoder
            expiresInDecoder
            scopeDecoder

-}
defaultAuthenticationSuccessDecoder : Json.Decoder (Internal.AuthenticationSuccess Internal.Default)
defaultAuthenticationSuccessDecoder =
    Internal.authenticationSuccessDecoder Internal.defaultDecoder


{-| Custom Json decoder for a positive response. You provide a custom response decoder for any extra fields using other decoders
from this module, or some of your own craft.

    customAuthenticationSuccessDecoder : Decoder extraFields -> Decoder AuthenticationSuccess
    customAuthenticationSuccessDecoder =
        D.map4 AuthenticationSuccess
            tokenDecoder
            refreshTokenDecoder
            expiresInDecoder
            scopeDecoder

-}
customAuthenticationSuccessDecoder : Json.Decoder extraFields -> Json.Decoder (Internal.AuthenticationSuccess extraFields)
customAuthenticationSuccessDecoder extraFieldsDecoder =
    Internal.authenticationSuccessDecoder extraFieldsDecoder


{-| Json decoder for an errored response.

    case res of
        Err (Http.BadStatus { body }) ->
            case Json.decodeString OAuth.AuthorizationCode.defaultAuthenticationErrorDecoder body of
                Ok { error, errorDescription } ->
                    doSomething

                _ ->
                    parserFailed

        _ ->
            someOtherError

-}
defaultAuthenticationErrorDecoder : Json.Decoder (Internal.AuthenticationError ErrorCode)
defaultAuthenticationErrorDecoder =
    Internal.authenticationErrorDecoder defaultErrorDecoder


{-| Json decoder for an 'expire' timestamp
-}
defaultExpiresInDecoder : Json.Decoder (Maybe Int)
defaultExpiresInDecoder =
    Internal.expiresInDecoder


{-| Json decoder for a 'scope'
-}
defaultScopeDecoder : Json.Decoder (List String)
defaultScopeDecoder =
    Internal.scopeDecoder


{-| Json decoder for a 'scope', allowing comma- or space-separated scopes
-}
lenientScopeDecoder : Json.Decoder (List String)
lenientScopeDecoder =
    Internal.lenientScopeDecoder


{-| Json decoder for an 'access\_token'
-}
defaultTokenDecoder : Json.Decoder Token
defaultTokenDecoder =
    Internal.tokenDecoder


{-| Json decoder for a 'refresh\_token'
-}
defaultRefreshTokenDecoder : Json.Decoder (Maybe Token)
defaultRefreshTokenDecoder =
    Internal.refreshTokenDecoder


{-| Json decoder for 'error' field
-}
defaultErrorDecoder : Json.Decoder ErrorCode
defaultErrorDecoder =
    Internal.errorDecoder errorCodeFromString


{-| Json decoder for 'error\_description' field
-}
defaultErrorDescriptionDecoder : Json.Decoder (Maybe String)
defaultErrorDescriptionDecoder =
    Internal.errorDescriptionDecoder


{-| Json decoder for 'error\_uri' field
-}
defaultErrorUriDecoder : Json.Decoder (Maybe String)
defaultErrorUriDecoder =
    Internal.errorUriDecoder
