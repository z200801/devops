# k8s-get-config

A Bash utility for managing Kubernetes user access via ServiceAccounts and RBAC, with kubeconfig generation. Tested on Kubernetes 1.34+.

## Features

- Create users with `admin` (cluster-admin) or `readonly` (view + nodes-viewer) roles.
- Issue short-lived tokens via `kubectl create token` with configurable TTL.
- Issue long-lived tokens via manually-managed Secrets with the `kubernetes.io/service-account.name` annotation.
- Generate ready-to-use kubeconfig files (`<user>-kubeconfig`) in the current directory.
- List existing users with TTL and expiry info, in a human table or JSON.
- Backward compatibility: detects users in `kube-system` (legacy installations) for `--list` and `--delete`.
- Uses a dedicated namespace for users (default: `kube-users`, autocreated).

## Requirements

- `kubectl` configured against the target cluster with admin permissions (must be able to create ServiceAccounts, ClusterRoleBindings, Secrets, and Namespaces).
- `jq`
- `base64` (GNU coreutils)
- A Kubernetes cluster, version 1.24+ recommended; tested on 1.34+.

## Installation

```bash
chmod +x k8s-get-config.sh
./k8s-get-config.sh --help
```

## Usage

```
Usage: ./k8s-get-config.sh [OPTIONS]

Options:
  --create   --user <name> --role <admin|readonly> [--ttl <duration>]
  --delete   --user <name>
  --mkconfig --user <name> [--ttl <duration>]
  --list [--json]
```

### Roles

| Role       | Bindings                                        |
| ---------- | ----------------------------------------------- |
| `admin`    | `cluster-admin` ClusterRole                     |
| `readonly` | `view` ClusterRole + custom `nodes-viewer` (get/list/watch on `nodes`) |

The custom `nodes-viewer` ClusterRole is created automatically on the first `readonly` user creation.

### TTL

The `--ttl` flag controls token lifetime:

| `--ttl` value         | Behavior                                                     |
| --------------------- | ------------------------------------------------------------ |
| not provided          | Long-lived token (manual Secret)                             |
| `0`                   | Long-lived token (manual Secret)                             |
| Go duration (`24h`, `30m`, `2h30m`, `7d`, `3600s`) | Short-lived token via `kubectl create token --duration` |

**Important**: short-lived TTLs are bounded by the API server's `--service-account-max-token-expiration` flag (default ~24h on most clusters). If the API server truncates a requested TTL, the script prints a warning showing the actual expiry.

To raise the limit, set on the kube-apiserver:

```
--service-account-max-token-expiration=720h
```

Long-lived tokens via manual Secret have no expiry. They are technically supported in Kubernetes 1.34 but considered legacy by the official documentation. They are appropriate for trusted long-running CI/CD pipelines or admin tooling, but **should be rotated manually** as a hygiene practice.

### Examples

```bash
# Long-lived admin token (default behavior)
./k8s-get-config.sh --create --user alice --role admin

# Long-lived readonly token (explicit)
./k8s-get-config.sh --create --user observer --role readonly --ttl 0

# Short-lived (24h) admin token for CI
./k8s-get-config.sh --create --user ci-deploy --role admin --ttl 24h

# Short-lived (30 days) readonly token
./k8s-get-config.sh --create --user audit --role readonly --ttl 720h

# Regenerate kubeconfig using the existing long-lived secret
./k8s-get-config.sh --mkconfig --user alice

# Issue a fresh 8h short-lived token, overwrite kubeconfig
./k8s-get-config.sh --mkconfig --user observer --ttl 8h

# Replace existing token with a new long-lived one
./k8s-get-config.sh --mkconfig --user alice --ttl 0

# List all users, table format
./k8s-get-config.sh --list

# List as JSON for further processing
./k8s-get-config.sh --list --json | jq '.[] | select(.ttl == "short-lived")'

# Delete user (SA, bindings, secret, local kubeconfig)
./k8s-get-config.sh --delete --user alice
```

### `--list` output

Default (table):

```
USER                  ROLE        NS            TTL           EXPIRES                  REMAINING     NOTE
----------------------------------------------------------------------------------------------------------------
alice                 admin       kube-users    short-lived   2026-04-30 20:30:58 UTC  in 1d0h       from kubeconfig
bob                   readonly    kube-users    never         -                        -             from kubeconfig
carol                 admin       kube-system   never         -                        -             long-lived secret [legacy]
ghost                 admin       kube-users    short-lived   unknown                  unknown       kubeconfig not found
```

JSON (`--list --json`):

