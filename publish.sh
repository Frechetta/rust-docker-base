#!/bin/bash
set -euo pipefail

IMAGE_NAME="rust-build-base"
REMOTE_IMAGE_NAME="frechetta93/$IMAGE_NAME"

docker tag "$IMAGE_NAME" "$REMOTE_IMAGE_NAME"
docker push "$REMOTE_IMAGE_NAME"
