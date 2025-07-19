source ./env

for repo in $REPOS; do
    adb push $repo/*.lua $SCRIPTS_DIR
done