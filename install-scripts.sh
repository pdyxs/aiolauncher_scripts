source ./env


for repo in $REPOS; do
    ../platform-tools/adb push $repo/*.lua $SCRIPTS_DIR
done

for repo in $DUP; do
    for script in $repo/*.lua; do
        file=${script##*/}
        ../platform-tools/adb push $script $SCRIPTS_DIR/${file%.*}2.lua
        ../platform-tools/adb push $script $SCRIPTS_DIR/${file%.*}3.lua
        ../platform-tools/adb push $script $SCRIPTS_DIR/${file%.*}4.lua
    done
done