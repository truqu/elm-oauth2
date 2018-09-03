#!/bin/bash

if [[ -z $(which tmux) ]]; then
  echo "tmux is required to run this script\n"
  echo "https://github.com/tmux/tmux/wiki"
  exit 1
fi

if [[ -z $(which entr) ]]; then
  echo "entr is required to run this script"
  echo "http://entrproject.org/"
  exit 1
fi

function killServer {
  tmux kill-session -t elm-oauth2
}

function startServer {
  tmux new-session -d -s elm-oauth2 -c examples 'python -m SimpleHTTPServer'
}

trap killServer EXIT

startServer && echo "Listening on port :8000"

find . -type f -name '*.elm' ! -path '*elm-stuff*' | entr -s '\
  elm make && cd examples &&\
  elm make authorization-code/Main.elm --output authorization-code/bundle.min.js &&\
  elm make implicit/Main.elm --output implicit/bundle.min.js'
