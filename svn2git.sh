#!/bin/bash
showHelp() {
    echo "Usage: svn2git.sh -s|--svn SVN_REPO_URL -g|--git GIT_REPO_URL"
    echo "-------------------------------------------------------------"
    echo 
    echo "Create a new and empty git repository on a remote server. Run this script"
    echo " to clone an svn repository into a git repository and upload it on the server."
    echo "If you don't provide a remote git repository address the git repo will stay locally"

}
if [ "$#" -le "1" ]; then
    showHelp
    exit 1
fi
while [[ $# > 1 ]]; do
    key="$1"
    shift

    case $key in
        -s|--svn)
        SVN_REPO="$1"
        shift
        ;;
        -g|--git)
        GIT_REPO="$1"
        shift
        ;;
        *|\?)
            showHelp
            exit 1
        ;;
    esac
done

echo "Converting SVN Repo $SVN_REPO to $GIT_REPO"
SVN_TEST_DIR="$(mktemp -d /tmp/test_svn.XXX)/tmp_svn"
svnadmin create $SVN_TEST_DIR

echo '#!/bin/sh' >"${SVN_TEST_DIR}/hooks/pre-revprop-change"
echo 'exit 0;' >>"${SVN_TEST_DIR}/hooks/pre-revprop-change"

chmod +x "${SVN_TEST_DIR}/hooks/pre-revprop-change"
svnsync init "file://${SVN_TEST_DIR}" "$SVN_REPO" || {
    echo "Check the error and try again. (probably try https?)"
    exit 1
}
echo "Initialised repository succesfully. Syncing. . ."
svnsync sync "file://${SVN_TEST_DIR}" || {

    echo "Error during sync. WTH happened?"
}

echo "Syncing completed. . . Converting that SVN repo to GIT"

git svn clone "file://${SVN_TEST_DIR}" -T trunk -b branches -t tags || {

    echo "Error. Check line 58, maybe that SVN repo did not follow the default naming convensions"
    exit 1
}

echo "Moving you to your new repository"
mv tmp_svn "$(basename ${SVN_REPO})".git
cd "$(basename ${SVN_REPO}).git"