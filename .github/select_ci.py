"""Conservative PR selection; main/manual runs always keep full validation."""

import os
import subprocess


def changed_paths():
    if os.environ.get("EVENT_NAME") != "pull_request":
        return None
    base, head = os.environ.get("BASE_SHA", ""), os.environ.get("HEAD_SHA", "")
    if not base or not head:
        return None
    try:
        # Disable rename detection so both the removed and added paths count.
        result = subprocess.run(
            ["git", "diff", "--no-renames", "--name-only", "-z", f"{base}...{head}", "--"],
            check=True, capture_output=True,
        )
    except subprocess.CalledProcessError:
        print("::warning::Could not compare PR revisions; running all checks")
        return None
    return [os.fsdecode(path) for path in result.stdout.split(b"\0") if path]


def select(paths):
    lanes = {"package": False, "flutter": False, "backend": False}
    if not paths:
        return dict.fromkeys(lanes, True)
    for path in paths:
        if path in {"README.md", "CHANGELOG.md", "LICENSE"} or (
            path.startswith("doc/") and path.endswith(".md")
        ):
            continue
        if path.startswith("example/flutter_hybrid_genui/"):
            lanes["flutter"] = True
        elif path.startswith("example/genui_backend_server/"):
            lanes["backend"] = True
        elif path.startswith(("lib/", "test/")) or path == "example/main.dart":
            # Only the Flutter example has a path dependency on the root package.
            lanes["package"] = lanes["flutter"] = True
        else:
            # Shared config/dependencies, workflows, and unknown paths stay broad.
            return dict.fromkeys(lanes, True)
    return lanes


if __name__ == "__main__":
    selection = select(changed_paths())
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        for lane, enabled in selection.items():
            print(f"{lane}={str(enabled).lower()}", file=output)
    print(f"CI selection: {selection}")
