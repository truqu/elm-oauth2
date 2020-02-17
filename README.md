Elm OAuth 2 [![](https://img.shields.io/badge/package.elm--lang.org-7.0.0-60b5cc.svg?style=flat-square)](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest) 
=====

This package offers some utilities to implement a client-side [OAuth 2](https://tools.ietf.org/html/rfc6749) authorization in Elm. 
It covers all four basic grant types as well as the [PKCE](https://tools.ietf.org/html/rfc7636) extension:

- [Authorization Code w/ PKCE (Recommended)](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-AuthorizationCode-PKCE):
  An extension of the original OAuth 2.0 specification to mitigate authorization code interception attacks
  through the use of Proof Key for Code Exchange (PKCE). **FOR CONFIDENTIAL CLIENTS** such as the device
  operating system or a highly privileged application that has been issued credentials for authenticating
  with the authorization server (e.g. a client id).

- [Authorization Code](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-AuthorizationCode):
  The token is obtained as a result of an authentication, from a code obtained as a result of a
  user redirection to an OAuth provider. The authorization code grant type is used to obtain both access
  tokens and refresh tokens and is optimized **FOR CONFIDENTIAL CLIENTS** such as the device operating system 
  or a highly privileged application that has been issued credentials for authenticating with the authorization
  server (e.g. a client id).

- [Implicit](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Implicit):
  The most commonly used. The token is obtained directly as a result of a user redirection to
  an OAuth provider. The implicit grant type is used to obtain access tokens (it does not
  support the issuance of refresh tokens) and is optimized **FOR PUBLIC CLIENTS**.

- [Resource Owner Password Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-Password):
  The token is obtained directly by exchanging the user credentials with an OAuth provider. The resource owner password 
  credentials grant type is suitable in cases **WHERE THE RESOURCE OWNER HAS A TRUST RELATIONSHIP WITH THE CLIENT**.

- [Client Credentials](http://package.elm-lang.org/packages/truqu/elm-oauth2/latest/OAuth-ClientCredentials):
  The token is obtained directly by exchanging application credentials with an OAuth provider. The client credentials
  grant type **MUST ONLY BE USED BY CONFIDENTIAL CLIENTS**.

## Getting Started

### Installation

```
elm install truqu/elm-oauth2
```

### Examples / Demos

- [Auth0](https://github.com/truqu/elm-oauth2/tree/master/examples/providers/auth0)
- [Facebook](https://github.com/truqu/elm-oauth2/tree/master/examples/providers/facebook)
- [Google](https://github.com/truqu/elm-oauth2/tree/master/examples/providers/google)
- [Spotify](https://github.com/truqu/elm-oauth2/tree/master/examples/providers/spotify)

### Troubleshooting

[TROUBLESHOOTING.md](https://github.com/truqu/elm-oauth2/tree/master/TROUBLESHOOTING.md)

## Changelog

[CHANGELOG.md](https://github.com/truqu/elm-oauth2/tree/master/CHANGELOG.md)
