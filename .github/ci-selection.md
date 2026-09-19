# CI selection

Root library, tests and `example/main.dart` select the root behavioral checks
and the Flutter example, which depends on the root through `path: ../..`.
The backend example has no root dependency. Each known example subtree selects
its own lane. Root prose and Markdown under `doc/` skip behavioral checks.
Root shared configuration/dependencies and unknown paths select all lanes.
Pana and publish dry-run always run, including on docs/example-only changes.
The existing concurrency policy and separate macOS smoke are unchanged.

Only pull requests are narrowed; main pushes and manual runs (where supported)
keep full validation. The selector compares the PR merge base with its head,
counts both sides of renames and deletions, and keeps all checks for empty or
unavailable diffs. Existing jobs always start and report their original status
names; unselected steps are skipped, while selected failures/cancellation retain
normal GitHub Actions job results. No separate aggregate is needed.

Run the selector regression checks with:

```sh
python3 -B -m unittest discover -s .github -p 'test_select_ci.py'
```

Update the selection rules and dependency cases when adding packages or changing
example dependencies. Savings from narrowed PRs are projections until observed
in hosted runs; full-input PRs intentionally retain the existing work.
