#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

base_values=(
  --set domain=example.com
  --set server.authSecret=test-auth
)

render() {
  local release="$1"
  local output="$2"
  shift 2
  helm template "$release" "$chart_dir" "${base_values[@]}" "$@" > "$output"
}

render demo "$tmp_dir/bundled.yaml" \
  --set postgresql.auth.postgresPassword=db-password \
  --set server.image.digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

grep -q 'host: "demo-postgresql"' "$tmp_dir/bundled.yaml"
grep -q 'kind: StatefulSet' "$tmp_dir/bundled.yaml"
grep -q 'password: "db-password"' "$tmp_dir/bundled.yaml"
grep -q 'netbird-server:0.77.0@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$tmp_dir/bundled.yaml"

render demo "$tmp_dir/sqlite.yaml" \
  --set postgresql.enabled=false

grep -q 'engine: "sqlite"' "$tmp_dir/sqlite.yaml"
grep -q 'replicas: 1' "$tmp_dir/sqlite.yaml"
grep -q 'type: Recreate' "$tmp_dir/sqlite.yaml"
! grep -q 'kind: StatefulSet' "$tmp_dir/sqlite.yaml"

render demo "$tmp_dir/external.yaml" \
  --set server.database.mode=external \
  --set postgresql.enabled=false \
  --set server.database.external.engine=postgres \
  --set server.database.external.host=db.example \
  --set server.database.external.username=netbird \
  --set server.database.external.password=db-password

grep -q 'host: "db.example"' "$tmp_dir/external.yaml"
! grep -q 'kind: StatefulSet' "$tmp_dir/external.yaml"

render demo "$tmp_dir/auto-external.yaml" \
  --set server.database.external.engine=postgres \
  --set server.database.external.host=db.example \
  --set server.database.external.username=netbird \
  --set server.database.external.password=db-password

grep -q 'engine: "postgres"' "$tmp_dir/auto-external.yaml"
grep -q 'host: "db.example"' "$tmp_dir/auto-external.yaml"

render demo "$tmp_dir/mysql.yaml" \
  --set server.database.mode=external \
  --set postgresql.enabled=false \
  --set server.database.external.engine=mysql \
  --set server.database.external.host=mysql.example \
  --set server.database.external.port=3306 \
  --set server.database.external.username=netbird \
  --set server.database.external.password=db-password

grep -q 'engine: "mysql"' "$tmp_dir/mysql.yaml"
grep -q 'port: 3306' "$tmp_dir/mysql.yaml"

render demo "$tmp_dir/ingress.yaml" \
  --set ingress.enabled=true \
  --set server.services.stun.type=LoadBalancer \
  --set postgresql.auth.postgresPassword=db-password

grep -q 'kind: Ingress' "$tmp_dir/ingress.yaml"
grep -q 'name: demo-netbird-stun' "$tmp_dir/ingress.yaml"

render demo "$tmp_dir/gateway.yaml" \
  --set gateway.enabled=true \
  --set 'gateway.parentRefs[0].name=default-gateway' \
  --set postgresql.auth.postgresPassword=db-password \
  --api-versions gateway.networking.k8s.io/v1/HTTPRoute \
  --api-versions gateway.networking.k8s.io/v1/GRPCRoute \
  --api-versions gateway.networking.k8s.io/v1alpha2/UDPRoute

! grep -q '^kind: Ingress' "$tmp_dir/gateway.yaml"
grep -q '^kind: UDPRoute' "$tmp_dir/gateway.yaml"

render demo "$tmp_dir/bootstrap.yaml" \
  --set postgresql.auth.postgresPassword=db-password \
  --set bootstrap.enabled=true \
  --set bootstrap.credentials.email=admin@example.com \
  --set bootstrap.credentials.name='NetBird Admin' \
  --set bootstrap.credentials.password=bootstrap-password

grep -q '^kind: Job' "$tmp_dir/bootstrap.yaml"
grep -q 'name: demo-netbird-bootstrap' "$tmp_dir/bootstrap.yaml"
grep -q 'kind: Role' "$tmp_dir/bootstrap.yaml"
grep -q 'kind: RoleBinding' "$tmp_dir/bootstrap.yaml"
grep -q 'name: demo-netbird-mgmt-api-key' "$tmp_dir/bootstrap.yaml"
grep -q 'NB_SETUP_PAT_ENABLED' "$tmp_dir/bootstrap.yaml"

render demo "$tmp_dir/bootstrap-existing-credentials.yaml" \
  --set postgresql.auth.postgresPassword=db-password \
  --set bootstrap.enabled=true \
  --set bootstrap.existingCredentialsSecret=netbird-bootstrap-credentials \
  --set bootstrap.credentials.emailKey=login \
  --set bootstrap.credentials.nameKey=display-name \
  --set bootstrap.credentials.passwordKey=initial-password

grep -q 'name: netbird-bootstrap-credentials' "$tmp_dir/bootstrap-existing-credentials.yaml"
grep -q 'key: login' "$tmp_dir/bootstrap-existing-credentials.yaml"
grep -q 'key: display-name' "$tmp_dir/bootstrap-existing-credentials.yaml"
grep -q 'key: initial-password' "$tmp_dir/bootstrap-existing-credentials.yaml"

render demo "$tmp_dir/bootstrap-disabled.yaml" \
  --set postgresql.auth.postgresPassword=db-password \
  --set bootstrap.enabled=true \
  --set bootstrap.createUser=false

! grep -q '^kind: Job' "$tmp_dir/bootstrap-disabled.yaml"

default_invalid_output="$tmp_dir/invalid.yaml"
if helm template demo "$chart_dir" > "$default_invalid_output" 2>&1; then
  echo "expected missing required values to fail" >&2
  exit 1
fi

echo "chart render smoke tests passed"
