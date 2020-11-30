#!/bin/bash

set -e

if [ -z "$GH_TOKEN" ]
then
  echo "You must provide the action with a GitHub Personal Access Token secret in order to deploy."
  exit 1
fi

if [ -z "$BRANCH" ]
then
  echo "You must provide the action with a branch name it should deploy to, for example gh-pages or docs."
  exit 1
fi

if [ -z "$FOLDER" ]
then
  echo "You must provide the action with the folder name in the repository where your compiled page lives."
  exit 1
fi

case "$FOLDER" in /*|./*)
  echo "The deployment folder cannot be prefixed with '/' or './'. Instead reference the folder name directly."
  exit 1
esac

if [ -z "$COMMIT_EMAIL" ]
then
  COMMIT_EMAIL="${GITHUB_ACTOR}@users.noreply.github.com"
fi

if [ -z "$COMMIT_NAME" ]
then
  COMMIT_NAME="${GITHUB_ACTOR}"
fi
if [ -z "$TARGET_REPOSITORY" ]
then
  TARGET_REPOSITORY="${GITHUB_REPOSITORY}"
fi

# Installs Git.
apt-get update && \
apt-get install -y git && \

# Directs the action to the the Github workspace.
cd $GITHUB_WORKSPACE && \

# Base branch will be always the current branch
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD) && \

# Configures Git.
git init && \
git config --global user.email "${COMMIT_EMAIL}" && \
git config --global user.name "${COMMIT_NAME}" && \

## Initializes the repository path using the access token.
REPOSITORY_PATH="https://${GH_TOKEN}@github.com/${TARGET_REPOSITORY}.git" && \

## Clone the target repository
git clone "$REPOSITORY_PATH" docs && \
cd docs \

# Checks to see if the remote exists prior to deploying.
# If the branch doesn't exist it gets created here as an orphan.
if [ "$(git ls-remote --heads "$REPOSITORY_PATH" "$BRANCH" | wc -l)" -eq 0 ];
then
  echo "Creating remote branch ${BRANCH} as it doesn't exist..."
  git checkout "${BASE_BRANCH}" && \
  git checkout --orphan $BRANCH && \
  git rm -rf . && \
  touch README.md && \
  git add README.md && \
  git commit -m "Initial ${BRANCH} commit" && \
  git push $REPOSITORY_PATH $BRANCH
fi

# Checks out the base branch to begin the deploy process.
git checkout "${BASE_BRANCH}" && \

# Builds the project if a build script is provided.
echo "Running build scripts... $BUILD_SCRIPT" && \
eval "$BUILD_SCRIPT" && \

if [ "$CNAME" ]; then
  echo "Generating a CNAME file in in the $FOLDER directory..."
  echo $CNAME > $FOLDER/CNAME
fi

# Commits the data to Github.
echo "Deploying to GitHub..." && \
git fetch && \
git checkout -b $BRANCH origin/$BRANCH  && \
  
if [ -z "$VERSION" ]
then
  echo "No Version. Publishing Snapshot of Docs"
  mkdir -p snapshot
  cp -r "../$FOLDER/." ./snapshot/
  git add snapshot/*
else 
    echo "Publishing $VERSION of Docs"
    if [ -z "$BETA" ] || [ "$BETA" = "false" ]
    then 
      echo "Publishing Latest Docs"
      mkdir -p latest
      cp -r "../$FOLDER/." ./latest/
      git add latest/*
    fi   

    majorVersion=${VERSION:0:4}
    majorVersion="${majorVersion}x"

    mkdir -p "$VERSION"
    cp -r "../$FOLDER/." "./$VERSION/"
    git add "$VERSION/*"
    
    mkdir -p "$majorVersion"
    cp -r "../$FOLDER/." "./$majorVersion/"
    git add "$majorVersion/*"
fi


git commit -m "Deploying to ${BRANCH} - $(date +"%T")" --quiet && \
git push "https://$GITHUB_ACTOR:$GH_TOKEN@github.com/$TARGET_REPOSITORY.git" gh-pages || true && \
git checkout "${BASE_BRANCH}" && \
echo "Deployment succesful!"
