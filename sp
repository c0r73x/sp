#!/bin/bash

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

SKEL_DIR="$HOME/.skeletons"

if [[ ! -d $SKEL_DIR ]]; then
    printf "${COL_RED}Skeleton directory missing!${COL_RESET}\n" >&2
    echo "" >&2
    echo "Please create $HOME/.skeletons and place your skeleton projects in" >&2
    echo "that folder" >&2
    exit 1
fi

list_projects() {
    local projects=($(find "$SKEL_DIR" -mindepth 1 -maxdepth 1 -type d))
    local desc
    local name

    if [[ ${#projects[@]} -eq 0 ]]; then
        printf "${COL_YELLOW}No skeleton projects found!\n${COL_RESET}"
        return
    fi

    echo "Skeleton projects:"

    for proj in "${projects[@]}"; do
        if [[ -d "$proj" ]]; then
            desc=""
            name="$(basename "$proj")"

            if [[ -f "$proj/.description" ]]; then
                desc="$(cat "$proj/.description")"
            fi

            printf "  ${COL_GREEN}%-10s${COL_RESET}%s\n" \
                "$name" "${desc/$'\n'}"
        fi
    done
}

create_project() {
    if [[ ! -d "$SKEL_DIR/$PROJECT" ]]; then
        printf "${COL_RED}Unknown skeleton \"%s\"${COL_RESET}\n" "$PROJECT"
        list_projects
        exit 1
    fi

    if [[ -d "$OUTPUT_DIR" ]]; then
        read -r -p "The directory \"$OUTPUT_DIR\" exists, continue anyway? [y/N] " response
        response=${response,,}
        if [[ "$response" =~ ^(no|n)$ ]]; then
            exit 0
        fi
    fi

    local vars=($(compgen -A variable | grep "PROJECT_"))

    echo "Variables: "

    for v in "${vars[@]}"; do
        printf "  ${COL_BLUE}%s${COL_RESET} = %s\n" "$v" "$(eval echo "\$$v")"
    done

    PFILES=($(find "$SKEL_DIR/$PROJECT/" -mindepth 1))
    missing=()

    for pf in "${PFILES[@]}"; do
        if [[ "$pf" =~ %(PROJECT_[A-Z]{1,})% ]]; then
            v=${BASH_REMATCH[1]}
            if [[ -z "$(eval echo "\$$v")" ]]; then
                missing+=($v)
            fi
        fi
    done

    PCONT=($(grep -orh '%PROJECT_[A-Z]\+%' "$SKEL_DIR/$PROJECT"))
    for pc in "${PCONT[@]}"; do
        v="${pc//%/}"
        if [[ -z "$(eval echo "\$$v")" ]]; then
            missing+=($v)
        fi
    done

    missing=($(echo "${missing[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    if [[ ${#missing[@]} -gt 0 ]]; then
        for m in "${missing[@]}"; do
            printf "  ${COL_RED}%s is missing!$COL_RESET \n" "$m"
        done
        echo ""
        echo "Please specify missing variables and try again" >&2
        exit 1
    fi

    echo ""

    read -r -p "Create a new \"$PROJECT\" project into \"$OUTPUT_DIR\"? [y/N] " response
    response=${response,,}
    if [[ "$response" =~ ^(yes|y)$ ]]; then
        mkdir -p "$OUTPUT_DIR"
        PFILES=($(find "$SKEL_DIR/$PROJECT/" -mindepth 1))

        for pf in "${PFILES[@]}"; do
            if [[ "$pf" =~ .description$ ]]; then
                continue
            fi

            npf=${pf//$SKEL_DIR\/$PROJECT/$OUTPUT_DIR}
            if [[ "$pf" =~ %(PROJECT_[A-Z]{1,})% ]]; then
                for v in "${vars[@]}"; do
                    val="$(eval echo "\$$v")"
                    npf="${npf//%${v}%/$val}"
                done
            fi

            if [[ -d "$pf" ]]; then
                mkdir -p "$npf"
            else
                npd="$(dirname "$npf")"
                if [[ ! -d "$npd" ]]; then
                    mkdir -p "$npd"
                fi

                cp "$pf" "$npf"
                for v in "${vars[@]}"; do
                    val="$(eval echo "\$$v")"
                    sed -i "s#%${v}%#${val}#" "$npf"
                done
            fi
        done

        echo ""
        printf "${COL_GREEN}done!${COL_RESET}\n"
    else
        exit 0
    fi
}

parse_variables() {
    IFS=',' read -ra vars <<< "$1"
    for v in "${vars[@]}"; do
        arrV=(${v//=/ })
        eval "PROJECT_${arrV[0]}=\"${arrV[1]}\""
    done
}

help_message() {
    echo "Usage: $0 [OPTIONS] [SKELETON] [DIRECTORY]"
    echo ""
    echo "Options:"

    printf "  %-10s%s\n" "-h" "display this help and exit"
    printf "  %-10s%s\n" "-v" "string list of variables"
    printf "  %-10s%s\n" ""   "Example: -v NAME='project',VERSION='1.0'"
    printf "  %-10s%s\n" "-i" "input file with variables"
    printf "  %-10s%s\n" ""   "Example file:"
    printf "  %-10s%s\n" ""   "  PROJECT_NAME='project'"
    printf "  %-10s%s\n" ""   "  PROJECT_VERSION='1.0'"

    echo ""
}

if [[ $# -eq 0 ]]; then
    help_message >&2
    exit 1
fi

PROJECT_NAME=""

while getopts "i:v:hl" c; do
    case "$c" in
        i)
            if [[ -f "$OPTARG" ]]; then
                source "$OPTARG"
            else
                printf "${COL_RED}No such file \"%s\"$COL_RESET\n" "$OPTARG" >&2
                exit 1
            fi
            ;;
        v)
            parse_variables "$OPTARG"
            ;;
        l)
            list_projects
            exit 0
            ;;
        h)
            help_message >&2
            exit 1
            ;;
        *)
            help_message >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
    printf "${COL_RED}Please specify a project skeleton!${COL_RESET}\n" >&2
    exit 1
fi

if [[ $# -lt 2 ]]; then
    printf "${COL_RED}Please specify a project directory!${COL_RESET}\n" >&2
    exit 1
fi

PROJECT=$1
OUTPUT_DIR=$2

if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(basename "$2")"
fi

create_project
