#!/usr/bin/env bash

# ----------------------
# Git helper functions
# Merge branches
# Checkout local branches
# Find branches by keyword
# Checkout remote branches
# Delete local branches
# ----------------------
_INPUT=

branchesFile=$TMPDIR'branches'
trap "{ rm -f $branchesFile; }" EXIT

_ACTION_MERGE="merge"
_ACTION_CHECKOUT="checkout"
_ACTION_DELETE="deletion"
_ACTION_REMOTE_CHECKOUT="remote checkout"

# git merge
gml() {
    _showListOrHandleUserIntputForGitBranchAction $_ACTION_MERGE $1
}

# git checkout
gcol() {
    _showListOrHandleUserIntputForGitBranchAction $_ACTION_CHECKOUT $1
}

# git branch -d
gbdl() {
    _showListOrHandleUserIntputForGitBranchAction $_ACTION_DELETE $1
}

# git checkout -t
gcorl() {
    _showListOrHandleUserIntputForGitBranchAction $_ACTION_REMOTE_CHECKOUT $1
}

_showListOrHandleUserIntputForGitBranchAction() {
    _ACTION=$1
    _USER_INPUT=$2

    if [ -z "$_USER_INPUT" ]; then
        _presentBranchList $_ACTION
    elif; then
        _handleActionWithUserInput $_ACTION $_USER_INPUT
    fi
}

_presentBranchList() {
    _ACTION=$1

    local NOCOLOR='\033[0m'
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'

    _addBranchesToFileForAction $_ACTION

    currentBranch=$(git branch | grep \* | cut -d ' ' -f2)
    echo "Current branch:\n${GREEN}$currentBranch${NOCOLOR}"
    _removeCurrentBranchFromList

    echo "Branches available for $_ACTION:"
    _listBranchesFromFile $branchesFile

    _validateInput 'Branch number: '
    branch=$(head -$_INPUT $branchesFile | tail -1 | awk '{$1=$1};1')

    _handleActionWithBranch $_ACTION $branch
}

_addBranchesToFileForAction() {
    _ACTION=$1

    rm -f $branchesFile

    case $_ACTION in
    "remote checkout") git branch -r >$branchesFile ;; # Get remote branches
    *) git branch >$branchesFile ;;                    # Get local branches
    esac
}

_handleActionWithKeyword() {
    _ACTION=$1
    _KEYWORD=$2

    grepBranches=$TMPDIR'grepBranches'
    trap "{ rm -f $grepBranches; }" EXIT

    _addBranchesToFileForAction $_ACTION
    _removeCurrentBranchFromList

    hitCount=$(grep -c $_KEYWORD $branchesFile)
    grep $_KEYWORD $branchesFile >$grepBranches

    case $hitCount in
    # If 0 results, return
    0) return ;;

    # If 1 result, give option to switch
    1)
        line=($(grep -i "$_KEYWORD" $grepBranches))
        printf "Did you mean ${GREEN}$line${NOCOLOR}? [y/n]${NOCOLOR} "
        read confirm
        case $confirm in
        [Yy]*) _handleActionWithBranch $_ACTION $line ;;
        *) return ;;
        esac
        ;;

    # If multiple results, let the user choose
    *)
        echo "Found branches with keyword '$_KEYWORD'"
        _listBranchesFromFile $grepBranches
        _validateInput 'Branch number: '
        branch=$(awk -v "line=$_INPUT" 'NR==line' $grepBranches | awk '{$1=$1};1')
        _handleActionWithBranch $_ACTION $branch
        ;;
    esac
}

_removeCurrentBranchFromList() {
    n=1
    while read line; do
        if [[ $line == *"*"* ]]; then
            # Remove the current branch from the file, we cannot checkout current branch
            sed -i "" $n\d $branchesFile
        fi
        n=$((n + 1))
    done <$branchesFile
}

_listBranchesFromFile() {
    FILE=$1

    n=1
    while read line; do
        if [[ $line != *"*"* ]]; then
            echo "$n. ${RED}$line${NOCOLOR}"
            n=$((n + 1))
        fi
    done <$FILE
}

_validateInput() {
    local NOCOLOR='\033[0m'
    local RED='\033[0;31m'

    while true; do

        # Read user input
        printf $1
        read tmp

        # If input is not an integer or if input is out of range, throw an error
        # Ask for input again
        if [[ ! $tmp =~ ^[0-9]+$ ]]; then
            echo "${RED}Invalid input${NOCOLOR}"
        elif [[ "$tmp" -lt "1" ]] || [[ "$tmp" -gt $((n - 1)) ]]; then
            echo "${RED}Input out of range ${NOCOLOR}"
        else
            _INPUT=$tmp
            break
        fi
    done
}

_handleActionWithUserInput() {
    _ACTION=$1
    _USER_INPUT=$2

    case $_ACTION in
    $_ACTION_MERGE)
        if ! git merge --no-ff $_USER_INPUT; then
            _handleActionWithKeyword $_ACTION $_USER_INPUT
        fi
        ;;
    $_ACTION_REMOTE_CHECKOUT)
        if ! git checkout -t $_USER_INPUT; then
            _handleActionWithKeyword $_ACTION $_USER_INPUT
        fi
        ;;
    $_ACTION_CHECKOUT)
        if ! git checkout $_USER_INPUT; then
            _handleActionWithKeyword $_ACTION $_USER_INPUT
        fi
        ;;
    $_ACTION_DELETE)
        if ! git branch -D $_USER_INPUT; then
            _handleActionWithKeyword $_ACTION $_USER_INPUT
        fi
        ;;
    esac
}

_handleActionWithBranch() {
    _ACTION=$1
    _BRANCH=$2

    case $_ACTION in
    $_ACTION_MERGE) git merge --no-ff $_BRANCH ;;
    $_ACTION_REMOTE_CHECKOUT) git checkout -t $_BRANCH ;;
    $_ACTION_CHECKOUT) git checkout $_BRANCH ;;
    $_ACTION_DELETE)
        printf "${RED}Are you sure you want to delete branch ${NOCOLOR}$_BRANCH${RED}? [y/n]${NOCOLOR} "

        read confirm
        case "$confirm" in
        [yY]) git branch -D $_BRANCH ;;
        *) echo "¯\_(ツ)_/¯" ;;
        esac
        ;;
    esac
}
