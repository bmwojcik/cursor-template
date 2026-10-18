#!/bin/sh
# Hide or show the local agent layer via .git/info/exclude.
#   install/agent-layer.sh install <project>
#   install/agent-layer.sh uninstall <project>
#   install/agent-layer.sh list <project>
#   install/agent-layer.sh pack <project> [archive.tar.gz]
#   install/agent-layer.sh check <project>
#
# install syncs the managed block. uninstall removes that block only.
# Tool symlinks stay in the separate cursor-template block.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
template=$(CDPATH= cd -- "$here/.." && pwd)
# shellcheck disable=SC1091
. "$template/hooks/resolve-tools.sh"

usage() {
    sed -n '2,10p' "$0" >&2
    exit 2
}

cmd=${1:-}
project=${2:-}
[ -n "$cmd" ] && [ -n "$project" ] || usage
project=$(CDPATH= cd -- "$project" && pwd)
refuse_tool_checkout "$project"
[ -f "$project/PROJECT.md" ] || {
    echo "agent-layer: missing $project/PROJECT.md" >&2
    exit 1
}
git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "agent-layer: $project is not a git checkout" >&2
    exit 1
}

begin="# >>> agent-layer (managed by cursor-template install/agent-layer.sh)"
end="# <<< agent-layer"
exclude_file=$(abs_git_path "$project" info/exclude)

write_patterns() {
    _wp=$1
    _base=$(mktemp)
    grep -E -v '^[[:space:]]*(#|$)' "$template/install/agent-layer.exclude" > "$_base" || true
    repo=$project
    _cfg=$project/PROJECT.md
    if _got=$(tool_config_path); then
        _cfg=$_got
    fi
    _docs=$(project_token "Docs impact" "$_cfg")
    if [ "$_docs" = "ci" ]; then
        _next=$(mktemp)
        awk '
            $0 == "/docs/" {
                print "/docs/*"
                print "!/docs/ci/"
                print "!/docs/ci/**"
                next
            }
            { print }
        ' "$_base" > "$_next"
        mv "$_next" "$_base"
    fi
    _stack=$(project_token "Stack" "$_cfg")
    _extra=$template/adapters/$_stack/agent-layer.exclude
    if [ -n "$_stack" ] && [ -f "$_extra" ]; then
        grep -E -v '^[[:space:]]*(#|$)' "$_extra" >> "$_base" || true
    fi
    printf '%s\n' "/.agent-tools/" >> "$_base"
    mv "$_base" "$_wp"
}

strip_block() {
    _sb=$1
    mkdir -p "$(dirname "$exclude_file")"
    touch "$exclude_file"
    awk -v b="$begin" -v e="$end" '
        index($0, b) == 1 { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip { print }
    ' "$exclude_file" > "$_sb"
}

install_block() {
    patterns=$(mktemp)
    stripped=$(mktemp)
    write_patterns "$patterns"
    strip_block "$stripped"
    {
        cat "$stripped"
        printf '%s\n' "$begin"
        cat "$patterns"
        printf '%s\n' "$end"
    } > "$exclude_file"
    count=$(grep -c . "$patterns" || true)
    rm -f "$patterns" "$stripped"
    echo "agent-layer: synced $count patterns"
}

uninstall_block() {
    if [ ! -f "$exclude_file" ] || ! grep -q "$begin" "$exclude_file"; then
        return 0
    fi
    stripped=$(mktemp)
    strip_block "$stripped"
    mv "$stripped" "$exclude_file"
    echo "agent-layer: removed managed block"
}

list_files() {
    patterns=$(mktemp)
    write_patterns "$patterns"
    git -C "$project" ls-files --others --ignored --exclude-from="$patterns" \
        | grep -v '^var/' \
        | grep -v '\.request$' \
        | grep -v '__pycache__/' \
        | sort || true
    rm -f "$patterns"
}

case "$cmd" in
    install)
        install_block
        ;;
    uninstall)
        uninstall_block
        ;;
    list)
        list_files
        ;;
    pack)
        archive=${3:-agent-layer.tar.gz}
        case $archive in
            /*) ;;
            *) archive=$project/$archive ;;
        esac
        tmp=$(mktemp)
        list_files > "$tmp"
        if [ ! -s "$tmp" ]; then
            echo "agent-layer: nothing to pack" >&2
            rm -f "$tmp"
            exit 1
        fi
        tar -C "$project" -czf "$archive" -T "$tmp"
        count=$(wc -l < "$tmp" | tr -d ' ')
        rm -f "$tmp"
        echo "agent-layer: $count files → $archive"
        ;;
    check)
        repo=$project
        layer=$(switch_token "Agent layer" || true)
        if [ "$layer" != "local" ]; then
            echo "agent-layer: mode is ${layer:-committed}; local hide is not required"
            exit 0
        fi
        patterns=$(mktemp)
        leaks=$(mktemp)
        err=$(mktemp)
        write_patterns "$patterns"
        # Tracked and staged paths live in the index. ls-files honours
        # --exclude-from; check-ignore does not, and a swallowed git error
        # must not look like a clean tree.
        if ! git -C "$project" ls-files -c -i --exclude-from="$patterns" >"$leaks" 2>"$err"; then
            echo "agent-layer: git ls-files failed" >&2
            cat "$err" >&2
            rm -f "$patterns" "$leaks" "$err"
            exit 1
        fi
        rm -f "$patterns" "$err"
        allow=$(switch_field "Agent layer tracked" || true)
        kept=$(mktemp)
        allowed_out=$(mktemp)
        python3 - "$allow" "$leaks" "$kept" "$allowed_out" <<'PY'
import fnmatch
import sys
from pathlib import Path

allow_raw, leaks_path, keep_path, ok_path = sys.argv[1:5]
patterns = [part.strip().lstrip("./") for part in allow_raw.split(",") if part.strip()]


def matches(path, pattern):
    if any(char in pattern for char in "*?["):
        folded = pattern.replace("**", "*")
        return fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch(path, folded)
    if pattern.endswith("/"):
        return path.startswith(pattern)
    return path == pattern


kept_paths = []
allowed_paths = []
for line in Path(leaks_path).read_text(encoding="utf-8").splitlines():
    path = line.strip()
    if not path:
        continue
    if any(matches(path, pattern) for pattern in patterns):
        allowed_paths.append(path)
    else:
        kept_paths.append(path)
Path(keep_path).write_text("".join(f"{item}\n" for item in kept_paths), encoding="utf-8")
Path(ok_path).write_text("".join(f"{item}\n" for item in allowed_paths), encoding="utf-8")
PY
        if [ -s "$allowed_out" ]; then
            while IFS= read -r allowed_path; do
                [ -n "$allowed_path" ] || continue
                echo "tracked-allowed: $allowed_path"
            done < "$allowed_out"
        fi
        mv "$kept" "$leaks"
        rm -f "$allowed_out"
        if [ -s "$leaks" ]; then
            echo "agent-layer: tracked or staged agent-layer files:" >&2
            cat "$leaks" >&2
            rm -f "$leaks"
            exit 1
        fi
        rm -f "$leaks"
        echo "agent-layer: no tracked agent-layer files"
        ;;
    *)
        usage
        ;;
esac
