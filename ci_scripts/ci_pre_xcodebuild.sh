#!/bin/sh

# Echo the OPENAI_KEY environment variable into Secrets.xcconfig
# This script assumes Secrets.xcconfig is at the root of your project.
# The path $CI_PRIMARY_REPOSITORY_PATH is an Xcode Cloud environment variable 
# that points to the root of your cloned repository.

echo "OPENAI_KEY = $OPENAI_KEY" > "$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig"

echo "Secrets.xcconfig successfully generated with OPENAI_KEY." 