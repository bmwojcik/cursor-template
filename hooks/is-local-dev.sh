#!/bin/sh
# cursor-template hook
# Exit 0 on a developer laptop. Exit 1 in CI and production so hooks no-op.
# Opt in: DOCS_IMPACT=1 or a marker file .docs-impact.local
# Opt out: DOCS_IMPACT=0
# Laptop probes (any match): Cursor, Claude Code, JetBrains, .ddev,
# a Mark Shust-style ../bin/cli, .docs-impact.local, MAGE_MODE=developer.

if [ "${DOCS_IMPACT:-}" = "0" ] || [ "${DOCS_IMPACT:-}" = "false" ] || [ "${DOCS_IMPACT:-}" = "no" ]; then
    exit 1
fi
if [ "${DOCS_IMPACT:-}" = "1" ] || [ "${DOCS_IMPACT:-}" = "true" ] || [ "${DOCS_IMPACT:-}" = "yes" ]; then
    exit 0
fi

if [ -n "${CI:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${BITBUCKET_BUILD_NUMBER:-}" ]; then
    exit 1
fi
if [ "${MAGE_MODE:-}" = "production" ]; then
    exit 1
fi

repo=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1

if [ -f "$repo/.docs-impact.local" ]; then
    exit 0
fi
if [ -d "$repo/.ddev" ]; then
    exit 0
fi
if [ -x "$repo/../bin/cli" ]; then
    exit 0
fi
if [ -d "${HOME}/.cursor" ]; then
    exit 0
fi
if [ -d "${HOME}/.claude" ]; then
    exit 0
fi
if [ -d "$repo/.idea" ]; then
    exit 0
fi
if [ -d "${HOME}/.config/JetBrains" ] || [ -d "${HOME}/.local/share/JetBrains" ]; then
    exit 0
fi
if [ -d "${HOME}/Library/Application Support/JetBrains" ]; then
    exit 0
fi
if [ "${MAGE_MODE:-}" = "developer" ]; then
    exit 0
fi

exit 1
