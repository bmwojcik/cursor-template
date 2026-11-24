# Generic upgrade checklist

For `upgrade-dependency` step 2 and step 4 when the stack has no dedicated checklist.

- **Diff upstream** between the old and new tag. Read the CHANGELOG, migration guide, and deprecation list for the whole range.
- **Consumers**: grep imports, requires, class names, function names, configuration keys, CLI flags, environment variables, HTTP endpoints, and database objects of the package across the code roots in `PROJECT.md`. Include build and CI files, Dockerfiles, and scripts.
- **Subclassing and monkey-patching**: our subclasses, overrides, mocks, and patches of upstream code break first.
- **Dependency injection or plugin registration by string** (container config, service names, entry points): a typechecker does not see these.
- **Transitive**: other packages that depend on the upgraded one, and peer-dependency ranges.
- **Checks**: typecheck, lint, and unit tests from `PROJECT.md`, on a clean install from the lock file. Then exercise each runtime path the consumers touch. Passing tests do not prove that a string-registered service or a removed endpoint still works.
