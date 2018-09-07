#!/bin/bash

function deploy_examples () {
  version=$1
  examples=$2

  git checkout "gh-pages" || exit 1
  git merge --squash -X theirs -
  git reset *.html
  git commit -m "tmp"

  cd examples
  for d in $examples ; do
    elm make --optimize --output $d/bundle.min.js "$d/Main.elm"
    git add -f $d/bundle.min.js
    git add -f $d/index.html
  done
  git commit -m "release version $version"
  git rebase  -X ours HEAD~ --onto HEAD~2
  git push origin HEAD
  git checkout -
}
