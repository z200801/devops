# k8s-get-config

Bash-утиліта для керування доступом користувачів до Kubernetes через ServiceAccount-и та RBAC, з генерацією kubeconfig. Підтримує cluster-scoped і namespace-scoped ролі, кастомні ClusterRole-и та ротацію токенів. Протестовано на Kubernetes 1.34+.

## Можливості

- Cluster-scoped ролі: `admin` (cluster-admin) і `readonly` (view + nodes-viewer).
- Namespace-scoped ролі: `editor` (edit) і `view`.
- Кастомні ClusterRole-и через `--cluster-role` (cluster-wide або в конкретному ns).
- Ротація токенів через `--update --ttl`.
- Додавання доступу до ns існуючому юзеру через `--update --role ... --namespace ...`.
- Часткове відкликання: `--delete --user X --namespace Y` видаляє тільки доступ до ns.
- Перегляд списку з інформацією про TTL/expire та scope, у вигляді таблиці або JSON.
- Зворотна сумісність: виявлення legacy-юзерів у `kube-system`.
- Централізоване зберігання SA в окремому namespace (за замовчуванням: `kube-users`, створюється автоматично).

## Вимоги

- `kubectl` з правами адміністратора на цільовий кластер (можливість створювати ServiceAccount-и, ClusterRoleBinding-и, RoleBinding-и, Secret-и, Namespace-и).
- `jq`
- `base64` (GNU coreutils)
- Kubernetes-кластер, рекомендована версія 1.24+; протестовано на 1.34+.

## Встановлення

```bash
chmod +x k8s-get-config.sh
./k8s-get-config.sh --help
```

## Команди

```
--create   --user <name> [role-spec] [--ttl <duration>]
--update   --user <name> [role-spec] [--ttl <duration>]
--delete   --user <name> [--namespace <ns>]
--mkconfig --user <name>
--rotate   (--user <name> | --all) [--ttl <duration>] [--yes]
--list     [--json]
```

### Специфікації ролей

**Cluster-scope** (без `--namespace`):

| Прапорець                  | Ефект                                                |
| -------------------------- | ---------------------------------------------------- |
| `--role admin`             | ClusterRoleBinding на `cluster-admin`                |
| `--role readonly`          | ClusterRoleBinding-и на `view` + `nodes-viewer`      |
| `--cluster-role <name>`    | ClusterRoleBinding на існуючий кастомний ClusterRole |

**Namespace-scope** (потребує `--namespace <ns>`):

| Прапорець                                  | Ефект                                            |
| ------------------------------------------ | ------------------------------------------------ |
| `--role editor --namespace NS`             | RoleBinding на ClusterRole `edit`, у NS          |
| `--role view --namespace NS`               | RoleBinding на ClusterRole `view`, у NS          |
| `--cluster-role <name> --namespace NS`     | RoleBinding на кастомний ClusterRole, у NS       |

`--role` і `--cluster-role` взаємовиключні. `--cluster-role` потребує, щоб вказаний ClusterRole **уже існував** (перевіряється перед створенням binding-а).

ClusterRole `nodes-viewer` — кастомний і створюється автоматично при першому юзері з `readonly`.

### TTL

| Значення `--ttl`        | Поведінка                                                     |
| ----------------------- | ------------------------------------------------------------- |
| не вказано              | Довгоживучий токен (manual Secret з `kubernetes.io/service-account-token`) |
| `0`                     | Довгоживучий токен                                            |
| Go duration (`24h`, `30m`, `2h30m`, `7d`, `3600s`) | Короткоживучий через `kubectl create token --duration` |

Короткі TTL обмежені прапорцем `--service-account-max-token-expiration` API-сервера (за замовчуванням ~24h на більшості кластерів). Якщо API-сервер обріже запитуваний TTL, скрипт видасть попередження з реальним часом expire.

Щоб підняти ліміт, налаштуй на kube-apiserver:

```
--service-account-max-token-expiration=720h
```

### `--create`

Створює нового юзера. Падає, якщо юзер уже існує в `kube-users` або `kube-system`.

```bash
# Cluster admin, довгоживучий токен
./k8s-get-config.sh --create --user alice --role admin

# Cluster readonly, 24-годинний короткий
./k8s-get-config.sh --create --user audit --role readonly --ttl 24h

# Namespace editor, довгоживучий
./k8s-get-config.sh --create --user dev1 --role editor --namespace myapp

# Namespace view, 8-годинний короткий
./k8s-get-config.sh --create --user observer --role view --namespace staging --ttl 8h

# Кастомний ClusterRole, cluster-wide
./k8s-get-config.sh --create --user audit --cluster-role my-auditor

# Кастомний ClusterRole, scoped до одного ns
./k8s-get-config.sh --create --user prodaudit --cluster-role prod-auditor --namespace prod
```

### `--update`

