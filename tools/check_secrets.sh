#!/bin/bash
# Fails if anything tracked by git looks like a curling.dimmit.net sensor app
# key (csk_ and a long run of key characters). Run by make test.
cd "$(dirname "$0")/.."
if git grep -nIE 'csk_[A-Za-z0-9_-]{16,}' -- . ':!tools/check_secrets.sh'; then
    echo "A sensor app key is in the repo: remove it (keys go in the app's settings or the Keychain)" >&2
    exit 1
fi
