#!/bin/bash

display_menu() {
    zenity --forms --title="Finder" \
        --text="Choose an option:" \
        --add-entry="File name:" \
        --add-entry="Directory name:" \
        --add-entry="Owner:" \
        --add-entry="Group:" \
        --add-entry="Size (MB):" \
        --add-entry="Content:" \
        --extra-button="Reset"\
        --ok-label="Search"\
        --cancel-label="Exit"\
        --width=500 \
        --height=350 \
        --separator='|'
}

reset() {
    FINDER_FILE_NAME=""
    FINDER_FILE_DIRECTORY=""
    FINDER_FILE_OWNER=""
    FINDER_FILE_GROUP=""
    FINDER_FILE_SIZE=""
    FINDER_FILE_CONTENT=""
}

reset

while [ true ]
do
    input=$(display_menu)
    RESULT=$?

    read -ra params <<< "$(echo "$input" | tr '|' ' ')"

    for param in "${params[@]}"; do
        echo "$param"
    done

    if [[ RESULT -eq 1 ]]; then
        if [[ "${params[0]}" == "Reset" ]]; then
            reset
            continue
        else
            break
        fi
    fi

    find ${params[1]} \
        ${params[0]:+-name "${params[0]}"} \
        ${params[3]:+-group "${params[3]}"} \
        ${params[2]:+-user "${params[2]}"} \
        ${params[4]:+-size "+${params[4]}M"} \
        ${params[5]:+-type f -exec grep -q "${params[5]}" {\} \; -print} > /tmp/finder-gui.tmp
    zenity --text-info --title="Search Results" --filename="/tmp/finder-gui.tmp" --width=500 --height=350
    rm /tmp/finder-gui.tmp
done