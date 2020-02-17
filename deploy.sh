#!/bin/bash

function untag () {
  git tag -d $1
  git push origin --delete $1
}

## Verify nothing is unstaged or untracked
status=$(git status -s)
if [ -n "$status" ]; then
  echo "branch isn't clean: commit staged files and / or discard untracked files!"
  echo $status
  exit 1
fi

## Verify code compiles
echo "compiling library" && elm make || exit 1
for d in $(ls -d examples/providers/**/**) ; do
  cd $d
  mkdir -p dist
  echo "compiling $d" && elm make --optimize "Main.elm" --output="dist/app.min.js" || exit 1
  cd -
done
rm -f index.html

## Get version number
version=$(cat elm.json | grep '"version"' | sed 's/\([^0-9]*\)\([0-9]\.[0-9]\.[0-9]\)\(.*\)/\2/')
if [ -z "$version" ]; then
  echo "unable to capture package version"
  exit 1
else
  echo "VERSION: $version"
fi

## Create tag and publish
trap 'untag $version' 1
git tag -d $version 1>/dev/null 2>&1
git tag -a $version -m "release version $version" && git push origin $version
elm publish || exit 1


## Deploy examples
source ./deploy_examples.sh
deploy_examples $version
