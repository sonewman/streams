#!/bin/bash
set -e

if [ "$DEPLOY_USER" == "" ]; then
    echo "No deploy credentials present; skipping deploy"
    exit 0
fi

LS_URL="https://streams.spec.whatwg.org/"
COMMIT_URL_BASE="https://github.com/whatwg/streams/commit/"
BRANCH_URL_BASE="https://github.com/whatwg/streams/tree/"

SERVER="streams.spec.whatwg.org"
WEB_ROOT="streams.spec.whatwg.org"
COMMITS_DIR="commit-snapshots"
BRANCHES_DIR="branch-snapshots"

SHA="`git rev-parse HEAD`"
BRANCH="`git rev-parse --abbrev-ref HEAD`"
if [ "$BRANCH" == "HEAD" ]; then # Travis does this for some reason
    BRANCH=$TRAVIS_BRANCH
fi

if [ "$BRANCH" == "master" -a "$TRAVIS_PULL_REQUEST" != "false" ]; then
    echo "Skipping deploy for a pull request; the branch build will suffice"
    exit 0
fi

BACK_TO_LS_LINK="<a href=\"$LS_URL\" id=\"commit-snapshot-link\">Go to the living standard</a>"
SNAPSHOT_LINK="<a href=\"https://streams.spec.whatwg.org/commit-snapshots/$SHA\" id=\"commit-snapshot-link\">Snapshot as of this commit</a>"

echo "Branch = $BRANCH"
echo "Commit = $SHA"
echo ""

rm -rf $WEB_ROOT || exit 0

# Commit snapshot
COMMIT_DIR=$WEB_ROOT/$COMMITS_DIR/$SHA
mkdir -p $COMMIT_DIR
curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F md-status=LS-COMMIT \
     -F md-warning="Commit $SHA $COMMIT_URL_BASE$SHA replaced by $LS_URL" \
     -F md-title="Streams Standard (Commit Snapshot $SHA)" \
     -F md-Text-Macro="SNAPSHOT-LINK $BACK_TO_LS_LINK" \
     > $COMMIT_DIR/index.html;
cp *.svg $COMMIT_DIR
echo "Commit snapshot output to $WEB_ROOT/$COMMITS_DIR/$SHA"

if [ $BRANCH != "master" ] ; then
    # Branch snapshot, if not master
    BRANCH_DIR=$WEB_ROOT/$BRANCHES_DIR/$BRANCH
    mkdir -p $BRANCH_DIR
    curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F md-status=LS-BRANCH \
         -F md-warning="Branch $BRANCH $BRANCH_URL_BASE$BRANCH replaced by $LS_URL" \
         -F md-title="Streams Standard (Branch Snapshot $BRANCH)" \
         -F md-Text-Macro="SNAPSHOT-LINK $SNAPSHOT_LINK" \
         > $BRANCH_DIR/index.html;
    cp *.svg $BRANCH_DIR
    echo "Branch snapshot output to $WEB_ROOT/$BRANCHES_DIR/$BRANCH"
else
    # Living standard, if master
    curl https://api.csswg.org/bikeshed/ -F file=@index.bs \
         -F md-Text-Macro="SNAPSHOT-LINK $SNAPSHOT_LINK" \
         > $WEB_ROOT/index.html
    cp *.svg $WEB_ROOT
    echo "Living standard output to $WEB_ROOT"
fi

# scp the output directory up
sudo apt-get install sshpass

echo ""
find $WEB_ROOT -print
echo ""

sshpass -p $DEPLOY_PASSWORD scp -r -o StrictHostKeyChecking=no $WEB_ROOT $DEPLOY_USER@$SERVER:
