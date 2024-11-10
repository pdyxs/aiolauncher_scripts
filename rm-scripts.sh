source ./env

TO_RM="ru samples"

for repo in $TO_RM; do
    cd $repo
    for script in *.lua; do
        ../../platform-tools/adb shell rm -rf $SCRIPTS_DIR/$script
    done
    cd ..
done