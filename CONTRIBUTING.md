# Contributing

This repo is experimental, but changes should still be small, testable, and
easy to reason about.

## Development Principles

- **SOLID where it helps**: keep responsibilities clear, depend on interfaces
  such as `GenUiBackend`, and extend behavior through composition.
- **KISS by default**: prefer small adapters and explicit data objects over
  framework-heavy abstractions.
- Keep the root `genui_genkit` package provider-neutral.
- Keep llamadart-specific setup in `genkit_llamadart`, backend examples, or
  app/example routes. Do not add provider-specific code to the core package.
- Use Genkit's official server integrations, such as `genkit_shelf`, before
  adding custom server infrastructure.
- Remove dead demos, fake runtime paths, and unused config fields when they no
  longer explain or test real behavior.

## Documentation Expectations

When public behavior changes, update the relevant docs in the same change:

- root `README.md` for the pub.dev-facing project story
- `doc/architecture.md` for architecture or mode changes
- example READMEs for runnable commands and environment variables
- `AGENTS.md` for durable agent workflow rules

The root README should start with a short value proposition, show a visual or
diagram when it helps, and include copyable Dart snippets.

## Lint Policy

The repo uses `package:lints/recommended.yaml`, strict analyzer language
options, and a focused set of additional stable lints in the root
`analysis_options.yaml`.

The goal is not maximum lint count. The goal is maintainable code with:

- explicit generic types where they affect API safety
- no discarded futures unless intentionally wrapped with `unawaited`
- owned subscriptions and stream controllers closed or cancelled
- small functions with clear return types
- no committed path dependencies for packages outside this repo

Use `pubspec_overrides.yaml` for local dependency development and keep it
uncommitted.

## Test Matrix

Run checks for the package and each example you changed.

```sh
flutter analyze
flutter test
```

```sh
cd example/flutter_hybrid_genui
flutter analyze
flutter test
flutter test integration_test -d macos
```

```sh
cd example/genui_backend_server
dart analyze
dart test
dart run bin/server.dart
```

For backend server manual tests, report the bound URL and stop the server when
finished unless the user explicitly asks to leave it running.

## Pub.dev Readiness

Before publishing a package:

- verify `LICENSE`, `README.md`, `CHANGELOG.md`, and `example/`
- run analysis and tests from the repo root
- check that the README explains scope and limitations
- confirm public APIs have enough Dart doc comments for generated docs
- avoid URLs or badges that cannot be rendered from pub.dev

## Release Automation

The first version of a package must be published manually with
`flutter pub publish`. After that, configure automated publishing from the
package's pub.dev Admin tab:

- repository: `leehack/genui_genkit`
- tag pattern: `v{{version}}`
- GitHub environment: `pub.dev`

Future releases use a guarded release-prep PR:

1. Create a same-repository branch named `release/<version>-prep`.
2. Change only `pubspec.yaml` and `CHANGELOG.md`: bump the package version and
   replace `## Unreleased` with `## <version> - YYYY-MM-DD`.
3. Run the normal release checks and complete review.
4. Merge the PR to approve publication.

The `Release on prep merge` workflow verifies the branch or `release-prep`
label, same-repository origin, two-file scope, version, changelog heading, and
merge commit. It then creates the matching `v<version>` tag at the exact merge
commit and dispatches `Publish to pub.dev` at that tag.

The publish workflow reruns package checks, performs a publish dry run,
publishes through pub.dev OIDC, and creates or updates the GitHub Release from
the version's changelog notes. Manual workflow dispatch from an existing
matching release tag reruns the checks and attempts publication, so use it only
to retry a failed publish while that version is not yet live; dispatching it
from a branch fails before publication. Rerunning a failed `Release on prep
merge` workflow repairs a missing GitHub Release when the package version is
already live.

Do not manually create the release tag after merging a guarded release-prep PR.
Ordinary PRs must not use a release-prep branch pattern or the `release-prep`
label.

The default CI workflow runs package checks plus the Flutter and backend example
analyze/test suites. The macOS integration smoke is available as a separate
manual workflow because GitHub-hosted macOS desktop integration tests are much
slower and less predictable than the unit/widget matrix.
