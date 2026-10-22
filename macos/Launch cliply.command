#!/bin/bash
# Double-click in Finder to launch Cliply in Terminal.
DIR="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$DIR/cliply.sh"
