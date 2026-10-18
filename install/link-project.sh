#!/bin/sh
# Link cursor-template files into a project as absolute symlinks.
# install/link-project.sh <project> [--check|--unlink|--force]
# Refuses to replace a real file or directory unless --force.
# PROJECT.md "Keep local" paths are left untouched (no link, no conflict).
# Writes # >>> cursor-template … # <<< cursor-template into .git/info/exclude.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
template=$(CDPATH= cd -- "$here/.." && pwd)
# shellcheck disable=SC1091
. "$template/hooks/resolve-tools.sh"

usage() {
    echo "usage: install/link-project.sh <project> [--check|--unlink|--force]" >&2
    exit 2
}

mode=install
force=0
project=
for arg in "$@"; do
    case $arg in
        --check) mode=check ;;
        --unlink) mode=unlink ;;
        --force) force=1 ;;
        -h|--help) usage ;;
        *)
            if [ -n "$project" ]; then
                usage
            fi
            project=$arg
            ;;
    esac
done

[ -n "$project" ] || usage
project=$(CDPATH= cd -- "$project" && pwd)
[ -f "$project/PROJECT.md" ] || {
    echo "link-project: missing $project/PROJECT.md" >&2
    exit 1
}
git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "link-project: $project is not a git checkout" >&2
    exit 1
}

repo=$project
_cfg=$project/PROJECT.md
if _got=$(tool_config_path); then
    _cfg=$_got
fi
stack=$(project_token "Stack" "$_cfg")
docs=$(project_token "Docs impact" "$_cfg")
[ -n "$stack" ] || stack=generic
[ -n "$docs" ] || docs=off

wanted=$(mktemp)
all_dests=$(mktemp)
keep_file=$(mktemp)
kept=$(mktemp)
trap 'rm -f "$wanted" "$all_dests" "$keep_file" "$kept"' EXIT

project_field "Keep local" "$_cfg" | sed 's/ — .*//' | tr ',' '\n' | while IFS= read -r item || [ -n "$item" ]; do
    item=$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^`//; s/`$//; s|^\./||; s|/*$||')
    [ -n "$item" ] || continue
    printf '%s\n' "$item"
done > "$keep_file" || true

is_kept() {
    [ -s "$keep_file" ] || return 1
    _ik=$1
    _ik=${_ik#./}
    while [ "${_ik%/}" != "$_ik" ]; do
        _ik=${_ik%/}
    done
    grep -F -x -q -- "$_ik" "$keep_file"
}

filter_matches() {
    _fm=$1
    case $_fm in
        "") return 0 ;;
        "$stack") return 0 ;;
        docs-impact:local) [ "$docs" = "local" ] ;;
        *) return 1 ;;
    esac
}

record() {
    printf '%s %s\n' "$1" "$2" >> "$wanted"
}

