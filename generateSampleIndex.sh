#!/bin/bash

# Interactive Strudel Sample Index Generator

echo "=== Strudel Sample Index Generator ==="
echo ""

# Prompt for sample root directory
read -e -p "Sample root directory (default: current directory): " SAMPLE_ROOT

# Default to current directory if empty
if [ -z "$SAMPLE_ROOT" ]; then
    SAMPLE_ROOT="."
fi

# Expand ~ and resolve path
SAMPLE_ROOT="${SAMPLE_ROOT/#\~/$HOME}"
SAMPLE_ROOT="$(realpath "$SAMPLE_ROOT" 2>/dev/null)"

if [ ! -d "$SAMPLE_ROOT" ]; then
    echo "Error: Directory '$SAMPLE_ROOT' does not exist."
    exit 1
fi

echo "  Found directory: $SAMPLE_ROOT"

# Show available subfolders
SUBFOLDER_COUNT=$(find "$SAMPLE_ROOT" -maxdepth 1 -mindepth 1 -type d | wc -l)
echo "  Subfolders found: $SUBFOLDER_COUNT"
if [ "$SUBFOLDER_COUNT" -eq 0 ]; then
    echo "Error: No subfolders found in '$SAMPLE_ROOT'. Nothing to index."
    exit 1
fi
echo ""

# Prompt for GitHub repo URL
read -p "GitHub repo URL (default: https://github.com/user/repo): " REPO_URL

# Strip trailing slashes
REPO_URL="${REPO_URL%/}"

# Prompt for branch
read -p "Branch [default: main]: " BRANCH
BRANCH="${BRANCH:-main}"

# Convert to raw URL
# Handles both formats:
#   https://github.com/user/repo       -> https://raw.githubusercontent.com/user/repo/main/
#   https://raw.githubusercontent.com/… -> kept as-is
if [[ "$REPO_URL" =~ ^https://github\.com/(.+)$ ]]; then
    BASE_URL="https://raw.githubusercontent.com/${BASH_REMATCH[1]}/$BRANCH/"
elif [[ "$REPO_URL" =~ ^https://raw\.githubusercontent\.com/ ]]; then
    BASE_URL="$REPO_URL"
    [[ "$BASE_URL" != */ ]] && BASE_URL="$BASE_URL/"
else
    echo "Warning: URL doesn't look like a GitHub link. Using as-is."
    BASE_URL="$REPO_URL"
    [[ "$BASE_URL" != */ ]] && BASE_URL="$BASE_URL/"
fi

echo "  Resolved base URL: $BASE_URL"
echo ""

# Prompt for output file
read -e -p "Output file name [default: strudel.json]: " OUTPUT_FILE
OUTPUT_FILE="${OUTPUT_FILE:-strudel.json}"
OUTPUT_PATH="$SAMPLE_ROOT/$OUTPUT_FILE"

# Warn if output file already exists
if [ -f "$OUTPUT_PATH" ]; then
    read -p "  File already exists. Overwrite? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi
echo ""

# Prompt for file extension to index
read -p "File extension to index [default: wav]: " FILE_EXT
FILE_EXT="${FILE_EXT:-wav}"
FILE_EXT="${FILE_EXT#.}"  # strip leading dot if user typed ".wav"
echo ""

# Build JSON
echo "Scanning folders..."

JSON="{\n  \"_base\": \"$BASE_URL\""
TOTAL_FILES=0

for folder in "$SAMPLE_ROOT"/*/; do
    [ -d "$folder" ] || continue

    SUB_FOLDER_NAME="$(basename "$folder")"

    FILES=()
    while IFS= read -r -d '' file; do
        FILENAME="$(basename "$file")"
        FILES+=("\"$SUB_FOLDER_NAME/$FILENAME\"")
    done < <(find "$folder" -maxdepth 1 -iname "*.$FILE_EXT" -type f -print0 | sort -z)

    COUNT=${#FILES[@]}
    if [ "$COUNT" -gt 0 ]; then
        TOTAL_FILES=$((TOTAL_FILES + COUNT))
        echo "  $SUB_FOLDER_NAME: $COUNT file(s)"

        JOINED=$(printf ",\n      %s" "${FILES[@]}")
        JSON="$JSON,\n  \"$SUB_FOLDER_NAME\": [\n      ${JOINED:7}\n  ]"
    fi
done

JSON="$JSON\n}"

# Write output
echo -e "$JSON" > "$OUTPUT_PATH"

echo ""
echo "=== Done ==="
echo "  Total files indexed: $TOTAL_FILES"
echo "  Output written to: $OUTPUT_PATH"
