#!/bin/sh
# Link cursor-template files into a project as absolute symlinks.
# install/link-project.sh <project> [--check|--unlink|--force] [--host cursor|claude|both]
# Refuses to replace a real file or directory unless --force.
# PROJECT.md "Keep local" paths are left untouched (no link, no conflict).
# Host (cursor | claude | both): flag > <git-dir>/agent-tools.local > tool config > both.
#   A dest under .cursor/ needs a host that includes cursor.
#   A dest under .claude/ and the automatic .claude/skills/<name> twin need a host that includes claude.
#   --unlink always removes the links of every host.
# links.txt filters: stack, docs-impact:local, host:cursor, host:claude; join with commas (all must match).
# Writes # >>> cursor-template … # <<< cursor-template into .git/info/exclude.
# Retired links (see retired_dests) are removed on install and check when they still point into this checkout.
# Host both only: manages a "# >>> cursor-template (claude files)" block in an untracked .cursorindexingignore
#   so Cursor does not index Claude Code files. A git-tracked .cursorindexingignore is never edited.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
template=$(CDPATH= cd -- "$here/.." && pwd)
# shellcheck disable=SC1091
. "$template/hooks/resolve-tools.sh"

usage() {
    echo "usage: install/link-project.sh <project> [--check|--unlink|--force] [--host cursor|claude|both]" >&2
    exit 2
}

mode=install
force=0
project=
host_flag=
while [ $# -gt 0 ]; do
    arg=$1
    shift
    case $arg in
        --check) mode=check ;;
        --unlink) mode=unlink ;;
        --force) force=1 ;;
        --host)
            [ $# -gt 0 ] || usage
            host_flag=$1
            shift
            ;;
        --host=*) host_flag=${arg#--host=} ;;
        -h|--help) usage ;;
        *)
            if [ -n "$project" ]; then
                usage
            fi
            project=$arg
            ;;
    esac
done
if [ -n "$host_flag" ] && ! agent_host_valid "$host_flag"; then
    echo "link-project: --host must be cursor, claude, or both" >&2
    exit 2
fi

[ -n "$project" ] || usage
project=$(CDPATH= cd -- "$project" && pwd)
refuse_tool_checkout "$project"
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
layer=$(project_token "Agent layer" "$_cfg")
[ -n "$stack" ] || stack=generic
[ -n "$docs" ] || docs=off
[ -n "$layer" ] || layer=committed
host=$(resolve_agent_host "$host_flag")
if [ "$mode" = unlink ]; then
    host=both
fi

wanted=$(mktemp)
every=$(mktemp)
all_dests=$(mktemp)
keep_file=$(mktemp)
kept=$(mktemp)
trap 'rm -f "$wanted" "$every" "$all_dests" "$keep_file" "$kept"' EXIT

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

host_has() {
    [ "$host" = both ] || [ "$host" = "$1" ]
}

# Filters join with commas: every part must match. $1 only: the function recurses.
filter_matches() {
    case $1 in
        "") return 0 ;;
        *,*) filter_matches "${1%%,*}" && filter_matches "${1#*,}" ;;
        "$stack") return 0 ;;
        docs-impact:local) [ "$docs" = "local" ] ;;
        host:cursor) host_has cursor ;;
        host:claude) host_has claude ;;
        *) return 1 ;;
    esac
}

# Same as filter_matches but ignores the host parts. Feeds the exclude block.
filter_matches_any_host() {
    case $1 in
        "") return 0 ;;
        *,*) filter_matches_any_host "${1%%,*}" && filter_matches_any_host "${1#*,}" ;;
        "$stack") return 0 ;;
        docs-impact:local) [ "$docs" = "local" ] ;;
        host:cursor|host:claude) return 0 ;;
        *) return 1 ;;
    esac
}

