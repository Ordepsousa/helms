# NetBird Helm Chart

Helm chart for deploying the NetBird monolith server and dashboard.

## Requirements

- Kubernetes 1.25 or newer.
- Helm 3.
- A DNS name for the NetBird installation.
- A TLS certificate configured on the Ingress or Gateway.
- A publicly reachable UDP endpoint for STUN on port `3478`.

The default database mode is `auto` and the bundled PostgreSQL dependency is enabled by default. Set `postgresql.enabled: false` to make `auto` use SQLite instead. SQLite always uses one server replica and the `Recreate` deployment strategy.

## Required values

Set a domain and both server secrets. The following example is only suitable for testing; use an external Secret management solution for production.

```yaml
domain: netbird.example.com

server:
  authSecret: replace-with-a-random-secret
  encryptionKey: replace-with-a-random-encryption-key
  database:
    mode: auto
postgresql:
  auth:
    postgresPassword: replace-with-a-database-password
```

For production, prefer `server.config.existingSecret` with a Secret created outside Helm. The configured key must contain the complete NetBird server configuration YAML.

## Values reference

The complete parameter reference, including defaults and inline descriptions, is maintained in [values.yaml](values.yaml). The main groups are:

| Group | Purpose |
| --- | --- |
| `domain` | Public NetBird DNS name and redirect URLs. |
| `ingress` | HTTP exposure for dashboard and server paths. |
| `gateway` | Gateway API exposure for HTTP, gRPC and UDP. |
| `serviceAccount` | Shared ServiceAccount configuration. |
| `server` | Management server image, storage, database, probes and security. |
| `dashboard` | Dashboard image, Service, probes and security. |
| `metrics` | Server metrics port and enablement. |
| `probes` | Shared startup, liveness and readiness timing. |
| `postgresql` | Values passed to the bundled Bitnami PostgreSQL subchart. |
| `bootstrap` | Optional first-user creation and API token Job. |

## Bootstrap first user and API token

Bootstrap is disabled by default. When enabled, the chart:

1. Sets `NB_SETUP_PAT_ENABLED=true` on the server.
2. Waits for the server and dashboard Services to respond.
3. Calls `/api/setup` to create the first user and request a PAT.
4. Stores the PAT as `NB_API_KEY` in the configured API key Secret.

The Job uses a dedicated ServiceAccount, Role and RoleBinding. Its Role can only update the pre-created API key Secret; it does not use the shared workload ServiceAccount.

The current flow requires both `createUser` and `generateAPIKey` to be true:

```yaml
bootstrap:
  enabled: true
  createUser: true
  generateAPIKey: true
  apiKeySecretName: netbird-mgmt-api-key
  credentials:
    email: admin@example.com
    name: NetBird Admin
    password: replace-with-a-password
```

For production, create the credentials Secret outside Helm and reference it:

```yaml
bootstrap:
  enabled: true
  existingCredentialsSecret: netbird-bootstrap-credentials
  credentials:
    emailKey: email
    nameKey: name
    passwordKey: password
```

The Job is configured as a `post-install,post-upgrade` Helm hook and skips token generation when the output Secret already contains `NB_API_KEY`. The default Job image installs `curl`, `jq` and `kubectl` from Alpine at runtime; pin or replace this image in restricted production environments.

## HTTP Ingress and STUN

A Kubernetes Ingress exposes HTTP/HTTPS only. It does not expose STUN UDP traffic. When using Ingress, use a separate UDP `LoadBalancer` Service for STUN:

```yaml
domain: netbird.example.com
ingress:
  enabled: true
  className: nginx
  tls:
    - secretName: netbird-tls
      hosts:
        - netbird.example.com
  hosts:
    - netbird.example.com

server:
  strategy:
    type: Recreate
  database:
    mode: sqlite
  services:
    http:
      type: ClusterIP
      port: 80
    stun:
      type: LoadBalancer
      port: 3478
```

The chart creates two HTTP Ingress resources:

- `netbird-dashboard`: `/` -> dashboard Service.
- `netbird-server`: `/api`, `/oauth2`, `/ws-proxy` and `/relay` -> server Service.

The standard Ingress resources cover HTTP paths only. NetBird management and signal gRPC traffic is exposed by the Gateway API routes, not by a portable Kubernetes Ingress configuration. Use Gateway API for HTTP + gRPC + UDP, or add controller-specific gRPC configuration and test it with the selected Ingress controller.

It also creates `<release>-<chart>-stun`:

- Service type: `server.services.stun.type`.
- Protocol: UDP.
- Port: `server.services.stun.port`.

After installation, check the external address:

```bash
kubectl get service <release>-<chart>-stun
```

Create a DNS record for the LoadBalancer address if your deployment requires a separate STUN hostname, and allow UDP port `3478` in the cloud firewall or security group.

