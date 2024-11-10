source ./env


for repo in $REPOS; do
    ../platform-tools/adb push $repo/*.lua $SCRIPTS_DIR
done

