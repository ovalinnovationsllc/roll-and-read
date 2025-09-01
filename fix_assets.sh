#!/bin/bash

# Fix double assets path in Flutter web build
echo "Fixing asset paths in Flutter service worker..."

# Check if the build directory exists
if [ -d "build/web" ]; then
    # Fix the double assets path in flutter_service_worker.js
    if [ -f "build/web/flutter_service_worker.js" ]; then
        sed -i '' 's|"assets/assets/|"assets/|g' build/web/flutter_service_worker.js
        echo "✓ Fixed asset paths in flutter_service_worker.js"
    fi
    
    # Update cache version to force refresh
    if [ -f "build/web/flutter_service_worker.js" ]; then
        # Generate a timestamp for cache busting
        TIMESTAMP=$(date +%s)
        sed -i '' "s/CACHE_NAME = \"[^\"]*\"/CACHE_NAME = \"flutter-app-cache-$TIMESTAMP\"/" build/web/flutter_service_worker.js
        echo "✓ Updated cache version"
    fi
else
    echo "Build directory not found. Run 'flutter build web' first."
fi

echo "Asset path fixes complete!"