Модифікує існуючого юзера. Має бути вказано хоча б одне з: `--ttl`, `--role`/`--cluster-role` (з `--namespace`).

```bash
# Ротувати токен на 8h short-lived
./k8s-get-config.sh --update --user alice --ttl 8h

# Перевести на long-lived (створить Secret якщо потрібно)
./k8s-get-config.sh --update --user alice --ttl 0

# Додати ns-доступ (без ротації токена)
./k8s-get-config.sh --update --user dev1 --role view --namespace staging

# Додати ns-доступ І ротувати токен
./k8s-get-config.sh --update --user dev1 --role editor --namespace anotherapp --ttl 24h

# Додати кастомний ClusterRole binding у ns
./k8s-get-config.sh --update --user audit --cluster-role auditor --namespace finance
```

**Правила поведінки:**

- **TTL switch закриває діри безпеки**: якщо у юзера є long-lived Secret і викликається `--update --ttl <dur>` для short-lived, **старий Secret видаляється** перед видачею нового короткого токена. Інакше старий credential лишався б валідним паралельно — це діра.
- **Заміна ролі в тому ж ns** (правило b): якщо юзер уже має `view` у `myapp` і викликати `--update --role editor --namespace myapp`, існуючий RoleBinding **замінюється** на новий. Гарантовано один RoleBinding на (юзер, ns).
- **Дублікат** (правило c): якщо точно такий самий RoleBinding уже існує — скрипт видасть warning і нічого не змінить. Idempotent.
- **Зміна cluster-scope ролі через `--update` не дозволена**. Для зміни cluster-scope ролі (admin ↔ readonly) використовуй `--delete` + `--create`. Це зроблено навмисно, щоб уникнути неоднозначності.

### `--delete`

```bash
# Повне видалення: SA, всі binding-и (cluster + ns), Secret, kubeconfig
./k8s-get-config.sh --delete --user alice

# Часткове: відкликати тільки RoleBinding-и у конкретному ns
# SA, інші ns-доступи, cluster binding-и і kubeconfig зберігаються
./k8s-get-config.sh --delete --user dev1 --namespace myapp
```

### `--mkconfig`

Перегенеровує kubeconfig з існуючого long-lived Secret. **Не видає** нових токенів. Для ротації використовуй `--update --ttl <dur>`.

```bash
./k8s-get-config.sh --mkconfig --user alice
```

Якщо у юзера нема long-lived Secret (створений з коротким TTL) — `--mkconfig` падає з підказкою використати `--update`.

### `--rotate`

Ротує токени. Корисно для періодичного оновлення credential-ів, особливо для long-lived Secret-ів, які варто циклічно ротувати з міркувань безпеки.

```bash
# Ротація одного юзера; TTL автоматично з локального kubeconfig (або 24h дефолт якщо нема)
./k8s-get-config.sh --rotate --user alice

# Ротація з явним новим TTL (також закриває дірку при переході long->short)
./k8s-get-config.sh --rotate --user alice --ttl 1h

# Ротація всіх юзерів у kube-users (з підтвердженням)
./k8s-get-config.sh --rotate --all

# Ротація всіх без підтвердження (для CI/автоматизації)
./k8s-get-config.sh --rotate --all --yes

# Ротація всіх з примусовим TTL для всіх
./k8s-get-config.sh --rotate --all --ttl 24h --yes
```

**Поведінка:**

- **Long-lived юзери**: існуючий Secret **видаляється і створюється заново**. Старий токен інвалідується миттєво. Будь-які існуючі копії kubeconfig стають непридатними до видачі нової.
- **Short-lived юзери**: видається новий short-lived токен. Раніше виданий токен (якщо ще валідний) **лишається валідним до свого оригінального expire** — короткі токени неможливо відкликати з боку кластера без перестворення SA. Прийнятно, бо TTL і так короткий.
- **Авто-визначення TTL** (без явного `--ttl`): скрипт читає локальний `./<user>-kubeconfig`, декодує JWT і обчислює оригінальний TTL як `exp - iat`. Якщо kubeconfig відсутній і long-lived Secret теж нема — fallback на дефолт `24h` з warning.
- **`--all` пропускає legacy-юзерів** з `kube-system`. Для їх ротації — `--rotate --user <name>` індивідуально.
- **Помилки у `--all`** не зупиняють виконання. У кінці скрипт виводить список юзерів, для яких ротація провалилась, і виходить з кодом 1.
- **Прогрес** показується як `[N/total] rotating <user>...` для `--all`.

**Підтвердження:** `--rotate --all` запитує підтвердження перед виконанням. Використовуй `--yes` (або `-y`) щоб пропустити prompt у non-interactive режимі.

### `--list`

```bash
./k8s-get-config.sh --list
./k8s-get-config.sh --list --json
```

Стандартний вивід:

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

JSON-вивід (`--json`):

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

#### Як працює `--list`

