# k8s-get-config

A Bash utility for managing Kubernetes user access via ServiceAccounts and RBAC, with kubeconfig generation. Supports cluster-scoped and namespace-scoped roles, custom ClusterRoles, and token rotation. Tested on Kubernetes 1.34+.

## Features

- Cluster-scoped roles: `admin` (cluster-admin) and `readonly` (view + nodes-viewer).
- Namespace-scoped roles: `editor` (edit) and `view`.
- Custom ClusterRoles via `--cluster-role` (cluster-wide or namespace-scoped).
- Token rotation via `--update --ttl`.
- Adding namespace access to existing users via `--update --role ... --namespace ...`.
- Partial revocation: `--delete --user X --namespace Y` removes only namespace access.
- Listing with TTL/expiry and scope information, in human table or JSON.
- Backward compatibility: detects users in `kube-system` (legacy installations).
- Centralized SA storage in dedicated namespace (default: `kube-users`, autocreated).

## Requirements

- `kubectl` configured against the target cluster with admin permissions (must be able to create ServiceAccounts, ClusterRoleBindings, RoleBindings, Secrets, Namespaces).
- `jq`
- `base64` (GNU coreutils)
- Kubernetes cluster, recommended 1.24+; tested on 1.34+.

## Installation

```bash
chmod +x k8s-get-config.sh
./k8s-get-config.sh --help
```

## Commands

```
--create   --user <name> [role-spec] [--ttl <duration>]
--update   --user <name> [role-spec] [--ttl <duration>]
--delete   --user <name> [--namespace <ns>]
--mkconfig --user <name>
--rotate   (--user <name> | --all) [--ttl <duration>] [--yes]
--list     [--json]
```

### Role specifications

**Cluster-scope** (no `--namespace`):

| Flag                       | Effect                                             |
| -------------------------- | -------------------------------------------------- |
| `--role admin`             | ClusterRoleBinding to `cluster-admin`              |
| `--role readonly`          | ClusterRoleBindings to `view` + `nodes-viewer`     |
| `--cluster-role <name>`    | ClusterRoleBinding to existing custom ClusterRole  |

**Namespace-scope** (requires `--namespace <ns>`):

| Flag                                       | Effect                                        |
| ------------------------------------------ | --------------------------------------------- |
| `--role editor --namespace NS`             | RoleBinding to `edit` ClusterRole, in NS      |
| `--role view --namespace NS`               | RoleBinding to `view` ClusterRole, in NS      |
| `--cluster-role <name> --namespace NS`     | RoleBinding to custom ClusterRole, in NS      |

`--role` and `--cluster-role` are mutually exclusive. `--cluster-role` requires the named ClusterRole to already exist (verified before binding).

The `nodes-viewer` ClusterRole is custom and created automatically on the first `readonly` user.

### TTL

| `--ttl` value         | Behavior                                                     |
| --------------------- | ------------------------------------------------------------ |
| not provided          | Long-lived token (manual Secret with `kubernetes.io/service-account-token`) |
| `0`                   | Long-lived token                                             |
| Go duration (`24h`, `30m`, `2h30m`, `7d`, `3600s`) | Short-lived token via `kubectl create token --duration` |

Short-lived TTLs are bounded by the API server's `--service-account-max-token-expiration` flag (default ~24h on most clusters). If the API server truncates a requested TTL, the script prints a warning showing the actual expiry.

To raise the limit, set on the kube-apiserver:

```
--service-account-max-token-expiration=720h
```

### `--create`

Creates a new user. Fails if the user already exists in `kube-users` or `kube-system`.

```bash
# Cluster admin, long-lived token
./k8s-get-config.sh --create --user alice --role admin

# Cluster readonly, 24h short-lived
./k8s-get-config.sh --create --user audit --role readonly --ttl 24h

# Namespace editor, long-lived token
./k8s-get-config.sh --create --user dev1 --role editor --namespace myapp

# Namespace view, 8h short-lived
./k8s-get-config.sh --create --user observer --role view --namespace staging --ttl 8h

# Custom ClusterRole, cluster-wide
./k8s-get-config.sh --create --user audit --cluster-role my-auditor

# Custom ClusterRole, scoped to one namespace
./k8s-get-config.sh --create --user prodaudit --cluster-role prod-auditor --namespace prod
```

### `--update`

Modifies an existing user. At least one of `--ttl`, `--role`/`--cluster-role` (with `--namespace`) must be specified.

```bash
# Rotate token to 8h short-lived
./k8s-get-config.sh --update --user alice --ttl 8h

# Switch to long-lived (creates Secret if needed)
./k8s-get-config.sh --update --user alice --ttl 0

# Add namespace access (no token rotation)
./k8s-get-config.sh --update --user dev1 --role view --namespace staging

# Add namespace access AND rotate token
./k8s-get-config.sh --update --user dev1 --role editor --namespace anotherapp --ttl 24h

# Add custom ClusterRole binding in a namespace
./k8s-get-config.sh --update --user audit --cluster-role auditor --namespace finance
```

