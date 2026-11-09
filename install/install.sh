#!/bin/sh
# Install the cursor-template agent layer into a project.
# install/install.sh <project> [--check|--adopt|--migrate-config|--with-reviewer|--without-reviewer|--sync-vendored] [--host cursor|claude|both]
# Idempotent. --check prints one line per feature and exits 1 on problems.
# A missing merge-reviewer checkout does not fail a normal install.
# PROJECT.md "Keep local" paths are skipped by link-project (no symlink, no conflict).
# Agent host (cursor | claude | both): which tool's links and laptop files this checkout installs.
#   --host writes "- **Agent host:** <value>" into .agent-tools/config.md (and into
#   <git-dir>/agent-tools.local when that file already has the key).
#   Effective host: --host > <git-dir>/agent-tools.local > .agent-tools/config.md > both.
#   Team files (AGENTS.md, CLAUDE.md) are written for every host.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
template=$(CDPATH= cd -- "$here/.." && pwd)
# shellcheck disable=SC1091
. "$template/hooks/resolve-tools.sh"

usage() {
    echo "usage: install/install.sh <project> [--check|--adopt|--migrate-config|--with-reviewer|--without-reviewer|--sync-vendored] [--host cursor|claude|both]" >&2
    exit 2
}

mode=install
adopt=0
migrate=0
with_reviewer=0
without_reviewer=0
sync_vendored=0
project=
host_flag=
while [ $# -gt 0 ]; do
    arg=$1
    shift
    case $arg in
        --check) mode=check ;;
        --adopt) adopt=1 ;;
        --migrate-config) migrate=1 ;;
        --with-reviewer) with_reviewer=1 ;;
        --without-reviewer) without_reviewer=1 ;;
        --sync-vendored) sync_vendored=1 ;;
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

[ -n "$project" ] || usage
if [ -n "$host_flag" ]; then
    host_flag=$(printf '%s' "$host_flag" | tr '[:upper:]' '[:lower:]')
    if ! agent_host_valid "$host_flag"; then
        echo "install: --host must be cursor, claude, or both" >&2
        exit 2
    fi
fi
if [ "$mode" = check ] && [ "$adopt" -eq 1 ]; then
    echo "install: pass --check or --adopt, not both" >&2
    exit 2
fi
if [ "$mode" = check ] && [ "$sync_vendored" -eq 1 ]; then
    echo "install: pass --check or --sync-vendored, not both" >&2
    exit 2
fi
if [ "$with_reviewer" -eq 1 ] && [ "$without_reviewer" -eq 1 ]; then
    echo "install: pass --with-reviewer or --without-reviewer, not both" >&2
    exit 2
fi
project=$(CDPATH= cd -- "$project" && pwd)
refuse_tool_checkout "$project"
repo=$project
if [ "$migrate" -eq 1 ]; then
    python3 "$template/install/generate-agent-docs.py" "$project" --migrate-config
fi
[ -f "$project/PROJECT.md" ] || {
    echo "install: missing $project/PROJECT.md" >&2
    exit 1
}
git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "install: $project is not a git checkout" >&2
    exit 1
}

set_host_key() {
    # set_host_key <file> <value>: replace the Agent host line, or add it after Stack.
    _sh_file=$1
    _sh_value=$2
    _sh_tmp=$(mktemp)
    if grep -q '^- \*\*Agent host:\*\*' "$_sh_file"; then
        awk -v v="$_sh_value" '
            /^- \*\*Agent host:\*\*/ { if (!done) { print "- **Agent host:** " v; done = 1 } ; next }
            { print }
        ' "$_sh_file" > "$_sh_tmp"
    elif grep -q '^- \*\*Stack:\*\*' "$_sh_file"; then
        awk -v v="$_sh_value" '
            { print }
            /^- \*\*Stack:\*\*/ && !done { print "- **Agent host:** " v; done = 1 }
        ' "$_sh_file" > "$_sh_tmp"
    else
        cat "$_sh_file" > "$_sh_tmp"
        printf '%s\n' "- **Agent host:** $_sh_value" >> "$_sh_tmp"
    fi
    cat "$_sh_tmp" > "$_sh_file"
    rm -f "$_sh_tmp"
}

