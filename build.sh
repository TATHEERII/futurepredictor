#!/bin/bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

# Build the web app
flutter pub get
flutter build web
