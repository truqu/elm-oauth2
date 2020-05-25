# Examples

## Pre-Requisite

:snake: Python 2+ | :hammer: Make 3+ | :curly_loop: Elm 0.19

## Building 

General command:

```console
$ make {provider}/{flow}
```

Concrete examples:

```console
$ make google/implicit
cd providers/google/implicit && elm make --optimize --output=../../../dist/app.min.js *.elm
Success!     

    Main ───> ../../../dist/app.min.js

$ make auth0/authorization-code
cd providers/auth0/authorization-code && elm make --optimize --output=../../../dist/app.min.js *.elm
Success!     

    Main ───> ../../../dist/app.min.js
```

## Running

```console
$ make start
python -m SimpleHTTPServer
Serving HTTP on 0.0.0.0 port 8000 ...
```

Then, visit http://localhost:8000/