```json
[
  {
    "user": "alice",
    "role": "admin",
    "namespace": "kube-users",
    "ttl": "short-lived",
    "expires": "2026-04-30 20:30:58 UTC",
    "expires_unix": 1777581058,
    "remaining": "in 1d0h",
    "note": "from kubeconfig",
    "legacy": false
  }
]
```

#### How TTL/expiry is resolved

The script cannot read short-lived tokens back from the cluster (they are not stored anywhere — `kubectl create token` returns the JWT once). To still show meaningful TTL info, `--list` uses this resolution order per user:

1. Look for a local kubeconfig file `./<user>-kubeconfig` in the current directory. If found, parse the JWT, decode the `exp` claim, and report the actual expiry.
2. If no local kubeconfig: check whether a long-lived Secret `<user>-token` exists in the user's namespace. If yes, report TTL as `never`.
3. Otherwise: report TTL as `short-lived` and expiry as `unknown` (the token was issued but not stored locally and not via long-lived Secret).

**Implication**: run `--list` from the directory where kubeconfigs live to get accurate expiry data for short-lived tokens.

The `[legacy]` tag indicates a user that still resides in `kube-system` from older installations. New users are always created in `kube-users`.

## Configuration

| Variable           | Default      | Purpose                                  |
| ------------------ | ------------ | ---------------------------------------- |
| `K8S_USERS_NS`     | `kube-users` | Namespace for new ServiceAccounts        |

The legacy namespace `kube-system` is hardcoded for backward compatibility and not configurable.

## Architecture notes

### Why a dedicated namespace?

Mixing user ServiceAccounts with control-plane components in `kube-system` is an anti-pattern:

- **Security**: any controller with `get/list secrets -n kube-system` sees user tokens. Pod Security Standards in `kube-system` are typically permissive.
- **Auditing**: user-driven actions are mixed with system actions in audit logs.
- **Operations**: bulk operations during cluster upgrades may inadvertently touch user resources.
- **RBAC delegation**: granting "user management" rights cleanly is impossible if it requires `kube-system` access (effectively cluster-root).

The `kube-users` namespace isolates user accounts and is created on demand.

### Token strategy

- **Short-lived** (`--ttl <duration>`): uses `kubectl create token`. Bound to the SA, expires automatically. Recommended for CI/CD and time-bounded access.
- **Long-lived** (`--ttl 0` or omitted): creates a `Secret` of type `kubernetes.io/service-account-token` with the `kubernetes.io/service-account.name` annotation. Kubernetes populates `.data.token` automatically. Token does not expire while the Secret exists.

The script detects when the API server truncates a requested TTL (via `--service-account-max-token-expiration`) by parsing the JWT `exp` claim and comparing against the requested duration.

### Idempotency

- ClusterRoleBindings are created via `kubectl apply` — re-running `--mkconfig` or repeating `--create` (after `--delete`) does not error on existing bindings.
- The `nodes-viewer` ClusterRole is created only if absent.
- `--delete` uses `--ignore-not-found` for all resources.

### What `--create` does

1. Ensures namespace `kube-users` exists.
2. Refuses if a SA with the same name exists in `kube-users` or `kube-system`.
3. Creates `ServiceAccount/<user>` in `kube-users`.
4. Creates ClusterRoleBindings:
   - `admin` → `<user>-binding` → `cluster-admin`
   - `readonly` → `<user>-binding-view` → `view`, `<user>-binding-nodes` → `nodes-viewer`
5. Issues token (long-lived Secret or short-lived via `kubectl create token`).
6. Writes `<user>-kubeconfig` (mode 600) in CWD.

### What `--delete` does

1. Locates the user in `kube-users` or `kube-system`.
2. Deletes ClusterRoleBindings: `<user>-binding`, `<user>-binding-view`, `<user>-binding-nodes`.
3. Deletes Secret `<user>-token` (if present).
4. Deletes ServiceAccount.
5. Removes local `<user>-kubeconfig`.

## Limitations

- Tokens issued via `kubectl create token` are **not** stored anywhere on the cluster. Once the kubeconfig is lost, the only recovery is to issue a new token via `--mkconfig --ttl <duration>`.
- The script writes kubeconfigs to CWD. Run it from a directory where you intend to keep the files (or move them after creation).
- Cluster CA is read from the **current kubectl context**. The generated kubeconfig will work only against the same cluster.
- `--list` requires read access to `clusterrolebindings` and (for long-lived secret detection) `secrets` in `kube-users` and `kube-system`.

## Author

z200801@gmail.com — original concept and v1.0.
v2.x: refactor with Claude (Anthropic).
