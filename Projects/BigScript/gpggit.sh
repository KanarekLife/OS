#!/usr/bin/env bash

# Author           : Stanisław Nieradko <stanislaw@nieradko.com>
# Created On       : 15.05.2023
# Last Modified By : Stanisław Nieradko <stanislaw@nieradko.com>
# Last Modified On : 28.05.2023
# Version          : 1.0
#
# Description      : Script for easier uploading and downloading git repository with GPG encryption.
#
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)

SCRIPT_NAME=$(basename "$0")
VERSION="1.0"
VERBOSE=true

GPGGIT_DIR=".gpggit"
REMOTE_DIR="$GPGGIT_DIR/remote"
ENCRYPTED_REMOTE_DIR="$GPGGIT_DIR/encrypted-remote"
RECIPIENTS_DIR="$GPGGIT_DIR/recipients"
TAPE_FILE="$GPGGIT_DIR/tape.tar.gz"
PACKAGE_FILE="$ENCRYPTED_REMOTE_DIR/package.gz"
REMOTE_URL_FILE="$ENCRYPTED_REMOTE_DIR/remote-url"

log_info() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1"
    fi
}

log_error() {
    echo "[ERROR] $1"
}

verify_dependencies() {
    local DEPENDENCIES=('git' 'gpg')

    for PROGRAM in ${DEPENDENCIES[@]}; do
        if ! $PROGRAM --version &>/dev/null; then
            log_error "$PROGRAM could not be found"
            exit 1
        fi
    done
}

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  init                            Initialize a new encrypted git repository"
    echo "  import <remote-url>             Import an existing encrypted git repository"
    echo "  add-recipient <key-file>        Add a recipient's public key"
    echo "  remove-recipient <email>        Remove recipient by email"
    echo "  restore-recipients              Restore recipients' keys from .gpggit/recipients directory"
    echo "  push                            Push changes to the encrypted git repository"
    echo "  pull                            Pull changes from the encrypted git repository"
    echo "  add <file>                      Add a file to the repository"
    echo "  commit <args>                   Commit changes to the repository"
    echo "  status                          Show the repository status"
    echo "  push-local                      Push changes to the local git repository"
    echo "  pull-local                      Pull changes from the local git repository"
}

version() {
    log_info "$SCRIPT_NAME version $VERSION"
    log_info "Author: Stanisław Nieradko <stanislaw@nieradko.com>"
    log_info "Description: Script for easier uploading and downloading git repository with GPG encryption."
}

