#!/bin/bash

APP_NAME="Bezel"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
APP_PATH=$(find "$DERIVED_DATA" -name "$APP_NAME.app" -path "*/Debug/*" 2>/dev/null | head -1)

build() {
    echo "Building $APP_NAME..."
    xcodebuild -scheme "$APP_NAME" -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"
}

run() {
    echo "Running $APP_NAME..."
    pkill -f "$APP_NAME.app" 2>/dev/null
    sleep 0.3
    if [ -n "$APP_PATH" ]; then
        open "$APP_PATH"
    else
        echo "Error: App not found. Run './run.sh build' first."
        exit 1
    fi
}

case "$1" in
    build)
        build
        ;;
    run)
        run
        ;;
    br|build-run)
        build && run
        ;;
    *)
        echo "Usage: ./run.sh [build|run|br]"
        echo "  build     - Build the project"
        echo "  run       - Run the app (kills existing instance)"
        echo "  br        - Build and run"
        exit 1
        ;;
esac