write_host_flag() {
    _wh_config=$project/.agent-tools/config.md
    _wh_local=$(abs_git_path "$project" agent-tools.local)
    case $_wh_local in
        /*) ;;
        *) _wh_local=$project/$_wh_local ;;
    esac
    if [ -f "$_wh_config" ]; then
        set_host_key "$_wh_config" "$host_flag"
        echo "agent host: wrote $host_flag to .agent-tools/config.md"
    else
        # No tool config file: PROJECT.md may still hold the switches, so do not create one here.
        mkdir -p "$(dirname "$_wh_local")"
        touch "$_wh_local"
        set_host_key "$_wh_local" "$host_flag"
        echo "agent host: no .agent-tools/config.md; wrote $host_flag to agent-tools.local"
        return 0
    fi
    if [ -f "$_wh_local" ] && grep -q '^- \*\*Agent host:\*\*' "$_wh_local"; then
        set_host_key "$_wh_local" "$host_flag"
        echo "agent host: updated agent-tools.local"
    fi
}

prune_empty_host_dirs() {
    case $host in
        claude) _pe_dir=$project/.cursor ;;
        cursor) _pe_dir=$project/.claude ;;
        *) return 0 ;;
    esac
    [ -d "$_pe_dir" ] && [ ! -L "$_pe_dir" ] || return 0
    find "$_pe_dir" -depth -type d -empty -delete 2>/dev/null || true
}

if [ "$mode" = install ] && [ -n "$host_flag" ]; then
    write_host_flag
fi
host=$(resolve_agent_host "$host_flag")

problems=0
note() {
    printf '%s\n' "$1"
}
fail() {
    printf '%s\n' "$1" >&2
    problems=$((problems + 1))
}

stack=$(switch_token "Stack" || true)
layer=$(switch_token "Agent layer" || true)
docs=$(switch_token "Docs impact" || true)
need=$(switch_token "Cursor template version" || true)
[ -n "$stack" ] || stack=generic
[ -n "$layer" ] || layer=committed
[ -n "$docs" ] || docs=off

have=$(tr -d '[:space:]' < "$template/VERSION")
note "stack: $stack"
note "agent-layer: $layer"
note "agent host: $host"
if [ -n "$need" ] && version_lt "$have" "$need"; then
    if [ "$mode" = check ]; then
        fail "cursor-template: $have older than $need"
    else
        note "cursor-template: $have older than $need"
        repo=$project
        CURSOR_TEMPLATE_HOME=$template
        export CURSOR_TEMPLATE_HOME
        warn_template_version || true
    fi
else
    note "cursor-template: $have ok${need:+ (min $need)}"
fi

update_cursor_env() {
    home_dir=${XDG_CONFIG_HOME:-$HOME/.config}/review-change
    file=$home_dir/cursor.env
    mkdir -p "$home_dir"
    umask 077
    tmp=$(mktemp)
    if [ -f "$file" ]; then
        grep -E -v '^(export[[:space:]]+)?(CURSOR_TEMPLATE_HOME|REVIEW_CHANGE_HOME)=' "$file" > "$tmp" || true
    fi
    printf 'CURSOR_TEMPLATE_HOME=%s\n' "$template" >> "$tmp"
    mv "$tmp" "$file"
    chmod 600 "$file"
    echo "cursor.env: updated CURSOR_TEMPLATE_HOME"
}

backup_dir=
backup_file() {
    rel=$1
    [ -e "$project/$rel" ] || return 0
    if [ -z "$backup_dir" ]; then
        stamp=$(date +%Y%m%d%H%M%S)
        git_path=$(abs_git_path "$project" "cursor-template-backup/$stamp")
        case $git_path in
            /*) backup_dir=$git_path ;;
            *) backup_dir=$project/$git_path ;;
        esac
        mkdir -p "$backup_dir"
    fi
    mkdir -p "$backup_dir/$(dirname "$rel")"
    cp -a "$project/$rel" "$backup_dir/$rel"
    echo "install: backed up $rel → $backup_dir/$rel"
}

copy_hooks() {
    mkdir -p "$project/.githooks"
    foreign_hooks=0
    for name in pre-commit post-commit is-local-dev.sh resolve-tools.sh; do
        src=$template/hooks/$name
        dest=$project/.githooks/$name
        if [ -L "$dest" ]; then
            if [ "$mode" = check ]; then
                continue
            fi
            rm "$dest"
        elif [ -f "$dest" ] && ! grep -q "cursor-template hook" "$dest"; then
            if [ "$adopt" -eq 1 ]; then
                backup_file ".githooks/$name"
            else
                foreign_hooks=1
                fail "install: .githooks/$name is not a cursor-template hook. Move any project-specific behaviour into PROJECT.md, then rerun: $template/install/install.sh $project --adopt"
                continue
            fi
        fi
        if [ "$mode" = check ]; then
            continue
        fi
        cp "$src" "$dest"
        chmod 755 "$dest"
    done
    if [ "$foreign_hooks" -ne 0 ]; then
        return
    fi
    if [ "$mode" = check ]; then
        return
    fi
}

hook_paths() {
    git -C "$project" ls-files -- .githooks 2>/dev/null || true
    for _name in pre-commit post-commit is-local-dev.sh resolve-tools.sh; do
        if [ -f "$project/.githooks/$_name" ]; then
            printf '%s\n' ".githooks/$_name"
        fi
    done
}

ensure_hook_index_modes() {
    [ "$layer" = "committed" ] || return 0
    [ "$mode" = install ] || return 0
    _list=$(mktemp)
    hook_paths | awk 'NF && !seen[$0]++' > "$_list"
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        [ -f "$project/$rel" ] || continue
        chmod 755 "$project/$rel"
        indexed=$(git -C "$project" ls-files -s -- "$rel" | awk 'NR==1 { print $1 }')
        if [ -z "$indexed" ]; then
            git -C "$project" add --chmod=+x -- "$rel"
            echo "hooks: index mode fixed (+x) $rel"
            continue
        fi
        if [ "$indexed" = "100755" ]; then
            continue
        fi
        differs=0
        if ! git -C "$project" diff --quiet -- "$rel"; then
            differs=1
        fi
        git -C "$project" update-index --chmod=+x -- "$rel"
        if [ "$differs" -eq 1 ]; then
            echo "hooks: index mode fixed (+x) $rel (content also differs)"
        else
            echo "hooks: index mode fixed (+x) $rel"
        fi
    done < "$_list"
    rm -f "$_list"
}

check_hook_index_modes() {
    [ "$layer" = "committed" ] || return 0
    [ "$mode" = check ] || return 0
    _list=$(mktemp)
    git -C "$project" ls-files -s -- .githooks > "$_list" 2>/dev/null || true
    while read -r gitmode _hash _stage path; do
        [ -n "$path" ] || continue
        if [ "$gitmode" != "100755" ]; then
            fail "hooks: not executable in git $path"
        fi
        if [ -e "$project/$path" ] && [ ! -x "$project/$path" ]; then
            echo "hooks: not executable on disk $path"
        fi
    done < "$_list"
    rm -f "$_list"
}

if [ "$mode" = install ]; then
    update_cursor_env
fi

repo=$project
resolve_tools_load_env
CURSOR_TEMPLATE_HOME=$template
export CURSOR_TEMPLATE_HOME

link_args="$project --host $host"
if [ "$mode" = check ]; then
    link_args="$project --check --host $host"
fi
# shellcheck disable=SC2086
if sh "$template/install/link-project.sh" $link_args; then
    note "links: ok"
else
    fail "links: problem"
fi

vendor_args=$project
if [ "$mode" = check ]; then
    vendor_args="$vendor_args --check"
fi
if [ "$sync_vendored" -eq 1 ]; then
    vendor_args="$vendor_args --sync"
fi
vendor_status=0
# shellcheck disable=SC2086
python3 "$template/install/vendor_files.py" $vendor_args || vendor_status=$?
if [ "$vendor_status" -ne 0 ]; then
    fail "vendored: problem"
fi

foreign_hooks=0
copy_hooks
hook_missing=0
if [ "$foreign_hooks" -eq 0 ]; then
    for name in pre-commit post-commit is-local-dev.sh resolve-tools.sh; do
        if [ ! -f "$project/.githooks/$name" ]; then
            hook_missing=1
        fi
    done
    if [ "$hook_missing" -eq 0 ]; then
        note "hooks: present"
    else
        fail "hooks: missing"
    fi
fi

ensure_hook_index_modes
check_hook_index_modes

hooks_path=$(git -C "$project" config --get core.hooksPath || true)
if [ "$mode" = install ]; then
    git -C "$project" config core.hooksPath .githooks
    hooks_path=.githooks
fi
if [ "$hooks_path" = ".githooks" ]; then
    note "hooks-path: .githooks"
else
    fail "hooks-path: ${hooks_path:-unset}"
fi

if [ "$adopt" -eq 1 ]; then
    for spec in "AGENTS.md|## Agent rules" "CLAUDE.md|## Claude"; do
        file=${spec%%|*}
        if [ -f "$project/$file" ] && ! grep -q "generated by cursor-template" "$project/$file"; then
            backup_file "$file"
        fi
    done
fi
opt_file=$(abs_git_path "$project" agent-tools.local)
case $opt_file in
    /*) ;;
    *) opt_file=$project/$opt_file ;;
esac
if [ "$mode" = install ] && [ "$without_reviewer" -eq 1 ]; then
    mkdir -p "$(dirname "$opt_file")"
    if [ -f "$opt_file" ]; then
        awk 'index($0, "- **Merge reviewer:**") != 1 { print }' "$opt_file" > "$opt_file.tmp"
        mv "$opt_file.tmp" "$opt_file"
    fi
    printf '%s\n' '- **Merge reviewer:** off' >> "$opt_file"
    echo "merge-reviewer: opt-out written"
fi
if [ "$mode" = install ] && [ "$with_reviewer" -eq 1 ] && [ -f "$opt_file" ]; then
    awk 'index($0, "- **Merge reviewer:**") != 1 { print }' "$opt_file" > "$opt_file.tmp"
    mv "$opt_file.tmp" "$opt_file"
    if [ ! -s "$opt_file" ]; then
        rm -f "$opt_file"
    fi
    echo "merge-reviewer: opt-out removed"
fi
opt_out=0
if [ -f "$opt_file" ]; then
    opt_value=$(project_token "Merge reviewer" "$opt_file" || true)
    if [ "$opt_value" = "off" ]; then
        opt_out=1
    fi
fi
reviewer_enabled=0
if [ "$opt_out" -eq 1 ]; then
    note "merge-reviewer: off"
elif resolve_merge_reviewer; then
    reviewer_script=$MERGE_REVIEWER_HOME/install/link-project.sh
    if [ -f "$reviewer_script" ]; then
        # An older merge-reviewer rejects --host. Pass it only when that script knows the flag.
        reviewer_host=
        if grep -q -e '--host' "$reviewer_script"; then
            reviewer_host="--host $host"
        else
            note "merge-reviewer: link-project.sh has no --host; update merge-reviewer"
        fi
        if [ "$mode" = check ]; then
            # shellcheck disable=SC2086
            if sh "$reviewer_script" "$project" --check $reviewer_host; then
                reviewer_enabled=1
                note "merge-reviewer: linked"
            else
                fail "merge-reviewer: link check failed"
            fi
        # shellcheck disable=SC2086
        elif sh "$reviewer_script" "$project" $reviewer_host; then
            reviewer_enabled=1
            note "merge-reviewer: linked"
        else
            fail "merge-reviewer: link failed"
        fi
    else
        note "merge-reviewer: checkout missing"
    fi
else
    note "merge-reviewer: not linked"
fi
gen_args="$project --host $host"
if [ "$reviewer_enabled" -eq 1 ]; then
    gen_args="$gen_args --reviewer-enabled"
fi
if [ "$mode" = check ]; then
    gen_args="$gen_args --check"
elif [ "$adopt" -eq 1 ]; then
    gen_args="$gen_args --force"
fi
# shellcheck disable=SC2086
gen_status=0
# shellcheck disable=SC2086
python3 "$template/install/generate-agent-docs.py" $gen_args || gen_status=$?
if [ "$gen_status" -eq 0 ]; then
    note "agent-docs: ok"
elif [ "$gen_status" -eq 2 ]; then
    problems=$((problems + 1))
else
    fail "agent-docs: problem"
fi

if [ "$mode" = install ]; then
    prune_empty_host_dirs
fi

case "$docs" in
    ci)
        if [ "$mode" = install ] && [ ! -f "$project/docs/ci/docs-impact.py" ]; then
            mkdir -p "$project/docs/ci"
            cp "$template/tools/docs-impact.py" "$project/docs/ci/docs-impact.py"
            chmod +x "$project/docs/ci/docs-impact.py"
            echo "docs-impact: copied docs/ci/docs-impact.py"
        fi
        if [ "$mode" = install ]; then
            python3 "$template/install/generate-agent-docs.py" "$project" --seed-config ci
        fi
        if [ -f "$project/docs/ci/docs-impact.py" ] && [ -f "$project/docs/ci/docs-impact.config.json" ]; then
            note "docs-impact: ci present"
        else
            fail "docs-impact: ci missing"
        fi
        ;;
    local)
        if [ "$mode" = install ]; then
            python3 "$template/install/generate-agent-docs.py" "$project" --seed-config local
        fi
        if [ -f "$project/docs/scripts/docs-impact.py" ] && [ -f "$project/docs/scripts/docs-impact.config.json" ]; then
            note "docs-impact: local linked"
        else
            fail "docs-impact: local missing"
        fi
        ;;
    off)
        note "docs-impact: off"
        ;;
    *)
        fail "docs-impact: unknown $docs"
        ;;
esac

_notes=$(switch_token "Notes check" || true)
if [ -z "$_notes" ]; then
    if [ "$docs" = "ci" ]; then
        _notes=ci
    elif [ "$docs" = "local" ]; then
        _notes=local
    else
        _notes=off
    fi
fi
if [ "$_notes" = "ci" ]; then
    if [ -f "$project/docs/ci/notes-append-only.py" ] && [ ! -L "$project/docs/ci/notes-append-only.py" ]; then
        note "notes: ci copy"
    else
        fail "notes: missing"
    fi
elif [ "$_notes" = "local" ]; then
    if [ -f "$project/docs/scripts/notes-append-only.py" ]; then
        note "notes: linked"
    else
        fail "notes: missing"
    fi
else
    note "notes: off"
fi

if [ "$layer" = "local" ]; then
    if [ "$mode" = install ]; then
        sh "$template/install/agent-layer.sh" install "$project"
    elif [ "$mode" = check ]; then
        if sh "$template/install/agent-layer.sh" check "$project"; then
            note "agent-layer-check: ok"
        else
            fail "agent-layer-check: tracked files"
        fi
    fi
    note "agent-layer-hide: on"
else
    if [ "$mode" = install ]; then
        sh "$template/install/agent-layer.sh" uninstall "$project"
    fi
    note "agent-layer-hide: off"
fi

if [ "$problems" -ne 0 ]; then
    echo "install: $problems problem(s)" >&2
    exit 1
fi
echo "install: ok"
exit 0