while IFS= read -r line || [ -n "$line" ]; do
    case $line in
        ""|"#"*) continue ;;
    esac
    filter=
    rest=$line
    case $line in
        "["*)
            filter=${line%%]*}
            filter=${filter#\[}
            rest=${line#*] }
            ;;
    esac
    set -f
    # shellcheck disable=SC2086
    set -- $rest
    set +f
    src=${1:-}
    dest=${2:-}
    [ -n "$src" ] && [ -n "$dest" ] || {
        echo "link-project: bad links.txt line: $line" >&2
        exit 1
    }
    printf '%s\n' "$dest" >> "$all_dests"
    case $dest in
        .cursor/skills/*)
            printf '%s\n' ".claude/skills/${dest#.cursor/skills/}" >> "$all_dests"
            ;;
    esac
    if filter_matches "$filter"; then
        if is_kept "$dest"; then
            printf '%s\n' "$dest" >> "$kept"
        else
            record "$src" "$dest"
        fi
        case $dest in
            .cursor/skills/*)
                _twin=".claude/skills/${dest#.cursor/skills/}"
                if is_kept "$_twin"; then
                    printf '%s\n' "$_twin" >> "$kept"
                else
                    record "$src" "$_twin"
                fi
                ;;
        esac
    fi
done < "$here/links.txt"

exclude_file=$(abs_git_path "$project" info/exclude)
begin="# >>> cursor-template"
end="# <<< cursor-template"

rewrite_exclude() {
    mkdir -p "$(dirname "$exclude_file")"
    touch "$exclude_file"
    tmp=$(mktemp)
    awk -v b="$begin" -v e="$end" '
        index($0, b) == 1 { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip { print }
    ' "$exclude_file" > "$tmp"
    {
        cat "$tmp"
        printf '%s\n' "$begin"
        while read -r _src dest; do
            printf '/%s\n' "$dest"
        done < "$wanted"
        printf '%s\n' "/.cursor/rules/agent-tools.mdc"
        printf '%s\n' "/CLAUDE.local.md"
        printf '%s\n' "$end"
    } > "$exclude_file"
    rm -f "$tmp"
}

remove_exclude() {
    [ -f "$exclude_file" ] || return 0
    tmp=$(mktemp)
    awk -v b="$begin" -v e="$end" '
        index($0, b) == 1 { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip { print }
    ' "$exclude_file" > "$tmp"
    mv "$tmp" "$exclude_file"
}

abs_source() {
    (
        _as=$template/$1
        if [ -d "$_as" ]; then
            CDPATH= cd -- "$_as" && pwd
        else
            _dir=$(CDPATH= cd -- "$(dirname "$_as")" && pwd)
            printf '%s/%s\n' "$_dir" "$(basename "$_as")"
        fi
    )
}

problems=0
linked=0

prune_stale() {
    while read -r dest || [ -n "$dest" ]; do
        [ -n "$dest" ] || continue
        if is_kept "$dest"; then
            continue
        fi
        if awk -v needle="$dest" '$2 == needle { found = 1 } END { exit !found }' "$wanted"; then
            continue
        fi
        dest_path=$project/$dest
        if [ -L "$dest_path" ]; then
            current=$(readlink "$dest_path")
            case $current in
                "$template"/*)
                    if [ "$mode" = install ]; then
                        rm "$dest_path"
                        echo "link: removed stale $dest"
                    elif [ "$mode" = check ]; then
                        echo "link: stale $dest" >&2
                        problems=$((problems + 1))
                    fi
                    ;;
            esac
        fi
    done < "$all_dests"
}

apply_one() {
    src=$1
    dest=$2
    source_path=$template/$src
    dest_path=$project/$dest
    if [ ! -e "$source_path" ]; then
        echo "link: missing source $src" >&2
        problems=$((problems + 1))
        return
    fi
    target=$(abs_source "$src")
    if [ -L "$dest_path" ]; then
        current=$(readlink "$dest_path")
        if [ "$mode" = unlink ]; then
            case $current in
                "$template"/*)
                    rm "$dest_path"
                    echo "link: removed $dest"
                    ;;
                *)
                    echo "link: kept foreign symlink $dest" >&2
                    ;;
            esac
            return
        fi
        if [ "$current" = "$target" ]; then
            linked=$((linked + 1))
            if [ "$mode" = check ]; then
                echo "link: ok $dest"
            fi
            return
        fi
        if [ "$force" -eq 1 ] && [ "$mode" = install ]; then
            ln -sfn "$target" "$dest_path"
            echo "link: replaced $dest"
            linked=$((linked + 1))
            return
        fi
        echo "link: conflict $dest (symlink points elsewhere)" >&2
        problems=$((problems + 1))
        return
    fi
    if [ -e "$dest_path" ]; then
        if [ "$mode" = unlink ]; then
            echo "link: kept real path $dest"
            return
        fi
        if [ "$force" -eq 1 ] && [ "$mode" = install ]; then
            rm -rf "$dest_path"
            mkdir -p "$(dirname "$dest_path")"
            ln -s "$target" "$dest_path"
            echo "link: replaced real path $dest"
            linked=$((linked + 1))
            return
        fi
        echo "link: conflict $dest (real file; --force to replace)" >&2
        problems=$((problems + 1))
        return
    fi
    if [ "$mode" = unlink ] || [ "$mode" = check ]; then
        if [ "$mode" = check ]; then
            echo "link: missing $dest" >&2
            problems=$((problems + 1))
        fi
        return
    fi
    mkdir -p "$(dirname "$dest_path")"
    ln -s "$target" "$dest_path"
    linked=$((linked + 1))
    echo "link: linked $dest"
}

while IFS= read -r dest || [ -n "$dest" ]; do
    [ -n "$dest" ] || continue
    echo "link: kept-local $dest"
done < "$kept"

if [ "$mode" = unlink ]; then
    while read -r src dest; do
        apply_one "$src" "$dest"
    done < "$wanted"
    remove_exclude
    echo "link-project: unlinked"
    exit 0
fi

prune_stale

if [ "$mode" = install ]; then
    rewrite_exclude
fi

while read -r src dest; do
    apply_one "$src" "$dest"
done < "$wanted"

if [ "$problems" -ne 0 ]; then
    echo "link-project: $problems problem(s)" >&2
    exit 1
fi
echo "link-project: ok ($linked links)"
exit 0
