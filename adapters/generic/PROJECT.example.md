# Acme — guidance

## Overview

Acme Widget is a small service.

## Stack

Generic. Tests are `npm test`.

## Code roots

```text
src/
```

## Package naming

- **Module form:** directory under `src/`

## Environment

```bash
npm test
npm run lint
```

## Docs language

- **Human docs:** English
- **Agent docs:** English

## Quality bar

- No secrets in the diff.
- Behaviour changes under `src/` update the matching docs in the same change when CI checks docs.

## Agent rules

### Layout

Application code is `src/`. Tests sit next to it as `*.test.ts`.
