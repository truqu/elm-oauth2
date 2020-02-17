#!/bin/bash

function deploy_examples () {
  version=$1

  git branch -D gh-pages-$version
  git checkout --orphan gh-pages-$version
  git reset

  cd examples/providers
  for d in $(ls -d **/** | grep -v README); do
    mkdir -p ../../$d
    cp -r ../index.html ../assets $d/dist ../../$d
    git add -f ../../$d/assets
    git add -f ../../$d/dist/app.min.js
    git add -f ../../$d/index.html
  done
  cd -
  git commit -m "$version"
  git branch -M gh-pages && git push origin -f HEAD
  git checkout -f master
}
