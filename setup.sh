#!/bin/bash

# All capitalized variables are global variables defined at the beginning of this file.
# All lowercase variables are local variables defined at the beginning of each function.

# Constants

#VER_TRIVY="v0.46.1"
#VER_VULN_LIST_UPDATE="eb47fe8e028cece8b97ec6aef471f2c3ada95ca0"

VER_TRIVY="v0.56.2"
VER_VULN_LIST_UPDATE="8b61bbff7ce6311eff2897745e37ed37a21b7d56"

# Notes:
#   VER_TRIVY           : the desired Trivy release (ends in '.1','.2',...)
#   VER_VULN_LIST_UPDATE: tag after which patches are added on top
#   TRIVY_DB            : SHA derived from Trivy by 'get_trivy_db_commit'
#                         $ grep trivy-db trivy/go.mod
#                         github.com/aquasecurity/trivy-db v0.0.0-20240910133327-7e0f4d2ed4c1
#                                                                                ^^^^^^^^^^^^


REPO_PATH_TRIVY="trivy"
REPO_PATH_TRIVY_DB="trivy-db"
REPO_PATH_VULN_LIST_UPDATE="vuln-list-update"

REPO_URL_TRIVY="https://github.com/aquasecurity/trivy.git"
REPO_URL_TRIVY_DB="https://github.com/aquasecurity/trivy-db.git"
REPO_URL_VULN_LIST_UPDATE="https://github.com/aquasecurity/vuln-list-update.git"

PATCH_DIR="patch"

INSTALLATION_BRANCH_NAME="installation-$VER_TRIVY"

# TODO: add a check if all files are present

function usage {
    echo usage
}

function get_trivy_db_commit {  
    # Syonpsis: Get commit hash for trivy-db.
    # Arguments: None

    local commit_ver
    local commit_ver_lines
    local line_cnt
    
    # Get the lines potentially containing trivy-db commit version info.
    commit_ver_lines=$(grep "trivy-db" "$REPO_PATH_TRIVY/go.mod")

    # Indicate error if grep fails.
    if [ "$?" -ne "0" ]; then
        echo "get_trivy_db_commit(): ERROR! Running grep to get trivy-db commit version failed."
        return 1
    fi

    # Indicate error when there are multiple such lines.
    line_cnt=$(wc -l <<< "$commit_ver_lines" | awk "{ print $1 }")
    if [ "$line_cnt" -ne "1" ]; then
        echo "get_trivy_db_commit(): ERROR! Incorrect number of lines associated with trivy-db found in go.mod."
        echo "$commit_ver_lines"
        return 1
    fi

    # Get the commit hash of the trivy-db that should be used for this trivy version.
    commit_ver="${commit_ver_lines/*-/}"

    # Check the validity of this commit hash in trivy-db repo.
    if ! git -C "$REPO_PATH_TRIVY_DB" show "$commit_ver" >/dev/null 2>&1; then
        echo "get_trivy_db_commit(): ERROR! Invalid commit hash \"$commit_ver\" in trivy-db"
        return 1
    fi

    echo "$commit_ver"
    return 0
}

function load_repo {
    # Synopsis: Clone the repos if necessary.
    # Arguments:
    #   $1 - Location of the repo
    #   $2 - Repo uniform resource locator (URL)

    if [ ! -d "$1" ] ; then
        echo "Cloning $1"
        git clone "$2" "$1" || return 1
    fi
}

function reset_repo {  
    # Synopsis: Set the repo to a certain commit.
    # Arguments:
    #   $1 - Location of the repo
    #   $2 - Commit reference that should be used for installation

    pushd "$1" || return 1
    git checkout --force --detach "$2" || return 1
    git clean -d -f -f -x
    popd || return 1
}

function apply_patch {
    # Synopsis: Install Wind River specific patch into a repo.
    # Arguments:
    #   $1 - Location of the repo
    #   $2 - Location of the patches

    local patch_dir_abspath
    local repo_name

    patch_dir_abspath="$(pwd)/$2"
    repo_name=$(basename "$1")

    pushd "$1" || return 1
    git checkout -b "$INSTALLATION_BRANCH_NAME"
    git am "$patch_dir_abspath/$repo_name/"*
    git checkout --detach
    git branch -D "$INSTALLATION_BRANCH_NAME"
    popd || return 1
}

