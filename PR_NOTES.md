## Why

Phase 1 toolchain upgrade only: move Crystal references off `0.35.1` to a modern stable version without changing application behavior.

## Verification

Attempted locally:

```bash
env HOME=/private/tmp/sequin-swarm-20260314-100822/toolchain/.tmp-home \
  XDG_CACHE_HOME=/private/tmp/sequin-swarm-20260314-100822/toolchain/.tmp-cache \
  shards install

env HOME=/private/tmp/sequin-swarm-20260314-100822/toolchain/.tmp-home \
  XDG_CACHE_HOME=/private/tmp/sequin-swarm-20260314-100822/toolchain/.tmp-cache \
  make test
```

Result:

`shards install` could not fetch dependencies in this environment because outbound GitHub access is blocked (`Could not resolve host: github.com`), so specs could not be run locally here.
