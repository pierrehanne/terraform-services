#!/bin/bash
set -euo pipefail

# --- Parameters ---
PROJECT_NAME="${1:?Missing PROJECT_NAME}"
REGION="${2:?Missing REGION}"
TIMEOUT="${3:?Missing TIMEOUT (seconds)}"
LAYER_NAME="${4:-}"
S3_PREFIX="${5:-}"
S3_BUCKET="${6:-}"

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: TIMEOUT must be an integer number of seconds"
  exit 1
fi

echo "Starting CodeBuild project '$PROJECT_NAME' in region '$REGION' with timeout ${TIMEOUT}s..."
[[ -n "$LAYER_NAME" ]] && echo "Lambda Layer: $LAYER_NAME"
[[ -n "$S3_BUCKET" ]] && echo "S3: $S3_BUCKET/$S3_PREFIX"

# --- Start build ---
BID=$(aws codebuild start-build \
      --project-name "$PROJECT_NAME" \
      --region "$REGION" \
      --query 'build.id' --output text)

echo "Build started: $BID"

# --- Wait for completion ---
END=$(( $(date +%s) + TIMEOUT ))

while [ $(date +%s) -lt $END ]; do
    STATUS=$(aws codebuild batch-get-builds \
             --ids "$BID" \
             --region "$REGION" \
             --query 'builds[0].buildStatus' --output text)

    REMAINING=$((END - $(date +%s)))
    echo "[$REMAINING s left] Status: $STATUS"

    case "$STATUS" in
        SUCCEEDED)
            echo "Build succeeded!"
            exit 0
            ;;
        FAILED|FAULT|STOPPED|TIMED_OUT)
            echo "Build failed with status: $STATUS"
            exit 1
            ;;
    esac

    sleep 15
done

# --- Timeout handling ---
echo "Build timeout reached (${TIMEOUT}s). Stopping build $BID..."
aws codebuild stop-build --id "$BID" --region "$REGION" >/dev/null 2>&1
exit 1