#!/bin/bash

# Script to push git changes to the remote repository

echo "Pushing git changes to remote repository..."

# Check if there are any uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "There are uncommitted changes. Please commit them first."
    exit 1
fi

# Check if there are any commits to push
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null)
if [ -z "$AHEAD" ]; then
    echo "Unable to determine if there are commits to push. Make sure the remote is configured."
    exit 1
elif [ "$AHEAD" -eq "0" ]; then
    echo "No commits to push. Your local branch is up to date with the remote."
    exit 0
fi

# Push changes to the remote repository
git push

if [ $? -eq 0 ]; then
    echo "Successfully pushed $AHEAD commit(s) to the remote repository."
else
    echo "Failed to push changes. Please check your remote repository configuration."
    exit 1
fi

echo "Done."