# cursor-template hook
# Source from a project hook. Does not print cursor.env.
# Caller sets $repo to the project root before calling the resolve functions.
# An environment variable that is already set wins over the same key in cursor.env
# and stops the search (a bad path is not replaced by a later candidate).

project_field() {
    _pf_key=$1
    _pf_file=$2
    awk -v key="$_pf_key" '
        $0 ~ "^[[:space:]]*- \\*\\*" key ":\\*\\*" {
            sub(/^[[:space:]]*- \*\*/, "")
            sub(/^[^*]*\*\*[[:space:]]*/, "")
            gsub(/`/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$_pf_file"
}

project_token() {
    project_field "$1" "$2" | awk 'NF { print $1; exit }'
}

_tool_config_warned=0

tool_config_path() {
    if [ -n "${repo:-}" ] && [ -f "$repo/.agent-tools/config.md" ]; then
        printf '%s\n' "$repo/.agent-tools/config.md"
        return 0
    fi
    if [ -n "${repo:-}" ] && [ -f "$repo/PROJECT.md" ]; then
        if [ "$_tool_config_warned" != 1 ] && grep -q -E '^- \*\*(Stack|Agent layer|Docs impact|Merge reviewer|Keep local|Cursor template version):\*\*' "$repo/PROJECT.md"; then
            echo "cursor-template: switches still in PROJECT.md — run install.sh --migrate-config" >&2
            _tool_config_warned=1
        fi
        printf '%s\n' "$repo/PROJECT.md"
        return 0
    fi
    return 1
}

switch_token() {
    _st_file=$(tool_config_path) || return 1
    project_token "$1" "$_st_file"
}

switch_field() {
    _sf_file=$(tool_config_path) || return 1
    project_field "$1" "$_sf_file"
}

version_lt() {
    python3 - "$1" "$2" <<'PY'
import sys

def parse(raw):
    raw = raw.strip()
    if not raw:
        return ()
    raw = raw.lstrip("v").split()[0]
    parts = []
    for piece in raw.split("."):
        if piece.isdigit():
            parts.append(int(piece))
        else:
            break
    return tuple(parts)

have, need = parse(sys.argv[1]), parse(sys.argv[2])
sys.exit(0 if have < need else 1)
PY
}

resolve_tools_load_env() {
    _rt_ct_had=0
    _rt_mr_had=0
    _rt_ct_val=
    _rt_mr_val=
    if [ "${CURSOR_TEMPLATE_HOME+x}" = x ]; then
        _rt_ct_had=1
        _rt_ct_val=$CURSOR_TEMPLATE_HOME
    fi
    if [ "${MERGE_REVIEWER_HOME+x}" = x ]; then
        _rt_mr_had=1
        _rt_mr_val=$MERGE_REVIEWER_HOME
    fi
    _rt_file=${XDG_CONFIG_HOME:-$HOME/.config}/review-change/cursor.env
    if [ -f "$_rt_file" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$_rt_file"
        set +a
    fi
    if [ "$_rt_ct_had" = 1 ]; then
        CURSOR_TEMPLATE_HOME=$_rt_ct_val
    fi
    if [ "$_rt_mr_had" = 1 ]; then
        MERGE_REVIEWER_HOME=$_rt_mr_val
    fi
    unset _rt_ct_had _rt_mr_had _rt_ct_val _rt_mr_val _rt_file
}

resolve_cursor_template() {
    if [ "${CURSOR_TEMPLATE_HOME+x}" = x ]; then
        if [ -n "$CURSOR_TEMPLATE_HOME" ] && [ -f "$CURSOR_TEMPLATE_HOME/VERSION" ]; then
            return 0
        fi
        return 1
    fi
    if [ -n "${repo:-}" ] && [ -f "$repo/tools/cursor-template/VERSION" ]; then
        CURSOR_TEMPLATE_HOME=$repo/tools/cursor-template
        return 0
    fi
    return 1
}

resolve_merge_reviewer() {
    if [ "${MERGE_REVIEWER_HOME+x}" = x ]; then
        if [ -n "$MERGE_REVIEWER_HOME" ] && [ -f "$MERGE_REVIEWER_HOME/bin/post-commit-review" ]; then
            return 0
        fi
        return 1
    fi
    if [ -n "${repo:-}" ] && [ -f "$repo/tools/merge-reviewer/bin/post-commit-review" ]; then
        MERGE_REVIEWER_HOME=$repo/tools/merge-reviewer
        return 0
    fi
    if [ -n "${CURSOR_TEMPLATE_HOME:-}" ]; then
        _rt_sibling=$(dirname "$CURSOR_TEMPLATE_HOME")/merge-reviewer
        if [ -f "$_rt_sibling/bin/post-commit-review" ]; then
            MERGE_REVIEWER_HOME=$_rt_sibling
            unset _rt_sibling
            return 0
        fi
        unset _rt_sibling
    fi
    return 1
}

warn_template_version() {
    [ -n "${repo:-}" ] || return 0
    [ -n "${CURSOR_TEMPLATE_HOME:-}" ] || return 0
    [ -f "$CURSOR_TEMPLATE_HOME/VERSION" ] || return 0
    tool_config_path >/dev/null || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    _wv_have=$(tr -d '[:space:]' < "$CURSOR_TEMPLATE_HOME/VERSION")
    _wv_need=$(switch_token "Cursor template version" || true)
    [ -n "$_wv_need" ] || return 0
    if version_lt "$_wv_have" "$_wv_need"; then
        _wv_stamp=$(git -C "$repo" rev-parse --git-path cursor-template-version-warned)
        _wv_token="${_wv_have}<${_wv_need}"
        if [ -f "$_wv_stamp" ] && [ "$(cat "$_wv_stamp")" = "$_wv_token" ]; then
            unset _wv_have _wv_need _wv_stamp _wv_token
            return 0
        fi
        echo "cursor-template: checkout ${_wv_have} is older than config minimum ${_wv_need}" >&2
        printf '%s\n' "$_wv_token" > "$_wv_stamp"
    fi
    unset _wv_have _wv_need _wv_stamp _wv_token
}