**Behavior rules:**

- **TTL switch closes security gaps**: if a user has a long-lived Secret and `--update --ttl <dur>` requests a short-lived token, the old Secret is **deleted** before the new short-lived token is issued. Otherwise the old credential remains valid in parallel — a security gap.
- **Role replacement in same namespace** (rule b): if a user already has `view` in `myapp` and you run `--update --role editor --namespace myapp`, the existing RoleBinding is replaced with the new one. Single RoleBinding per (user, namespace) is enforced.
- **Duplicate add** (rule c): if the exact same RoleBinding already exists, the script prints a warning and makes no changes. Idempotent.
- **Cluster-scope role changes are not allowed via `--update`**. To change a cluster-scope role, use `--delete` + `--create`. This avoids ambiguity (admin↔readonly is a fundamentally different setup).

### `--delete`

```bash
# Full delete: SA, all bindings (cluster + ns), Secret, kubeconfig
./k8s-get-config.sh --delete --user alice

# Partial: revoke only RoleBindings in a specific namespace
# SA, other ns access, cluster bindings, and kubeconfig are preserved
./k8s-get-config.sh --delete --user dev1 --namespace myapp
```

### `--mkconfig`

Regenerates the kubeconfig file from an existing long-lived Secret. Does **not** issue new tokens. To rotate the token, use `--update --ttl <dur>`.

```bash
./k8s-get-config.sh --mkconfig --user alice
```

If the user has no long-lived Secret (was created with a short-lived TTL), `--mkconfig` fails with a hint to use `--update`.

### `--rotate`

Rotates tokens. Useful for periodic credential refresh, especially for long-lived Secrets that should be cycled as a hygiene practice.

```bash
# Rotate one user; auto-detect TTL from local kubeconfig (or default 24h if missing)
./k8s-get-config.sh --rotate --user alice

# Rotate one user with explicit new TTL (also closes long->short security gap)
./k8s-get-config.sh --rotate --user alice --ttl 1h

# Rotate all users in kube-users (with confirmation prompt)
./k8s-get-config.sh --rotate --all

# Rotate all without prompt (CI/automation)
./k8s-get-config.sh --rotate --all --yes

# Rotate all and force a specific TTL on everyone
./k8s-get-config.sh --rotate --all --ttl 24h --yes
```

**Behavior:**

- **Long-lived users**: the existing Secret is **deleted and recreated**. The old token is invalidated immediately. Any existing kubeconfig copies become unusable until a new one is distributed.
- **Short-lived users**: a new short-lived token is issued. The previously issued token (if still valid) **remains valid until its original expiry** — short-lived tokens cannot be revoked from the cluster side without recreating the SA. Acceptable because TTLs are short by design.
- **TTL auto-detection** (without explicit `--ttl`): the script reads the local `./<user>-kubeconfig`, decodes the JWT, and computes original TTL as `exp - iat`. If the kubeconfig is missing and no long-lived Secret exists, falls back to default `24h` with a warning.
- **`--all` skips legacy users** in `kube-system`. Rotate them individually with `--rotate --user <name>` if needed.
- **Failures in `--all`** do not stop the run. At the end the script reports a list of users that failed and exits with code 1.
- **Progress output** is shown as `[N/total] rotating <user>...` for `--all`.

**Confirmation:** `--rotate --all` prompts before proceeding. Use `--yes` (or `-y`) to skip the prompt for non-interactive use.

### `--list`

Default output:

```
USER                  ROLE                SCOPE                    TTL           EXPIRES                  REMAINING     NOTE
------------------------------------------------------------------------------------------------------------------------------------
alice                 admin               cluster                  short-lived   2026-04-30 21:00:09 UTC  in 1d0h       from kubeconfig
audit                 custom:my-auditor   cluster                  never         -                        -             long-lived secret
bob                   readonly            cluster                  never         -                        -             from kubeconfig
carol                 admin               cluster                  never         -                        -             long-lived secret [legacy]
dev1                  editor              ns:myapp                 short-lived   2026-04-30 04:00:09 UTC  in 7h59m      from kubeconfig
dev1                  view                ns:staging               short-lived   2026-04-30 04:00:09 UTC  in 7h59m      from kubeconfig
dev2                  view                ns:myapp,staging         never         -                        -             long-lived secret
prodaudit             custom:prod-auditor ns:prod                  never         -                        -             long-lived secret
```

JSON output (`--json`):

