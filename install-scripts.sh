source ./env

for repo in $REPOS; do
    adb push $repo/*.lua $SCRIPTS_DIR
    if [ -d "$repo/core" ]; then
        adb push $repo/core/*.lua $SCRIPTS_DIR/core
    fi
done