source ./env


for repo in $REPOS; do
    adb push $repo/*.lua $SCRIPTS_DIR
done

for repo in $DUP; do
    for script in $repo/*.lua; do
        file=${script##*/}
        adb push $script $SCRIPTS_DIR/${file%.*}2.lua
        adb push $script $SCRIPTS_DIR/${file%.*}3.lua
        adb push $script $SCRIPTS_DIR/${file%.*}4.lua
    done
done