#!/bin/bash
# Deploy docs to github using Travis CI - based on this gist https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

# Get ROSS version
ROSS_VERSION=$(python -c "import ross; print(ross.__version__[:3])")

echo "Building and deploying ross-website version $ROSS_VERSION"
set -e # Exit with nonzero exit code if anything fails

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$ROSS_VERSION" ]; then
    echo "TRAVIS_PULL_REQUEST: $TRAVIS_PULL_REQUEST"
    echo "TRAVIS_BRANCH: $TRAVIS_BRANCH"
    echo "Skipping documentation deployment. This is done only on current released version."
    exit 0
fi

echo "Python version: $TRAVIS_PYTHON_VERSION"
if [ $TRAVIS_PYTHON_VERSION != '3.7' ]; then
    echo "Skipping documentation deployment. This is done only on the 3.7 build"
    exit 0
fi

# get ssh keys
echo "Getting keys on $PWD"
echo "key: $encrypted_904ffbd6830c_key"
echo "iv: $encrypted_904ffbd6830c_iv"

openssl aes-256-cbc -K $encrypted_904ffbd6830c_key -iv $encrypted_904ffbd6830c_iv -in deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

cd $HOME
# clone with ssh
git clone git@github.com:ross-rotordynamics/ross-website.git ross-website/html

# Delete all existing contents except .git and deploy_key.enc (we will re-create them)
echo "Removing existing content"
cd $HOME/ross-website/html
find -maxdepth 1 ! -name .git ! -name .gitignore ! -name . | xargs rm -rf

cd $HOME/build/ross-rotordynamics/ross/docs
git checkout $ROSS_VERSION
echo "Building html files"
make html BUILDDIR=$HOME/ross-website

cd $HOME/ross-website/html
git config user.name "Travis CI"
git config user.email "raphaeltimbo@gmail.com"

# If there are no changes (e.g. this is a README update) then just bail.
echo "Checking diff"
if [ -z `git diff --exit-code` ]; then
    echo "No changes to the spec on this push; exiting."
    exit 0
fi

echo "Commiting changes"
git add .
git commit -m "Docs deployed from Travis CI - build: $TRAVIS_BUILD_NUMBER"

echo "Pushing to repository"
git push git@github.com:ross-rotordynamics/ross-website.git master
