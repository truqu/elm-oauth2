#!/bin/sh

## Verify nothing is unstaged or untracked
status=$(git status -s)
if [ -n "$status" ]; then
  echo "branch isn't clean: commit staged files and / or discard untracked files!"
  echo $status
  exit 1
fi

## Verify code compiles
elm make || exit 1
for d in examples/*; do
  if [ "$d" != "examples/images" ]; then
    elm make "$d/Main.elm" || exit 1
  fi
done
rm -f index.html

## Get version number
version=$(cat elm-package.json | grep '"version"' | sed 's/\([^0-9]*\)\([0-9]\.[0-9]\.[0-9]\)\(.*\)/\2/')
if [ -z "$version" ]; then
  echo "unable to capture package version"
  exit 1
else
  echo "VERSION: $version"
fi

## Create tag and publish
git tag -a $version -m "release version $version" && git push origin HEAD --tags
elm package publish || exit 1

## Deploy examples
git checkout "gh-pages" || exit 1
for d in examples/*; do
  if [ "$d" != "examples/images" ]; then
    elm make "$d/Main.elm"
    mv index.html $d
  fi
done
git add . && git commit -m "release version $version"
git push origin HEAD && git checkout -

echo "==========\nDONE."
