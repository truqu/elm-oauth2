<details>
  <summary>Understanding OAuth roles</summary>

Throughout the library, you'll find terms referring to OAuth well-defined roles:

- **`resource owner`**  
  _An entity capable of granting access to a protected resource.
  When the resource owner is a person, it is referred to as an
  end-user._

- **`client`**  
  _An application making protected resource requests on behalf of the
  resource owner and with its authorization. The term "client" does
  not imply any particular implementation characteristics (e.g.,
  whether the application executes on a server, a desktop, or other
  devices)._

- **`authorization server`**  
  _The server issuing access tokens to the client after successfully
  authenticating the resource owner and obtaining authorization._

- **`resource server`**  
  _The server hosting the protected resources, capable of accepting
  and responding to protected resource requests using access tokens._

> NOTE: Usually, the _authorization server_ and the _resource server_ are
> a same entity, or comes from the same entity. So, a simplified vision of
> this roles can be:
>
> - **`resource owner`**  
>   The end-user
> 
> - **`client`**  
>   Your Elm app
> 
> - **`authorization server`** / **`resource server`**  
>   Google, Facebook, Twitter or whatever OAuth provider you're talking to
</details>

<details>
  <summary>Authentication requests in the _Authorization Flow_ don't go through </summary>

Most authorization servers don't enable CORS on the authentication endpoints. For this reason,
it's likely that the preflight _OPTIONS_ requests sent by the browser return an invalid
answer, preventing the browser from making the request at all. 

Why is it so? The authorization request _usually_requires one's secret; thus making them 
rather impractical to perform from a client-side application without exposing those secrets.
As a security measure, most authorization servers choose to enforce that those requests are
made server-side instead. 

Generally, this is also what you want, unless you're dealing with a custom authorization server 
in some sort of isolated environment. OAuth 2.0 is designed to cover all sort of delegation of
permissions, the case of user-facing client-side applications is only one of them; some 
authorization flows are therefore not necessarily adapted to these cases. Usually, a client-side
application will prefer the _Implicit Flow_ over the others.
</details>

> Still having an issue?
>
> Please [open a ticket](https://github.com/truqu/elm-oauth2/issues/new) and let us know :heart:!
