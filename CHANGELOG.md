## v8.0.0 (2021-06-30)

- Allow more advanced control for tweaking parsers, decoders and url builders. This is particularly useful for applications integrating with systems which are either not strictly following the OAuth2.0 specifications, or, systems who introduce custom fields of some importance for the underlying application. (see #29, #23, #21)

- Update dependencies for base64 encoding

### Diff

#### `OAuth` - MINOR

- Added:

  ```elm
  type GrantType
      = AuthorizationCode
      | Password
      | ClientCredentials
      | RefreshToken
      | CustomGrant String

  grantTypeToString : GrantType -> String
  ```

  ```elm
  type ResponseType
      = Code
      | Token
      | CustomResponse String

  responseTypeToString : ResponseType -> String
  ```

#### `OAuth.Implicit` - MAJOR 

- Added:

  ```elm
  makeAuthorizationUrlWith :
      ResponseType
      -> Dict String String
      -> Authorization
      -> Url
  ```

- Changed: 

  ```elm
  -- type alias Parsers =
  --     { tokenParser :
  --           Query.Parser (Maybe Token)
  --     , errorParser :
  --           Query.Parser (Maybe ErrorCode)
  --     , authorizationSuccessParser :
  --           String -> Query.Parser AuthorizationSuccess
  --     , authorizationErrorParser :
  --           ErrorCode -> Query.Parser AuthorizationError
  --     }

  type alias Parsers error success =
      { tokenParser :
            Query.Parser (Maybe Token)
      , errorParser :
            Query.Parser (Maybe ErrorCode)
      , authorizationSuccessParser :
            String -> Query.Parser success
      , authorizationErrorParser :
            ErrorCode -> Query.Parser error
      }
  ```

  ```elm
  -- defaultParsers : Parsers
  defaultParsers : Parsers AuthorizationError AuthorizationSuccess
  ```

  ```elm
  -- parseTokenWith : Parsers -> Url -> AuthorizationResult
  parseTokenWith : Parsers error success -> Url -> AuthorizationResultWith error success
  ```

#### `OAuth.AuthorizationCode` - MAJOR

- Added:

  ```elm
  makeAuthorizationUrlWith :
      ResponseType
      -> Dict String String
      -> Authorization
      -> Url
  ```

  ```elm
  makeTokenRequestWith :
      OAuth.GrantType
      -> Json.Decoder success
      -> Dict String String
      -> (Result Http.Error success -> msg)
      -> Authentication
      -> RequestParts msg
  ```

- Changed:

  ```elm
  -- type AuthorizationResult
  --     = Empty
  --     | Error AuthorizationError
  --     | Success AuthorizationSuccess

  type alias AuthorizationResult =
      AuthorizationResultWith AuthorizationError AuthorizationSuccess

  type AuthorizationResultWith error success
      = Empty
      | Error error
      | Success success
  ```

  ```elm
  -- type alias Parsers =
  --     { codeParser :
  --           Query.Parser (Maybe String)
  --     , errorParser :
  --           Query.Parser (Maybe ErrorCode)
  --     , authorizationSuccessParser :
  --           String -> Query.Parser AuthorizationSuccess
  --     , authorizationErrorParser :
  --           ErrorCode -> Query.Parser AuthorizationError
  --     }

  type alias Parsers error success =
      { codeParser :
            Query.Parser (Maybe String)
      , errorParser :
            Query.Parser (Maybe ErrorCode)
      , authorizationSuccessParser :
            String -> Query.Parser success
      , authorizationErrorParser :
            ErrorCode -> Query.Parser error
      }
  ```

  ```elm
  -- defaultParsers : Parsers
  defaultParsers : Parsers AuthorizationError AuthorizationSuccess
  ```

  ```elm
  -- parseCodeWith : Parsers -> Url -> AuthorizationResult
  parseCodeWith : Parsers error success -> Url -> AuthorizationResultWith error success
  ```

#### `OAuth.AuthorizationCode.PKCE` - MAJOR 

- Added:

  ```elm
  makeAuthorizationUrlWith :
      ResponseType
      -> Dict String String
      -> Authorization
      -> Url
  ```

  ```elm
  makeTokenRequestWith :
      OAuth.GrantType
      -> Json.Decoder success
      -> Dict String String
      -> (Result Http.Error success -> msg)
      -> Authentication
      -> RequestParts msg
  ```

- Changed:

  ```elm
  -- type AuthorizationResult
  --     = Empty
  --     | Error AuthorizationError
  --     | Success AuthorizationSuccess

  type alias AuthorizationResult =
      AuthorizationResultWith AuthorizationError AuthorizationSuccess

  type AuthorizationResultWith error success
      = Empty
      | Error error
      | Success success
  ```

  ```elm
  -- type alias Parsers =
  --     { codeParser :
  --           Query.Parser (Maybe String)
  --     , errorParser :
  --           Query.Parser (Maybe ErrorCode)
  --     , authorizationSuccessParser :
  --           String -> Query.Parser AuthorizationSuccess
  --     , authorizationErrorParser :
  --           ErrorCode -> Query.Parser AuthorizationError
  --     }

  type alias Parsers error success =
      { codeParser :
            Query.Parser (Maybe String)
      , errorParser :
            Query.Parser (Maybe ErrorCode)
      , authorizationSuccessParser :
            String -> Query.Parser success
      , authorizationErrorParser :
            ErrorCode -> Query.Parser error
      }
  ```

  ```elm
  -- defaultParsers : Parsers
  defaultParsers : Parsers AuthorizationError AuthorizationSuccess
  ```

  ```elm
  -- parseCodeWith : Parsers -> Url -> AuthorizationResult
  parseCodeWith : Parsers error success -> Url -> AuthorizationResultWith error success
  ```


#### `OAuth.ClientCredentials` - MINOR 

- Added:

  ```elm
  makeTokenRequestWith :
      GrantType
      -> Json.Decoder success
      -> Dict String String
      -> (Result Http.Error success -> msg)
      -> Authentication
      -> RequestParts msg
  ```

#### `OAuth.Password` - MINOR 

- Added:

  ```elm
  makeTokenRequestWith :
      GrantType
      -> Json.Decoder success
      -> Dict String String
      -> (Result Http.Error success -> msg)
      -> Authentication
      -> RequestParts msg
  ```


#### `OAuth.Refresh` - MINOR 

- Added:

  ```elm
  makeTokenRequestWith :
      GrantType
      -> Json.Decoder success
      -> Dict String String
      -> (Result Http.Error success -> msg)
      -> Authentication
      -> RequestParts msg
  ```

## v7.0.1 (2020-12-05)

- Updated dependency `ivadzy/bbase64@1.1.1` renamed as `chelovek0v/bbase64@1.0.1`

## v7.0.0 (2020-02-17)

#### Diff

```elm
---- ADDED MODULES - MINOR ----

    OAuth.AuthorizationCode.PKCE


---- OAuth.AuthorizationCode - MAJOR ----

    Added:
        type alias AuthorizationCode = String.String
    
    Changed:
      - type alias AuthorizationSuccess =
            { code : String, state : Maybe String }
      + type alias AuthorizationSuccess =
            { code : OAuth.AuthorizationCode.AuthorizationCode
            , state : Maybe.Maybe String.String
            }
```

#### Commits

- f1f648a76fcc0e8e33ef06cd9867600164d709d7 add support for RFC7636 - Proof Key for Code Exchange

  Auth 2.0 public clients utilizing the Authorization Code Grant are
  susceptible to the authorization code interception attack.  This
  specification describes the attack as well as a technique to mitigate against
  the threat through the use of Proof Key for Code Exchange (PKCE, pronounced
  "pixy").

- 3dc3c9d6a0aa6d20b84d8ffc79e55aec06beb683 remove double dependency on base64 and favor only one
  
- 6199c78126d59fe0da5ed491f04835087285188a several doc revision on all grants (diagrams, type description etc ...)
  
- 0d969a08dd90079933f747c24cea8c13b9954a07 put PKCE as recommended in README and start reviewing demos / guides
  
- b712fcdec341bb3b07a95fbcf5e77c6794f7da01 rework examples
  - Add auth0 example with authorization code and PKCE support
  - Add facebook example
  - Make them more readable and avoid unrelated code in examples
  - Add README to summarize information

- 68383cfa0d22c29733a219a2849db3cfc2731e63 revise deployment scripts, in particular examples
  
- f86ffe9469f50b9c011505459df380fe071b604c bump version (major) to 7.0.0 & update CHANGELOG


## v6.0.0 (2019-09-03)

- (267ca48) Internal small refactor
- (43e536a) General documentation improvements 
- (e34e16f) Rename 'makeAuthUrl' to 'makeAuthorizationUrl' 
- (12ce2ba) Split-up README, extract troubleshooting and guides 

## v5.0.0 (2019-01-23)

- (d74016e, 333d6ea, 849d985, 78caba7) Upgrade `elm/http` to new major version `2.0.0`


## v4.0.1 (2018-10-06)

- (15e4e82) Bug Fix: make token\_type parsing case-insensitive.


## v4.0.0 (2018-09-07)

- (72f251a, 1327646) Documentation improvements

- (0105ca3, 9a3b307, 5e3c841, 4801593) Review examples to be more complete, self-explanatory and clearer

- (0ac7d90) Completely review internal implementation & exposed API 


## v3.0.0 (2018-09-03) 

- (3a60354) Upgrade `src/` to `elm@0.19`
- (ef85924) Upgrade `examples/implicit` to `elm@0.19`
- (88f27a7) Remove `examples/authorization_code` 
- (7ce7c82) Change `String` to `Url` for 
  - `Authorization.url`
  - `Authorization.redirectUri`
  - `Authentication#AuthorizationCode.redirectUri`
  - `Authentication#AuthorizationCode.url`
  - `Authentication#ClientCredentials.url`
  - `Authentication#Password.url`
  - `Authentication#Refresh.url`
- (912197c) Expose `lenientResponseDecoder` from `OAuth.Decode`


## v2.2.1 (2018-08-16) 

- Bump `elm-base64` version upper-bound


## v2.2.0 (2017-12-22)

- (oversight) Actually expose 'authenticateWithOpts' functions from modules


## v2.1.0 (2017-12-22)

- Expose internal Json decoders 
- Enable users to adjust requests made to the Authorization Server to cope with possible 
  implementation quirks (like GitHub API v3)


## v2.0.3 (2017-06-04)

- Update LICENSE's information
- Fix broken links and examples in README


## v2.0.2 (2017-06-02)

- Fix bug about empty scope parameter being sent when `Nothing` is provided as a scope


## v2.0.1 (2017-06-02)

- Enhance documentation about response parameters

## v2.0.0 (2017-06-02)

- Review type `Response` to provide a clearer API
- Fix typos and references in examples


## v1.0.0 (2017-06-01)

- Initial release, support for all 4 grant types.
