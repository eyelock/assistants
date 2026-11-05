#!/usr/bin/env bash
# docs-sync, TypeScript layout: a small library on main; the branch
# feat/parse-options renames parseConfig to loadConfig and the test script
# from test:unit to test. README's example and AGENTS.md's test command are
# left behind; docs/api.md was updated with the change.
set -euo pipefail
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src docs
cat > src/config.ts <<'TS'
/** Parses a config file. Throws on a missing file. */
export function parseConfig(path: string): Record<string, string> {
  return {};
}
TS
cat > package.json <<'JSON'
{ "name": "conf", "version": "1.0.0", "scripts": { "test:unit": "node --test" } }
JSON
cat > README.md <<'MD'
# conf

```ts
import { parseConfig } from "conf";
const config = parseConfig("app.conf");
```
MD
cat > docs/api.md <<'MD'
# API

`parseConfig(path)` parses a config file, and throws on a missing one.
MD
cat > AGENTS.md <<'MD'
# conf

Run the tests with `npm run test:unit` before every commit.
MD
git add -A && git commit -qm "feat: conf"
git checkout -qb feat/parse-options
cat > src/config.ts <<'TS'
/** Loads a config file. Returns an empty config for a missing file. */
export function loadConfig(path: string): Record<string, string> {
  return {};
}
TS
cat > package.json <<'JSON'
{ "name": "conf", "version": "2.0.0", "scripts": { "test": "node --test" } }
JSON
cat > docs/api.md <<'MD'
# API

`loadConfig(path)` loads a config file, and returns an empty config for a missing one.
MD
git commit -qam "feat!: loadConfig replaces parseConfig; npm test"