restore_recipients() {
    if [[ -d "$RECIPIENTS_DIR" ]]; then
        for RECIPIENT in "$RECIPIENTS_DIR"/*; do
            gpg --import $RECIPIENT
        done
        log_info "Keys loaded!"
    else
        log_error "Recipients directory was not found!"
        exit 1
    fi
}

exit_abnormal() {
    usage
    exit 1
}

verify_dependencies

case "$1" in
init)
    shift
    REMOTE_URL="$1"

    if [[ -z "$REMOTE_URL" ]]; then
        log_error "Invalid remote URL: $REMOTE_URL"
        exit 1
    fi

    if ! [[ -z "$(ls -A .)" ]]; then
        log_error "Directory is not empty"
        exit 1
    fi

    mkdir -p "$REMOTE_DIR"
    mkdir -p "$ENCRYPTED_REMOTE_DIR"
    mkdir -p "$RECIPIENTS_DIR"

    if [[ -e ".gitignore" ]]; then
        sed -i "/^$GPGGIT_DIR\//d" ".gitignore"
    fi
    printf "$REMOTE_DIR\n$TAPE_FILE\n$ENCRYPTED_REMOTE_DIR\n" >>.gitignore

    git init "$ENCRYPTED_REMOTE_DIR"
    git init --bare "$REMOTE_DIR"
    git init
    git remote add origin "$REMOTE_DIR"

    cd "$ENCRYPTED_REMOTE_DIR"
    git remote add origin $REMOTE_URL

    log_info "Repository has been prepared! Feel free to push and pull to \`origin\`."
    ;;
import)
    shift
    REMOTE_URL="$1"

    if [[ -z "$REMOTE_URL" ]]; then
        log_error "Invalid remote URL: $REMOTE_URL"
        exit 1
    fi

    if ! [[ -z "$(ls -A .)" ]]; then
        log_error "Directory is not empty"
        exit 1
    fi

    mkdir -p "$REMOTE_DIR"
    mkdir -p "$ENCRYPTED_REMOTE_DIR"
    mkdir -p "$RECIPIENTS_DIR"

    cd "$ENCRYPTED_REMOTE_DIR"
    git clone $REMOTE_URL .
    cp -r recipients/ ../
    cd ../../
    restore_recipients

    gpg --output "$TAPE_FILE" --decrypt "$PACKAGE_FILE"
    if [ $? -ne 0 ]; then
        log_error "GPG could not decrypt the file. Aborting."
        exit 1
    fi
    tar -xzvcf "$TAPE_FILE" -C .

    git init
    git remote add origin "$REMOTE_DIR/"
    git fetch
    git checkout -b master origin/master --force
    ;;
add-recipient)
    shift
    if [[ -e "$@" ]]; then
        KEY_ID=$(gpg --with-colons --keyid-format 0xlong --import-options show-only --import "$@" | awk -F: '/^pub:/ { print $5 }')
        if [[ -n "$KEY_ID" ]]; then
            SEARCH_OUTPUT=$(gpg --list-keys --keyid-format 0xlong $key_id 2>/dev/null)
            if [[ "$SEARCH_OUTPUT" != *"$KEY_ID"* ]]; then
                GPG_OUTPUT=$(gpg --import "$@" 2>&1)
                if [[ $GPG_OUTPUT != *"imported"* ]]; then
                    log_error "GPG had issue with importing recipient public key or it already exists!"
                fi
            fi
            EMAIL=$(gpg --with-colons --keyid-format 0xlong --import-options show-only --import $@ | awk -F: '/^uid:/' | awk -F'[<>]' '{print $2}')
            if ! [[ -f "$RECIPIENTS_DIR/$EMAIL" ]]; then
                cp "$@" "$RECIPIENTS_DIR/$EMAIL"
                log_info "Public key from $@ has been added!"
            fi
        else
            log_error "Key ID could not been extracted from $@!"
        fi
    else
        log_error "Public key in $@ was not found!"
    fi
    ;;
remove-recipient)
    shift
    if [[ -f "$RECIPIENTS_DIR/$1" ]]; then
        rm "$RECIPIENTS_DIR/$1"
        log_info "Recipient $1 removed"
    fi
    ;;
restore-recipients)
    restore_recipients
    ;;
push)
    tar -czf "$TAPE_FILE" "$REMOTE_DIR/"
    RECIPIENTS=()

    for FILE in "$RECIPIENTS_DIR"/*; do
        if [[ -f "$FILE" ]]; then
            RECIPIENTS+="--recipient $(basename "$FILE")"
        fi
    done

    if [[ ${#RECIPIENTS[@]} -eq 0 ]]; then
        log_error "No recipients specified. Use \`gpggit add-recipient <user's public key location>\` to add one."
        exit_abnormal
    fi

    gpg --encrypt ${RECIPIENTS[@]} --output "$PACKAGE_FILE" "$TAPE_FILE"
    cp -r "$RECIPIENTS_DIR" "$ENCRYPTED_REMOTE_DIR/"
    cd "$ENCRYPTED_REMOTE_DIR"
    git add .
    git commit -m "update"
    git push -u origin master --force-with-lease
    log_info "Repository pushed successfuly"
    ;;
add)
    shift
    git add "$@"
    ;;
commit)
    shift
    git commit "$@"
    ;;
status)
    git status
    ;;
push-local)
    git push -u origin master
    ;;
pull-local)
    git pull --force
    ;;
pull)
    cd "$ENCRYPTED_REMOTE_DIR"
    git pull --force
    cd ../../
    if ! [[ -e "$PACKAGE_FILE" ]]; then
        echo "ERROR: package.gz not found. Make sure your repository is configured correctly!"
    fi
    gpg --output "$TAPE_FILE" --decrypt "$PACKAGE_FILE"
    mkdir -p "$ENCRYPTED_REMOTE_DIR"
    tar -xzvf "$TAPE_FILE" -C .
    log_info "Repository fetched successuly"
    ;;
*)
    while getopts "hv" OPTIONS; do
        case "${OPTIONS}" in
        h)
            usage
            exit
            ;;
        v)
            version
            exit
            ;;
        :)
            log_error "-${OPTARG} requires an argument"
            exit_abnormal
            ;;
        *)
            exit_abnormal
            ;;
        esac
    done
    ;;
esac
