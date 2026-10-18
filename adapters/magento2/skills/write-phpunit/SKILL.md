---
name: write-phpunit
description: >-
  Writes Magento 2 PHPUnit unit tests as one class per production class with
  @dataProvider or Test/Unit/_files JSON. Use when the user asks for phpunit
  or unit tests; when you changed a production class that already has
  Test/Unit/{Class}Test.php; when you added a class with branching, mapping,
  or money math; or when price, tax, or ERP pricing math needs a new case.
  Do not use for integration tests.
---

# Write PHPUnit unit tests

This skill is mandatory in the **same change set** as the production PHP when `AGENTS.md` § When tests are mandatory applies. Integration tests are out of scope.

The run command is `PROJECT.md` **Test paths**. Do not invent a different runner.

## Read first

1. The production class in the diff (grep names; do not guess).
2. **One** existing exemplar under the code roots in `PROJECT.md`: a `Test/Unit/*Test.php` next to similar code. Do not open the whole `Test/` tree or `dev/tests/`.
3. Skip integration trees and `vendor/**/Test`.

## Shape

- Path: `app/code/{Vendor}/{Module}/Test/Unit/.../{Class}Test.php`
- Namespace mirrors the path.
- One test class per production class. Scenarios are `@dataProvider` rows or JSON under `Test/Unit/_files/`. Never one PHP file per case.
- Match the PHPUnit major version this repo already runs (annotations versus attributes). Do not mix in a new style.
- `declare(strict_types=1);`. No inline comments. No `ObjectManager`. Construct real data objects with `new`. `createMock` for collaborators.
- Assert formatted money as strings when the code formats that way.

## After writing

Run the **Test paths** command from `PROJECT.md`, scoped to the module you changed. Do not run platform setup or cache CLI. If the environment is down, give the command and do not claim green.

## Coverage

Add a row for every branch the method actually has (flag off, early return, the formula, zero quantity, parent versus child).

## Editing existing tests

Default is additive. Full rule: `.cursor/rules/phpunit.mdc`.

- Intended production contract change → edit the matching test in the same change set.
- A wrong test → test-only commit.
- Never change an expected value, delete a row, or loosen a matcher just to get green.
