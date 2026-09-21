#!/usr/bin/env bash
# Local sanity checks for the Compute IBB — schema validation of manifest and
# example/test fixtures. This is a developer convenience, NOT a substitute for the automated
# (lint, secret scanning, SAST, IaC scan, policy conformance, unit/integration/contract tests) which must run on every pull request.
#
# Requires python3 with PyYAML and jsonschema:  pip install pyyaml jsonschema
set -euo pipefail

cd "$(dirname "$0")/.."

if ! python3 -c "import yaml, jsonschema" 2>/dev/null; then
  echo "error: needs python3 with PyYAML and jsonschema -- pip install pyyaml jsonschema" >&2
  exit 1
fi

echo "== Validating ibb-manifest.yaml is present and parseable =="
python3 -c "import yaml,sys; yaml.safe_load(open('ibb-manifest.yaml'))"

echo "== Validating example/test request fixtures against the input schema =="
for f in tests/requests/*.json examples/*.json; do
  [ -e "$f" ] || continue
  echo "  - $f"
  python3 - "$f" <<'PY'
import json, sys
import jsonschema
schema = json.load(open("schemas/compute-input-0.1.0.schema.json"))
# Catches a schema that is itself malformed (e.g. an empty "allOf") before it is
# used to judge a fixture, so the error names the real problem.
jsonschema.Draft202012Validator.check_schema(schema)
instance = json.load(open(sys.argv[1]))
jsonschema.validate(instance, schema)
PY
done

echo "OK"
