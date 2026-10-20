#!/bin/bash
DEST="$HOME/Library/Application Support/AppleRemoteCore/py"
mkdir -p "$DEST"
echo "Installing Apple TV support once..."
python3 -m pip install --disable-pip-version-check --retries 1 --timeout 12 --upgrade --target "$DEST" pyatv
result=$?
if [ "$result" -eq 0 ]; then echo "Success. Return to ARC and press Search."; else echo "Installation failed. Check internet and Python pip."; fi
read -r -p "Press Return to close..." x
exit "$result"
