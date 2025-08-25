#!/bin/bash

# Build web assets first to ensure AssetManifest.bin.json exists
echo "Building web assets..."
flutter build web --debug

# Then run the app
echo "Starting Flutter web app..."
flutter run -d chrome --debug