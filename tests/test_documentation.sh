#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=cyberops.sh
source "$REPO_DIR/cyberops.sh"

tests_run=0
tests_failed=0

record_result() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    ((tests_run += 1))
    if [[ "$actual" == "$expected" ]]; then
        printf 'ok %d - %s\n' "$tests_run" "$name"
    else
        printf 'not ok %d - %s (expected %s, got %s)\n' \
            "$tests_run" "$name" "$expected" "$actual"
        ((tests_failed += 1))
    fi
}

readme_lines="$(wc -l <"$REPO_DIR/README.md")"
if ((readme_lines < 350)); then
    readme_result=concise
else
    readme_result=long
fi
record_result "README remains a concise project entry point" "$readme_result" concise

required_guides=(DOCKER.md USB.md OPERATIONS.md DEMO.md)
for required_guide in "${required_guides[@]}"; do
    [[ -s "$REPO_DIR/docs/$required_guide" ]] && guide_result=present || guide_result=missing
    record_result "provides docs/$required_guide" "$guide_result" present
done

if grep -Fq "Privilege" "$REPO_DIR/docs/OPERATIONS.md" &&
    grep -Fq "side effect" "$REPO_DIR/docs/OPERATIONS.md"; then
    operation_result=documented
else
    operation_result=missing
fi
record_result "documents operation privileges and side effects" "$operation_result" documented

if grep -Fq "CYBEROPS Terminal $VERSION" "$REPO_DIR/docs/DEMO.md"; then
    demo_result=current
else
    demo_result=stale
fi
record_result "terminal demonstration uses the current version" "$demo_result" current

printf '1..%d\n' "$tests_run"

if ((tests_failed > 0)); then
    exit 1
fi
