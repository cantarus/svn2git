#!/bin/bash
showHelp() {
    echo "Usage: svn2git.sh -s|--svn SVN_REPO_URL"
    echo "-------------------------------------------------------------"
    echo 
    echo "Create a new and empty git repository on a remote server. Run this script"
    echo " to clone an svn repository into a git repository and upload it on the server."
    echo "If you don't provide a remote git repository address the git repo will stay locally"

}

cantarusUsername2GitUser() {
    username=$1
    if [ -z "$(echo $username | grep '-')" ]; then
        echo "$username = $username <${username}@uknown>"
    else
        name=$(echo $username | cut -d '-' -f 1)
        Name=$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}
        lastname=$(echo $username | cut -d '-' -f 2)
        Lastname=$(tr '[:lower:]' '[:upper:]' <<< ${lastname:0:1})${lastname:1}
        email="${name}.${lastname}@cantarus.com"
        echo "$username = $Name $Lastname <${email}>"
    fi

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

echo "Detecting users"
authors=$(svn log ${SVN_REPO} | grep -E "r[0-9]+.*" | cut -d '|' -f 2 | sort -u)
echo "Converting them to git compatible users"
[ -f "usernames.txt" ] && rm usernames.txt
touch usernames.txt
for author in $authors; do
    cantarusUsername2GitUser $author >>usernames.txt
done
echo "Cloning with svn port"
git svn clone "file://${SVN_TEST_DIR}" -T trunk -b branches -t tags --authors-file="usernames.txt" --prefix=origin/ || {

    echo "Try to clean /tmp folder and try again"
    exit 1
}

echo "Git repository:"
mv tmp_svn "$(basename ${SVN_REPO})".git
echo "$(pwd)/$(basename ${SVN_REPO}).git"
echo "Cleaning up"
rm -rf "$(dirname ${SVN_TEST_DIR})"
rm usernames.txt