Один юзер може мати декілька binding-ів:
- Cluster-scope (один рядок на юзера з cluster binding-ами).
- Namespace-scope (один рядок на (юзера, роль); та сама роль у декількох ns згортається у список через кому).

Юзер з cluster-доступом і ns-доступом одночасно з'являється у декількох рядках.

#### Як визначається TTL/expire

Короткоживучі токени (`kubectl create token`) **не зберігаються** ніде в кластері — вони існують лише у kubeconfig, виданому юзеру. Щоб все одно показувати корисну інформацію, `--list` для кожного юзера:

1. Читає локальний kubeconfig `./<user>-kubeconfig`, якщо є; декодує JWT, дістає claim `exp`.
2. Інакше — перевіряє наявність long-lived Secret `<user>-token` у ns юзера → виводить TTL як `never`.
3. Інакше — виводить `short-lived` з `unknown` expire.

Запускай `--list` з директорії, де лежать kubeconfig-и, для точних даних про expire коротких токенів.

## Конфігурація

| Змінна             | За замовчуванням | Призначення                              |
| ------------------ | ---------------- | ---------------------------------------- |
| `K8S_USERS_NS`     | `kube-users`     | Namespace для SA користувачів            |

Legacy namespace `kube-system` захардкоджений для зворотної сумісності (read-only fallback для `--list` і `--delete`).

## Архітектурні нотатки

### Розташування ресурсів

- **ServiceAccount** — завжди в `kube-users` (централізовано).
- **ClusterRoleBinding** — для cluster-scope доступу. Subject посилається на SA в `kube-users`.
- **RoleBinding** — у цільовому ns. Subject посилається на SA в `kube-users` (cross-namespace посилання на SA підтримується Kubernetes).
- **Long-lived Secret** — у `kube-users` (поруч з SA).

### Конвенція іменування

| Ресурс                                | Шаблон                                      |
| ------------------------------------- | ------------------------------------------- |
| ClusterRoleBinding `admin`            | `<user>-binding`                            |
| ClusterRoleBinding `readonly` (view)  | `<user>-binding-view`                       |
| ClusterRoleBinding `readonly` (nodes) | `<user>-binding-nodes`                      |
| ClusterRoleBinding custom             | `<user>-binding-custom-<clusterrole>`       |
| RoleBinding `editor`                  | `<user>-rb-edit` (у цільовому ns)           |
| RoleBinding `view`                    | `<user>-rb-view` (у цільовому ns)           |
| RoleBinding custom                    | `<user>-rb-custom-<clusterrole>`            |
| Long-lived Secret                     | `<user>-token` (у `kube-users`)             |

Імена, що перевищують ліміт DNS-1123 (63 символи), викликають явну помилку — без silent truncation.

### Стратегія токенів

- **Короткоживучі** (`--ttl <duration>`): `kubectl create token`. Прив'язані до SA, expire автоматично. Рекомендовано для CI/CD і доступу з обмеженим часом.
- **Довгоживучі** (`--ttl 0` або без `--ttl`): `Secret` типу `kubernetes.io/service-account-token` з анотацією `kubernetes.io/service-account.name`. Kubernetes автоматично заповнює `.data.token`. Токен не expire доки Secret існує.

Скрипт виявляє ситуацію, коли API-сервер обрізає TTL (через `--service-account-max-token-expiration`), парсячи `exp` із JWT і порівнюючи з запитаним duration.

### Ідемпотентність і безпека

- Binding-и створюються через `kubectl apply` — повторний запуск не падає.
- Вбудований `nodes-viewer` ClusterRole створюється тільки якщо його ще нема.
- `--delete` всюди використовує `--ignore-not-found`.
- `--update --ttl` при переході long-lived → short-lived **видаляє старий Secret**, щоб не лишилось паралельних валідних credential-ів.
- Підняття ролі в тому самому ns (`view` → `editor`) **замінює** існуючий RoleBinding, а не додає другий.
- Дублікат у тому самому ns (`view` → `view`) — no-op з warning.

## Обмеження

- Короткоживучі токени не можна "відновити" з кластера. Якщо kubeconfig втрачено — видавай новий через `--update --ttl <dur>`.
- Kubeconfig-и пишуться у CWD. Запускай з директорії, де ти плануєш їх зберігати.
- CA читається з поточного kubectl-контексту; згенеровані kubeconfig-и працюватимуть тільки з тим самим кластером.
- Множинні namespace-и в одній команді (`--namespace a,b,c`) не підтримуються. Викликай `--update` повторно або використовуй кастомний ClusterRole, який уже покриває потрібний scope.
- Зміни cluster-scope ролей (admin ↔ readonly) потребують `--delete` + `--create`. `--update` обробляє тільки додавання ns-scope ролей і зміни TTL.

## Автор

z200801@gmail.com — оригінальна концепція і v1.0.
v2.x–3.x: рефакторинг із Claude (Anthropic).
