#!/bin/bash
set -eo pipefail

echo "========================================"
echo " Cloudron App Automated Deploy Script"
echo "========================================"

# Configuration
REGISTRY="sentientlemon/odoocommunity"
APP_DOMAIN="odootest2.schneider-systems.com"
MANIFEST="CloudronManifest.json"

if [ ! -f "$MANIFEST" ]; then
    echo "Error: $MANIFEST not found in current directory!"
    exit 1
fi

# Bump version using a quick Python script
echo "Bumping version in $MANIFEST..."
NEW_VERSION=$(python3 -c "
import json
with open('$MANIFEST', 'r') as f:
    data = json.load(f)
v = data.get('version', '1.0.0')
parts = v.split('.')
parts[-1] = str(int(parts[-1]) + 1)
new_v = '.'.join(parts)
data['version'] = new_v
with open('$MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
print(new_v)
")

echo "New version: $NEW_VERSION"
IMAGE_TAG="$REGISTRY:$NEW_VERSION"

# Build Image
echo ""
echo "=> Building Docker image: $IMAGE_TAG"
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build -t "$IMAGE_TAG" .

# Push Image
echo ""
echo "=> Pushing Docker image to registry..."
docker push "$IMAGE_TAG"

# Update Cloudron App
echo ""
echo "=> Updating Cloudron app at $APP_DOMAIN..."
cloudron update --app "$APP_DOMAIN" --image "$IMAGE_TAG"

echo ""
echo "========================================"
echo " Deployment Complete! App updated to $NEW_VERSION"
echo "========================================"
