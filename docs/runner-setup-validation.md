# Runner setup validation evidence

The `Validate macOS runner setup` workflow is dispatched manually from the
`main` branch. Its job guard skips any other ref. It imports only
the existing Developer ID signing certificate into a temporary keychain, then
generates, builds, and tests the app without packaging or publishing output.

## Offline manual QA record

On 2026-07-27, the following local parser and policy check passed without
accessing GitHub Actions secrets or contacting a publication service:

```bash
ruby tests/runner_setup_workflow_test.rb
```

Output:

```text
Runner setup workflow offline policy and YAML parser checks passed.
```

The first manual run on `main` was skipped because the old guard only allowed
`release-automation`: https://github.com/SKALIFE/attendance/actions/runs/30246563365

The check verifies the manual-only trigger, main-only branch guard, read-only token,
temporary-keychain cleanup, allowed signing-secret set, absence of secret
output including `GH_TOKEN`, direct `${{ secrets.* }}` interpolation,
`printenv` and `env` environment dumps, and `set -x` or xtrace. It also
rejects notarization, release, tag, asset, or appcast publication commands and
actions.