function install {
    # Synopsis: 
    #   Perform the first-time installation of the repos. This function is 
    #   idempotent given the assumption that the directories, if exist, of 
    #   where repos are to be cloned contain correct clones of repos instead of 
    #   other random repos. For example, if "trivy" directory exists, then this 
    #   directory is a clone of the "trivy" from upstream instead of some other 
    #   random repo such as "perl5". 
    # Arguments: None
    #   $1 - phase flag ("1:)

    local ver_trivy_db
    phase=$1

    # Clone the repos if necessary.

    echo "[1/5] Cloning repos."

    load_repo "$REPO_PATH_TRIVY" "$REPO_URL_TRIVY" || return 1
    load_repo "$REPO_PATH_TRIVY_DB" "$REPO_URL_TRIVY_DB" || return 1
    load_repo "$REPO_PATH_VULN_LIST_UPDATE" "$REPO_URL_VULN_LIST_UPDATE" || return 1
    if [ $phase -eq 1 ] ; then
        return
    fi

    # Reset each repo to the correct version/commit.

    echo "[2/5] Selecting the correct commit for each repo."

    reset_repo "$REPO_PATH_TRIVY" "$VER_TRIVY" || return 1
    ver_trivy_db=$(get_trivy_db_commit)
    if [ "$?" -ne 0 ]; then return 1; fi
    reset_repo "$REPO_PATH_TRIVY_DB" "$ver_trivy_db" || return 1
    reset_repo "$REPO_PATH_VULN_LIST_UPDATE" "$VER_VULN_LIST_UPDATE" || return 1
    if [ $phase -eq 2 ] ; then
        return
    fi

    # Apply the patches to each repo.

    echo "[3/5] Applying the patches to each repo."

    apply_patch "$REPO_PATH_TRIVY_DB" "$PATCH_DIR" || return 1
    pushd "$REPO_PATH_TRIVY" || return 1
    go mod vendor
    rm -rf vendor/github.com/aquasecurity/trivy-db/
    # Set up the correct reference to trivy-db in trivy vendor.
    ln -s "$(pwd)/../$REPO_PATH_TRIVY_DB" vendor/github.com/aquasecurity/trivy-db
    popd || return 1
    apply_patch "$REPO_PATH_TRIVY" "$PATCH_DIR" || return 1
    apply_patch "$REPO_PATH_VULN_LIST_UPDATE" "$PATCH_DIR" || return 1
    if [ $phase -eq 3 ] ; then
        return
    fi

    # Build the binaries.

    echo "[4/5] Building the binaries."

    # Build CVE builder vuln-list-update.
    pushd "$REPO_PATH_VULN_LIST_UPDATE" || return 1
    go build -o vuln-list-update .
    popd || return 1

    # Build trivy binary.
    pushd "$REPO_PATH_TRIVY" || return 1
    go build -ldflags "-s -w -X=main.version=`git describe --tags --always`" ./cmd/trivy
    popd || return 1
    if [ $phase -eq 4 ] ; then
        return
    fi

    # Build database (the same process as updating the database).
    echo "[5/5] Building the CVE database."

    update_db
}

function update_db {
    # Synopsis: Update the database.
    # Arguments: None

    # Update JSON files containing CVE info.
    pushd "$REPO_PATH_VULN_LIST_UPDATE"
    ./vuln-list-update -target wrlinux
    popd

    # Build the JSON files into a trivy database file.
    pushd "$REPO_PATH_TRIVY_DB"
    make db-clean
    make build db-fetch-langs db-fetch-vuln-list
    cp -r $HOME/.cache/vuln-list-update/vuln-list/wrlinux/ cache/vuln-list/wrlinux/
    make db-build
    make db-compact
    make db-compress
    popd

    # Load the newly built trivy database file containing CVE info.
    mkdir -p ~/.cache/trivy/db
    cp "$REPO_PATH_TRIVY_DB/assets/metadata.json" "$REPO_PATH_TRIVY_DB/assets/trivy.db" ~/.cache/trivy/db
}

case "$1" in
    "install") install 5;;
    "clone") install 1;;
    "commits") install 2;;
    "patch") install 3;;
    "binary") install 4;;
    "update_db") update_db;;
    "help") usage; exit 1;;
esac