```json
[
  {
    "user": "alice",
    "role": "admin",
    "sa_namespace": "kube-users",
    "scope": "cluster",
    "namespaces": [],
    "ttl": "short-lived",
    "expires": "2026-04-30 21:00:09 UTC",
    "expires_unix": 1777582809,
    "remaining": "in 1d0h",
    "note": "from kubeconfig",
    "legacy": false
  },
  {
    "user": "dev1",
    "role": "editor",
    "sa_namespace": "kube-users",
    "scope": "namespace",
    "namespaces": ["myapp"],
    "ttl": "short-lived",
    "expires": "...",
    ...
  }
]
```

#### How `--list` works

A single user can have multiple bindings:
- Cluster-scope (one row per user with cluster bindings).
- Namespace-scope (one row per (user, role) tuple; same role across multiple namespaces is collapsed into a comma-separated list).

A user with both cluster and namespace bindings appears in multiple rows.

#### TTL/expiry resolution

Short-lived tokens (`kubectl create token`) are **not stored** anywhere on the cluster — they exist only in the kubeconfig given to the user. To still show meaningful expiry info, `--list` resolves per user:

1. Read local kubeconfig `./<user>-kubeconfig` if present, decode JWT, extract `exp` claim.
2. Otherwise, check for long-lived Secret `<user>-token` in user's namespace → report TTL as `never`.
3. Otherwise, report `short-lived` with `unknown` expiry.

Run `--list` from the directory holding the kubeconfigs for accurate short-lived expiry data.

## Configuration

| Variable           | Default      | Purpose                                  |
| ------------------ | ------------ | ---------------------------------------- |
| `K8S_USERS_NS`     | `kube-users` | Namespace for user ServiceAccounts       |

The legacy namespace `kube-system` is hardcoded for backward compatibility (read-only fallback for `--list` and `--delete`).

## Architecture notes

### Resource layout

- **ServiceAccount** — always in `kube-users` (centralized).
- **ClusterRoleBinding** — for cluster-scope access. Subject references the SA in `kube-users`.
- **RoleBinding** — in the target namespace. Subject references the SA in `kube-users` (cross-namespace SA reference is supported by Kubernetes).
- **Long-lived Secret** — in `kube-users` (paired with the SA).

### Naming convention

| Resource                              | Pattern                                     |
| ------------------------------------- | ------------------------------------------- |
| ClusterRoleBinding `admin`            | `<user>-binding`                            |
| ClusterRoleBinding `readonly` (view)  | `<user>-binding-view`                       |
| ClusterRoleBinding `readonly` (nodes) | `<user>-binding-nodes`                      |
| ClusterRoleBinding custom             | `<user>-binding-custom-<clusterrole>`       |
| RoleBinding `editor`                  | `<user>-rb-edit` (in target ns)             |
| RoleBinding `view`                    | `<user>-rb-view` (in target ns)             |
| RoleBinding custom                    | `<user>-rb-custom-<clusterrole>`            |
| Long-lived Secret                     | `<user>-token` (in `kube-users`)            |

Names exceeding the DNS-1123 limit (63 chars) cause an explicit error rather than silent truncation.

### Token strategy

- **Short-lived** (`--ttl <duration>`): `kubectl create token`. Bound to the SA, expires automatically. Recommended for CI/CD and time-bounded access.
- **Long-lived** (`--ttl 0` or omitted): `Secret` of type `kubernetes.io/service-account-token` with annotation `kubernetes.io/service-account.name`. Kubernetes populates `.data.token` automatically. Token does not expire while the Secret exists.

The script detects API-server-side TTL truncation (`--service-account-max-token-expiration`) by parsing the JWT `exp` claim and warning if the actual TTL is significantly shorter than requested.

### Idempotency and safety

- Bindings are created via `kubectl apply`; re-running the same command does not error.
- Built-in `nodes-viewer` ClusterRole is created only if absent.
- `--delete` uses `--ignore-not-found` everywhere.
- `--update --ttl` switching from long-lived to short-lived **deletes the old Secret** to prevent parallel valid credentials.
- Same-namespace role raise (e.g. `view` → `editor`) **replaces** the existing RoleBinding rather than adding a second one.
- Same-namespace duplicate (`view` → `view`) is a no-op with warning.

## Limitations

- Short-lived tokens are not recoverable from the cluster. If a kubeconfig is lost, issue a new token via `--update --ttl <dur>`.
- Kubeconfigs are written to CWD. Run the script from the directory you intend to keep them in.
- CA is read from the current kubectl context; generated kubeconfigs work only against that cluster.
- Multiple namespaces in a single command (e.g. `--namespace a,b,c`) are not supported. Run `--update` repeatedly, or use a custom ClusterRole that already covers the desired scope.
- Cluster-scope role changes (admin ↔ readonly) require `--delete` + `--create`. `--update` only handles namespace-scope role additions and TTL changes.

## Author

z200801@gmail.com — original concept and v1.0.
v2.x–3.x: refactor with Claude (Anthropic).
