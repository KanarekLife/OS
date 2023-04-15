display_menu() {
    printf "1. Nazwa pliku: $FINDER_FILE_NAME\n"
    printf "2. Katalog: $FINDER_FILE_DIRECTORY\n"
    printf "3. Właściciel: $FINDER_FILE_OWNER\n"
    printf "4. Grupa: $FINDER_FILE_GROUP\n"
    printf "5. Rozmiar (większy niż): $FINDER_FILE_SIZE MB\n"
    printf "6. Zawartość: $FINDER_FILE_CONTENT\n"
    printf "7. Szukaj:\n"
    printf "8. Koniec\n"
}

reset() {
    FINDER_EXIT=1
}

reset

while [ $FINDER_EXIT -eq 1 ]
do
    display_menu
    read FINDER_INPUT
    if [[ $FINDER_INPUT =~ ^[0-9]+$ ]]; then
        if ((FINDER_INPUT >= 1 && FINDER_INPUT <= 8)); then
            case $FINDER_INPUT in
                1)
                    read -p "Podaj nazwę pliku: " FINDER_FILE_NAME
                ;;
                2)
                    read -p "Podaj nazwę katalogu: " FINDER_FILE_DIRECTORY
                ;;
                3)
                    read -p "Podaj właściciela: " FINDER_FILE_OWNER
                ;;
                4)
                    read -p "Podaj grupę: " FINDER_FILE_GROUP
                ;;
                5)
                    read -p "Podaj rozmiar (większy niż w MB): " FINDER_FILE_SIZE
                ;;
                6)
                    read -p "Podaj zawartość: " FINDER_FILE_CONTENT
                ;;
                7)
                    find $FINDER_FILE_DIRECTORY \
                    ${FINDER_FILE_NAME:+-name "$FINDER_FILE_NAME"} \
                    ${FINDER_FILE_GROUP:+-group "$FINDER_FILE_GROUP"} \
                    ${FINDER_FILE_OWNER:+-user "$FINDER_FILE_OWNER"} \
                    ${FINDER_FILE_SIZE:+-size "+${FINDER_FILE_SIZE}M"} \
                    ${FINDER_FILE_CONTENT:+-type f -exec grep -q "$FINDER_FILE_CONTENT" {\} \; -print}
                ;;
                8)
                    FINDER_EXIT=0
                ;;
            esac
        fi
    else
        printf "INVALID COMMAND: Select the option by selecting ONLY the number and clicking ENTER\n\n"
    fi
done