# Project guidance

Team-wide. Any agent or human can read this file. Commands live only in Environment. Tool switches live in `.agent-tools/config.md`, not here.

## Overview

Acme is a small service. Replace this with what the product does. Do not name a laptop path or a secret.

## Stack

Generic application. Name the runtime and the package manager from this repository's lockfile. Do not hard-code a version that the lockfile already records.

## Code roots

```text
src/
```

## Package naming

- **Module form:** directory under `src/`
- **Theme or app roots:** none

## Environment

```bash
# REPLACE_ME — the test command and the local start command
```

- Do not run production commands or destructive SQL unless the user asks.
- Do not print secrets from env files.

## Docs language

- **Human docs:** English
- **Agent docs:** English

## Quality bar

- No new secrets in the diff.
- A behaviour change under the code roots needs a matching docs update in the same change when this repository's CI checks docs.
- Do not weaken a test to make production pass.

## Agent rules

### Acme

- Code lives under `src/`. Grep there before naming a type.

## Claude

Optional notes that apply only to Claude Code. Leave this section empty when there are none.
