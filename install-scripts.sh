source ./env

# Function to create numbered copies of a script
create_copies() {
    local script_path=$1
    local num_copies=$2
    local script_name=$(basename "$script_path" .lua)
    local script_dir=$(dirname "$script_path")

    # Create copies with numbers 2, 3, 4, etc.
    for i in $(seq 2 $num_copies); do
        cp "$script_path" "$script_dir/${script_name}${i}.lua"
    done
}

# Function to clean up numbered copies
cleanup_copies() {
    local repo=$1
    # Remove any previously created numbered copies
    find "$repo" -maxdepth 1 -name "*[0-9].lua" -type f -delete
}

# Read script-copies.conf and create copies
declare -A SCRIPT_COPIES
if [ -f "script-copies.conf" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse script name and number of copies
        read -r script_name num_copies <<< "$line"
        if [ -n "$script_name" ] && [ -n "$num_copies" ]; then
            SCRIPT_COPIES["$script_name"]=$num_copies
        fi
    done < script-copies.conf
fi

# Process each repository
for repo in $REPOS; do
    # Clean up any previously created numbered copies
    cleanup_copies "$repo"

    # Create numbered copies based on configuration
    for script_name in "${!SCRIPT_COPIES[@]}"; do
        script_path="$repo/${script_name}.lua"
        if [ -f "$script_path" ]; then
            create_copies "$script_path" "${SCRIPT_COPIES[$script_name]}"
        fi
    done

    # Push all scripts (including numbered copies)
    adb push $repo/*.lua $SCRIPTS_DIR

    # Push core modules if they exist
    if [ -d "$repo/core" ]; then
        adb push $repo/core/*.lua $SCRIPTS_DIR/core
    fi

    # Clean up numbered copies after pushing
    cleanup_copies "$repo"
done

# Copy selected community scripts
if [ -n "$COMMUNITY_SCRIPTS" ] && [ -d "community" ]; then
    for script_name in $COMMUNITY_SCRIPTS; do
        script_file="community/${script_name}.lua"
        if [ -f "$script_file" ]; then
            adb push "$script_file" "$SCRIPTS_DIR"
        else
            echo "Warning: Community script not found: $script_file"
        fi
    done
fi