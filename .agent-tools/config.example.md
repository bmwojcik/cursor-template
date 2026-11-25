# Tool config

Machine settings for a laptop that has the tools linked. Teammates are not asked to read this file.

<!-- Comments belong on their own line. Do not put them after a value. -->

- **Stack:** generic
- **Agent host:** both
<!-- cursor, claude, or both. Which tool's links and laptop files this laptop gets. Missing means both. A line in <git-dir>/agent-tools.local overrides this. docs/developer/agent-hosts.md -->
- **Opus parent:**
<!-- orchestrate-only or may-read. Empty keeps the neutral delegation sentence. -->
- **Agent layer:** committed
- **Agent layer tracked:**
<!-- Comma-separated paths or shell globs that stay in git even when they match the local hide list. -->
- **Keep local:**
<!-- Comma-separated paths this repo commits itself, for example docs/developer/review-change.md, docs/templates -->
- **Docs impact:** ci
- **Notes check:** ci
<!-- ci, local, or off. Empty follows Docs impact: ci when that is ci, local when that is local, otherwise off. -->
- **Cursor template version:** 0.3.0
- **Merge reviewer version:** 0.1.0
- **Review language:** English
- **Review canvas labels:** Approved / Approved with notes / Needs changes
- **Review model:** grok-4.7
- **Pre-review command:**
- **Test file command:**
- **Test paths:**
- **Base branch:** main
- **Git host:**
<!-- Empty parses git remote get-url origin. -->
- **Git project:**
<!-- Empty parses origin as group/repo. -->
- **Git base suffixes:**
<!-- suffix=ref pairs, for example -sit=origin/sit, default=origin/main -->
- **Skip branches:**

## Reproduce ticket

Paths and key names only. Never put passwords here.

- **Tracker site:**
- **Issue key prefix:**
- **Legacy tracker site:** none
- **Atlassian MCP namespace:** user-atlassian
- **Composio fallback:** no
- **Figma MCP namespace:** none
- **Playwright MCP namespace:** user-playwright
- **Local storefront URL:**
- **Forbidden local CLI:** none
- **Repro email domain:** example.com
- **Admin env file:** none
- **Preprod env file:** none
- **Preprod customer env:** none
- **Register path:**
- **Login path:**
- **Selector files:** none
- **Store-switch / cookie helper:** none
- **B2B fixture file:** none
- **Default store code:** default
- **Websites:** none
- **Read-only SQL:** none
- **Unit-test skill:** none
- **Static analysis commands:** none
- **Cache flush command (suggest only, do not run):** none
- **Deep-analysis manual:** OPERATING_MANUAL.md
