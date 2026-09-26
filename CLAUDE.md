# CLAUDE.md

Guidance for working on this repo. See README.md for what the module does
and its public variable interface.

## Conventions

- Declarative first: prefer `template` + `k8s_config` over `exec`/bash.
  Bash is only justified for the 3 structural reasons in README's
  "Design notes" -- don't add new bash without a reason that strong.
- Comments are one-liners or omitted. No multi-line comment blocks;
  put explanations in README instead. HCL `description` attributes are
  not comments -- keep them, they're part of the public interface.
- Host-agnostic: nothing in this module should assume GitHub specifically.
  `repo_url`/`repo_username`/`repo_token` work with any git host over
  HTTPS; the registry secret is generic (`registry_server`, not `ghcr.io`
  hardcoded) with `registry_secret_name` configurable since manifests
  reference the secret by name.
- Required variables default to `""` and are enforced at runtime via
  `: "${VAR:?}"` guards (jumppad requires every variable to have a
  default, so there's no parse-time "required" concept).

## Verifying a change

```
jumppad validate   # run from a caller blueprint, e.g. ../../jumppad
jumppad up          # full end-to-end; ~15-20min cold cache
```

There's no test suite -- this is HCL + bash glue, validated by running it
against a real k8s_cluster. Check `~/.jumppad/logs/` per-resource on
failure.

## Known jumppad limitations that shape this module's design

- `k8s_config` applies via Helm's `pkg/kube` client, not
  `kubectl apply --server-side` -- fails on CRDs whose OpenAPI schema
  exceeds the 262144-byte `last-applied-configuration` annotation cap
  (ArgoCD's `applicationsets.argoproj.io` does). That's why ArgoCD's
  install is an `exec` resource, not `k8s_config`.
- `template` resource's `variables` map silently skips substitution
  (copies `source` verbatim) if any value is a non-string type mixed
  into an otherwise-string map. Build lists into a pre-joined string
  variable instead of passing a list through `variables`.
- `exec.script = file(...)` stages content under `~/.jumppad/tmp/`,
  detached from this module's directory -- `BASH_SOURCE`-relative paths
  inside such scripts don't resolve. Get absolute paths via a `template`
  resource's `.destination` instead.
