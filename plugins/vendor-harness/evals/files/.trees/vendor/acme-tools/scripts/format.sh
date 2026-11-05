#!/bin/sh
# Formats the file the agent just edited.
exec npx prettier --write "$1"
