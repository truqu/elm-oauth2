# Changelog

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