Do not set `ingress.enabled` and `gateway.enabled` to `true` at the same time. Ingress resources are suppressed when Gateway API is enabled.

## Database

Use SQLite explicitly, or disable the bundled PostgreSQL dependency and keep `mode: auto`. SQLite is intended for a single server replica and uses the `Recreate` deployment strategy:

```yaml
server:
  replicaCount: 1
  strategy:
    type: Recreate
  database:
    mode: sqlite

postgresql:
  enabled: false
```

For an external PostgreSQL or MySQL database, configure the external connection settings and use a rolling strategy if desired:

```yaml
server:
  strategy:
    type: RollingUpdate
  database:
    mode: external
    external:
      engine: postgres
      host: postgres.example.com
      port: 5432
      name: netbird
      username: netbird
      password: replace-with-a-secret
      sslMode: require

```

Enable the bundled Bitnami PostgreSQL dependency at the same time:

```yaml
postgresql:
  enabled: true
  auth:
    username: netbird
    database: netbird
    postgresPassword: replace-with-a-secret
```

Set `external.engine: mysql` and port `3306` for MySQL. The optional `external.dsn` is used directly and ignores host, username and password fields. With `mode: auto`, external configuration is selected first when `external.host`, `external.dsn` or `external.existingSecret` is set; otherwise the PostgreSQL dependency is selected when enabled, and SQLite is used as the final fallback.

External database example:

```yaml
server:
  database:
    mode: external
    external:
      engine: mysql
      host: mysql.example.com
      port: 3306
      name: netbird
      username: netbird
      password: replace-with-a-secret
```

Instead of `external.password`, set `external.existingSecret` and `external.existingSecretPasswordKey`. The chart reads that Secret with Helm `lookup`, so installation/rendering needs access to the target cluster. A raw `external.dsn` takes precedence over host, username and password fields.

The bundled PostgreSQL password is stored in Helm values and rendered into the NetBird configuration Secret. For production, use an external Secret management system and avoid passing passwords through `--set`.

## Storage, backups and upgrades

The server PVC is named `<release>-<chart>-data`. If upgrading from a release that used the old PVC name without the `-data` suffix, preserve the existing data with:

```yaml
server:
  persistence:
    existingClaim: old-pvc-name
```

The PVC uses `helm.sh/resource-policy: keep`, so uninstalling the release does not delete it. Delete the PVC manually only when intentionally destroying the data.

Back up both the NetBird database and the PostgreSQL PVC before chart upgrades. For SQLite, stop the server before copying the database. For PostgreSQL, use `pg_dump` or the backup mechanism of the managed PostgreSQL provider. Test restores separately from backups.

The default server and dashboard resource requests/limits are conservative starting points. Adjust them for production workloads and monitor CPU, memory, disk space and PostgreSQL health.

The server requires elevated networking capabilities for NetBird networking features. Keep the default Pod security settings under review and remove capabilities that are not needed by the features you enable. The dashboard should be tested with `runAsNonRoot` and a read-only root filesystem before hardening those defaults.

## Gateway API

Gateway API can expose HTTP, gRPC and UDP, but the installed Gateway controller must support `HTTPRoute`, `GRPCRoute` and `UDPRoute`.

```yaml
domain: netbird.example.com
gateway:
  enabled: true
  parentRefs:
    - name: netbird-gateway
      namespace: gateway-system

server:
  services:
    stun:
      type: ClusterIP
      port: 3478
```

The Gateway must have compatible HTTP/HTTPS, gRPC and UDP listeners. The UDP route targets `netbird-stun:3478`. Configure the Gateway listener and any required `ReferenceGrant` resources according to the selected Gateway controller.

## Install

```bash
helm upgrade --install netbird ./netbird \
  --set domain=netbird.example.com \
  --set server.authSecret=replace-with-a-random-secret \
  --set server.encryptionKey=replace-with-a-random-encryption-key \
  --set postgresql.auth.postgresPassword=replace-with-a-database-password
```

Review the generated manifests before installing:

```bash
helm lint ./netbird
helm template netbird ./netbird -f values-production.yaml
```

## OCI releases

Push a version tag matching `Chart.yaml` to publish the chart. For example, with `version: 0.1.0`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The GitHub Actions workflow runs the lint and render tests, packages the chart, attaches `netbird-0.1.0.tgz` to the GitHub Release, and pushes the chart to GHCR.

Install the published chart with OCI:

```bash
helm install netbird oci://ghcr.io/OWNER/netbird \
  --version 0.1.0 \
  -f values-production.yaml
```

Replace `OWNER` with the GitHub organization or user that owns the repository. For a private package, authenticate Helm to GHCR before installing:

```bash
echo "$CR_PAT" | helm registry login ghcr.io --username OWNER --password-stdin
```
