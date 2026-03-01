#!/bin/bash
set -euo pipefail

IMAGE_NAME="rust-build-base"

docker build -t "$IMAGE_NAME" .
