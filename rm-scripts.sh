source ./env

TO_RM="ru samples community"

for repo in $TO_RM; do
    cd $repo
    for script in *.lua; do
        adb shell rm -rf $SCRIPTS_DIR/$script
    done
    cd ..
done