#!/bin/bash
set -e

REGISTRY_IP="${REGISTRY:-192.168.31.229:5444}"
IMAGE="${IMAGE:-code-server-base}"
VERSION=$(git rev-parse --short=6 HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
PLATFORMS="linux/amd64"

echo "Building multi-arch image for: ${PLATFORMS}"
echo "Registry: ${REGISTRY_IP}"
echo "Image: ${IMAGE}"
echo "Version: ${VERSION}"
echo "-------------------------------------------"

#docker buildx create --name multiarch-builder --driver docker-container --use multiarch-builder
if ! docker buildx inspect multiarch-builder >/dev/null 2>&1; then
    echo "Creating multiarch builder..."
    docker buildx create --name multiarch-builder --driver docker-container --use
fi

# Use the multiarch builder
docker buildx use multiarch-builder
docker buildx inspect --bootstrap

# === BUILD AND PUSH AMD64 ===
docker buildx build \
  --platform linux/amd64 \
  --build-arg VERSION="${VERSION}" \
  --build-arg DOCKER_GID=972 \
  --build-arg INSTALL_LATEX="true" \
  --build-arg INSTALL_ANSIBLE="true" \
  -t "${REGISTRY_IP}/${IMAGE}:${VERSION}" \
  -t "${REGISTRY_IP}/${IMAGE}:latest" \
  --push .

echo "✅ Multi-arch image pushed successfully"
digest=$(docker buildx imagetools inspect ${REGISTRY_IP}/${IMAGE}:${VERSION} 2>/dev/null | grep "Digest:" | awk '{print $2}' || echo "unknown")
printf "| %-17s %-30s |\n" "Digest:" "$digest"

#echo "Cleaning up dangling images..."
#docker builder prune -f

docker buildx prune --builder multiarch-builder -f
echo "===================================================="
echo "|           ✅ Docker Build Summary                |"
echo "===================================================="
printf "| %-17s %-30s |\n" "Image Name:"     "$IMAGE"
printf "| %-17s %-30s |\n" "Registry:"       "$REGISTRY_IP"
printf "| %-17s %-30s |\n" "Version Tag:"    "$VERSION"
printf "| %-17s %-30s |\n" "Latest Tag:"     "latest"
printf "| %-17s %-30s |\n" "Built & Pushed:" "${VERSION}-amd64"
printf "| %-17s %-30s |\n" "Manifest:"       "$VERSION"
printf "| %-17s %-30s |\n" "Manifest:"       "latest"
printf "| %-17s %-30s |\n" "Cleaned:"        "${VERSION}-amd64 (remote + local)"
echo "===================================================="