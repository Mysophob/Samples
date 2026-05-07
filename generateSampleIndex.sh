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

# Check for existing strudel.json to use as default repo URL
DEFAULT_REPO_URL=""
EXISTING_JSON="$SAMPLE_ROOT/strudel.json"
if [ -f "$EXISTING_JSON" ]; then
    # Extract _base value from existing JSON
    EXISTING_BASE=$(grep -oP '"_base"\s*:\s*"\K[^"]+' "$EXISTING_JSON" 2>/dev/null)
    if [ -n "$EXISTING_BASE" ]; then
        # Convert raw URL back to normal GitHub URL
        # https://raw.githubusercontent.com/user/repo/branch/ -> https://github.com/user/repo
        if [[ "$EXISTING_BASE" =~ ^https://raw\.githubusercontent\.com/([^/]+/[^/]+) ]]; then
            DEFAULT_REPO_URL="https://github.com/${BASH_REMATCH[1]}"
        else
            DEFAULT_REPO_URL="$EXISTING_BASE"
        fi
        echo "  Found existing strudel.json with repo: $DEFAULT_REPO_URL"
    fi
fi

# Prompt for GitHub repo URL
if [ -n "$DEFAULT_REPO_URL" ]; then
    read -p "GitHub repo URL [default: $DEFAULT_REPO_URL]: " REPO_URL
    REPO_URL="${REPO_URL:-$DEFAULT_REPO_URL}"
else
    read -p "GitHub repo URL: " REPO_URL
fi

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
echo "=== Index Complete ==="
echo "  Total files indexed: $TOTAL_FILES"
echo "  Output written to: $OUTPUT_PATH"
echo ""

# Extract user/repo from the repo URL for the strudel snippet
GITHUB_PATH=""
if [[ "$REPO_URL" =~ ^https://github\.com/(.+)$ ]]; then
    GITHUB_PATH="${BASH_REMATCH[1]}"
fi

# Autopush to git
read -p "Autopush files to git repo? [y/N]: " AUTOPUSH
if [[ "$AUTOPUSH" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Pushing to git..."

    cd "$SAMPLE_ROOT" || { echo "Error: Could not cd to $SAMPLE_ROOT"; exit 1; }

    # Check if inside a git repo
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Error: '$SAMPLE_ROOT' is not inside a git repository."
        echo "  Run 'git init' first, or check your path."
        exit 1
    fi

    git add .
    git commit -m "Update sample index ($TOTAL_FILES files indexed)"

    if git push; then
        echo ""
        echo "=== Push Complete ==="
    else
        echo ""
        echo "Error: git push failed. Check your remote configuration."
        exit 1
    fi
else
    echo "Skipping git push."
fi

# Print strudel usage snippet
echo ""
echo "=== Use in Strudel ==="
if [ -n "$GITHUB_PATH" ]; then
    echo ""
    echo "  samples('github:$GITHUB_PATH')"
    echo ""
else
    echo ""
    echo "  samples('github:user/repo')  (replace with your GitHub path)"
    echo ""
fi