dest_host_ok() {
    case $1 in
        .cursor/*) host_has cursor ;;
        .claude/*) host_has claude ;;
        *) return 0 ;;
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
    vendor=0
    rest=$line
    case $line in
        "["*)
            filter=${line%%]*}
            filter=${filter#\[}
            rest=${line#*] }
            ;;
    esac
    if [ "$filter" = "vendor:committed" ]; then
        vendor=1
        filter=
    fi
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
    if filter_matches_any_host "$filter" && ! { [ "$vendor" -eq 1 ] && [ "$layer" = "committed" ]; } && ! is_kept "$dest"; then
        printf '%s\n' "$dest" >> "$every"
        case $dest in
            .cursor/skills/*)
                printf '%s\n' ".claude/skills/${dest#.cursor/skills/}" >> "$every"
                ;;
        esac
    fi
    if filter_matches "$filter"; then
        if [ "$vendor" -eq 1 ] && [ "$layer" = "committed" ]; then
            continue
        fi
        if dest_host_ok "$dest"; then
            if is_kept "$dest"; then
                printf '%s\n' "$dest" >> "$kept"
            else
                record "$src" "$dest"
            fi
        fi
        case $dest in
            .cursor/skills/*)
                if host_has claude; then
                    _twin=".claude/skills/${dest#.cursor/skills/}"
                    if is_kept "$_twin"; then
                        printf '%s\n' "$_twin" >> "$kept"
                    else
                        record "$src" "$_twin"
                    fi
                fi
                ;;
        esac
    fi
done < "$here/links.txt"

# Links an older checkout made that links.txt no longer lists. Pruned like any stale link.
retired_dests=".claude/rules/documentation.md .claude/rules/phpunit.md"
for _rd in $retired_dests; do
    printf '%s\n' "$_rd" >> "$all_dests"
done

exclude_file=$(abs_git_path "$project" info/exclude)
begin="# >>> cursor-template"
end="# <<< cursor-template"

# .cursorindexingignore: Cursor skips these paths when indexing (they stay readable by the agent).
ii_file=$project/.cursorindexingignore
ii_begin="# >>> cursor-template (claude files)"
ii_end="# <<< cursor-template (claude files)"
ii_owned=0
ii_want=0
if [ "$mode" != unlink ] && [ "$host" = both ]; then
    ii_want=1
fi
ii_tracked=0
if git -C "$project" ls-files --error-unmatch -- .cursorindexingignore >/dev/null 2>&1; then
    ii_tracked=1
fi

ii_rest() {
    # The file without the managed block.
    [ -f "$ii_file" ] || return 0
    awk -v b="$ii_begin" -v e="$ii_end" '
        $0 == b { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip { print }
    ' "$ii_file"
}

ii_has_block() {
    [ -f "$ii_file" ] && grep -F -x -q -- "$ii_begin" "$ii_file"
}

ii_block() {
    printf '%s\n' "$ii_begin" "CLAUDE.md" "CLAUDE.local.md" ".claude/" "var/review-change.*" "$ii_end"
}

# Sets ii_owned=1 when the file holds nothing but the managed block (we created it).
ii_plan() {
    ii_owned=0
    [ "$ii_tracked" -eq 0 ] || return 0
    [ "$ii_want" -eq 1 ] || return 0
    if [ ! -f "$ii_file" ] || [ -z "$(ii_rest | tr -d '[:space:]')" ]; then
        ii_owned=1
    fi
}

ii_tracked_has_entries() {
    grep -F -x -q -- ".claude/" "$ii_file" 2>/dev/null
}

ii_apply() {
    if [ "$ii_tracked" -eq 1 ]; then
        if [ "$ii_want" -eq 1 ] && ! ii_tracked_has_entries; then
            echo "indexing-ignore: .cursorindexingignore is tracked; to keep Cursor from indexing Claude files add: CLAUDE.md CLAUDE.local.md .claude/ var/review-change.*"
        fi
        return 0
    fi
    _ii_tmp=$(mktemp)
    ii_rest | awk '{ a[NR] = $0 } END { n = NR; while (n > 0 && a[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print a[i] }' > "$_ii_tmp"
    if [ "$ii_want" -eq 1 ]; then
        if [ -n "$(tr -d '[:space:]' < "$_ii_tmp")" ]; then
            if [ -n "$(tail -c1 "$_ii_tmp")" ]; then
                printf '\n' >> "$_ii_tmp"
            fi
            printf '\n' >> "$_ii_tmp"
        else
            : > "$_ii_tmp"
        fi
        ii_block >> "$_ii_tmp"
        if [ -f "$ii_file" ] && cmp -s "$_ii_tmp" "$ii_file"; then
            rm -f "$_ii_tmp"
            return 0
        fi
        cat "$_ii_tmp" > "$ii_file"
        echo "indexing-ignore: wrote managed block to .cursorindexingignore"
    elif ii_has_block; then
        if [ -z "$(tr -d '[:space:]' < "$_ii_tmp")" ]; then
            rm -f "$ii_file"
            echo "indexing-ignore: removed .cursorindexingignore (only the managed block)"
        else
            cat "$_ii_tmp" > "$ii_file"
            echo "indexing-ignore: removed managed block from .cursorindexingignore"
        fi
    fi
    rm -f "$_ii_tmp"
}

ii_check() {
    if [ "$ii_tracked" -eq 1 ]; then
        ii_apply
        return 0
    fi
    if [ "$ii_want" -eq 1 ] && ! ii_has_block; then
        echo "indexing-ignore: missing managed block in .cursorindexingignore" >&2
        problems=$((problems + 1))
    elif [ "$ii_want" -eq 0 ] && ii_has_block; then
        echo "indexing-ignore: stale managed block in .cursorindexingignore" >&2
        problems=$((problems + 1))
    fi
}

ii_plan

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
        while read -r dest; do
            printf '/%s\n' "$dest"
        done < "$every"
        printf '%s\n' "/.cursor/rules/agent-tools.mdc"
        printf '%s\n' "/CLAUDE.local.md"
        # Generated by generate-agent-docs.py, not linked.
        if [ "$stack" = magento2 ]; then
            printf '%s\n' "/.claude/rules/phpunit.md"
        fi
        if [ "$ii_owned" -eq 1 ]; then
            printf '%s\n' "/.cursorindexingignore"
        fi
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
    ii_apply
    echo "link-project: unlinked"
    exit 0
fi

prune_stale

if [ "$mode" = install ]; then
    rewrite_exclude
    ii_apply
elif [ "$mode" = check ]; then
    ii_check
fi

while read -r src dest; do
    apply_one "$src" "$dest"
done < "$wanted"

if [ "$mode" = install ]; then
    for _dir in .cursor/skills .cursor/rules .claude/skills .claude/rules .claude/agents; do
        rmdir "$project/$_dir" 2>/dev/null || true
    done
fi

if [ "$problems" -ne 0 ]; then
    echo "link-project: $problems problem(s)" >&2
    exit 1
fi
echo "link-project: ok ($linked links)"
exit 0
