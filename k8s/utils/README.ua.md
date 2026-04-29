# k8s-get-config

Bash-утиліта для керування доступом користувачів до Kubernetes через ServiceAccount-и та RBAC, з генерацією kubeconfig. Протестовано на Kubernetes 1.34+.

## Можливості

- Створення користувачів з ролями `admin` (cluster-admin) або `readonly` (view + nodes-viewer).
- Видача короткоживучих токенів через `kubectl create token` з налаштовуваним TTL.
- Видача довгоживучих токенів через manual Secret з анотацією `kubernetes.io/service-account.name`.
- Генерація готових до використання kubeconfig-файлів (`<user>-kubeconfig`) у поточній директорії.
- Перегляд списку користувачів з інформацією про TTL та час дії, у вигляді таблиці або JSON.
- Зворотна сумісність: виявлення користувачів у `kube-system` (legacy-інсталяції) для команд `--list` та `--delete`.
- Використання окремого namespace для користувачів (за замовчуванням: `kube-users`, створюється автоматично).

## Вимоги

- `kubectl`, налаштований на цільовий кластер з правами адміністратора (можливість створювати ServiceAccount-и, ClusterRoleBinding-и, Secret-и та Namespace-и).
- `jq`
- `base64` (GNU coreutils)
- Кластер Kubernetes, рекомендована версія 1.24+; протестовано на 1.34+.

## Встановлення

```bash
chmod +x k8s-get-config.sh
./k8s-get-config.sh --help
```

## Використання

```
Usage: ./k8s-get-config.sh [OPTIONS]

Options:
  --create   --user <name> --role <admin|readonly> [--ttl <duration>]
  --delete   --user <name>
  --mkconfig --user <name> [--ttl <duration>]
  --list [--json]
```

### Ролі

| Роль       | Прив'язки                                       |
| ---------- | ----------------------------------------------- |
| `admin`    | ClusterRole `cluster-admin`                     |
| `readonly` | ClusterRole `view` + кастомний `nodes-viewer` (get/list/watch для `nodes`) |

Кастомний ClusterRole `nodes-viewer` створюється автоматично під час першого створення користувача з роллю `readonly`.

### TTL

Прапорець `--ttl` контролює час життя токена:

| Значення `--ttl`       | Поведінка                                                    |
| ---------------------- | ------------------------------------------------------------ |
| не вказано             | Довгоживучий токен (manual Secret)                           |
| `0`                    | Довгоживучий токен (manual Secret)                           |
| Go duration (`24h`, `30m`, `2h30m`, `7d`, `3600s`) | Короткоживучий токен через `kubectl create token --duration` |

**Важливо**: короткі TTL обмежуються прапорцем `--service-account-max-token-expiration` API-сервера (за замовчуванням ~24h на більшості кластерів). Якщо API-сервер обріже запитуваний TTL, скрипт видасть попередження з реальним часом expire.

Щоб підняти ліміт, налаштуй на kube-apiserver:

```
--service-account-max-token-expiration=720h
```

Довгоживучі токени через manual Secret не мають часу expire. Технічно підтримуються в Kubernetes 1.34, але офіційна документація вважає їх legacy. Підходять для довірених довготривалих CI/CD-пайплайнів та адміністративного інструментарію, але **варто ротувати їх вручну** як гігієнічну практику.

### Приклади

```bash
# Довгоживучий admin-токен (поведінка за замовчуванням)
./k8s-get-config.sh --create --user alice --role admin

# Довгоживучий readonly-токен (явно)
./k8s-get-config.sh --create --user observer --role readonly --ttl 0

# Короткоживучий (24 години) admin-токен для CI
./k8s-get-config.sh --create --user ci-deploy --role admin --ttl 24h

# Короткоживучий (30 днів) readonly-токен
./k8s-get-config.sh --create --user audit --role readonly --ttl 720h

# Перегенерувати kubeconfig, використовуючи існуючий long-lived Secret
./k8s-get-config.sh --mkconfig --user alice

# Видати свіжий 8-годинний токен, перезаписати kubeconfig
./k8s-get-config.sh --mkconfig --user observer --ttl 8h

# Замінити існуючий токен на новий довгоживучий
./k8s-get-config.sh --mkconfig --user alice --ttl 0

# Список усіх користувачів, табличний формат
./k8s-get-config.sh --list

# Список у JSON для подальшої обробки
./k8s-get-config.sh --list --json | jq '.[] | select(.ttl == "short-lived")'

# Видалити користувача (SA, прив'язки, secret, локальний kubeconfig)
./k8s-get-config.sh --delete --user alice
```

### Вивід `--list`

За замовчуванням (таблиця):

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

#### Як визначається TTL/expire

Скрипт **не може** прочитати короткоживучі токени з кластера — їх ніде не зберігають (`kubectl create token` повертає JWT один раз). Щоб все одно показувати корисну інформацію, `--list` використовує таку послідовність для кожного користувача:

1. Шукає локальний kubeconfig-файл `./<user>-kubeconfig` у поточній директорії. Якщо знайшов — парсить JWT, декодує claim `exp` і виводить реальний час expire.
2. Якщо локального kubeconfig нема — перевіряє наявність довгоживучого Secret `<user>-token` у namespace користувача. Якщо є — виводить TTL як `never`.
3. Інакше — TTL `short-lived`, expire `unknown` (токен був виданий, але не збережений локально і не у вигляді long-lived Secret).

**Наслідок**: запускай `--list` з директорії, де лежать kubeconfig-и, щоб отримати точні дані про expire короткоживучих токенів.

Тег `[legacy]` означає користувача, який лишився в `kube-system` зі старіших інсталяцій. Нові користувачі завжди створюються в `kube-users`.

## Конфігурація

| Змінна             | За замовчуванням | Призначення                              |
| ------------------ | ---------------- | ---------------------------------------- |
| `K8S_USERS_NS`     | `kube-users`     | Namespace для нових ServiceAccount-ів    |

Legacy namespace `kube-system` захардкоджений для зворотної сумісності і не налаштовується.

## Архітектурні нотатки

### Чому окремий namespace?

Змішування користувацьких ServiceAccount-ів з компонентами control plane у `kube-system` — anti-pattern:

- **Безпека**: будь-який контролер з правом `get/list secrets -n kube-system` бачить токени користувачів. Pod Security Standards у `kube-system` зазвичай послаблені.
- **Аудит**: дії користувачів змішуються з системними у audit-логах.
- **Експлуатація**: масові операції під час оновлення кластера можуть випадково зачепити користувацькі ресурси.
- **Делегування RBAC**: дати комусь права на "керування користувачами" чисто неможливо, якщо це вимагає доступу до `kube-system` (фактично root на кластер).

Namespace `kube-users` ізолює користувацькі акаунти і створюється на вимогу.

### Стратегія токенів

- **Короткоживучі** (`--ttl <duration>`): використовують `kubectl create token`. Прив'язані до SA, автоматично expire. Рекомендовано для CI/CD та доступу з обмеженим часом.
- **Довгоживучі** (`--ttl 0` або без `--ttl`): створюють `Secret` типу `kubernetes.io/service-account-token` з анотацією `kubernetes.io/service-account.name`. Kubernetes автоматично заповнює `.data.token`. Токен не expire доки Secret існує.

Скрипт виявляє ситуацію, коли API-сервер обрізає запитуваний TTL (через `--service-account-max-token-expiration`), парсячи `exp` із JWT і порівнюючи з запитаним duration.

### Idempotency

- ClusterRoleBinding-и створюються через `kubectl apply` — повторний запуск `--mkconfig` або повтор `--create` (після `--delete`) не падають на існуючих binding-ах.
- ClusterRole `nodes-viewer` створюється тільки якщо його ще нема.
- `--delete` використовує `--ignore-not-found` для всіх ресурсів.

### Що робить `--create`

1. Гарантує наявність namespace `kube-users`.
2. Відмовляє, якщо SA з такою назвою вже існує в `kube-users` або `kube-system`.
3. Створює `ServiceAccount/<user>` у `kube-users`.
4. Створює ClusterRoleBinding-и:
   - `admin` → `<user>-binding` → `cluster-admin`
   - `readonly` → `<user>-binding-view` → `view`, `<user>-binding-nodes` → `nodes-viewer`
5. Видає токен (long-lived Secret або short-lived через `kubectl create token`).
6. Записує `<user>-kubeconfig` (mode 600) у CWD.

### Що робить `--delete`

1. Знаходить користувача в `kube-users` або `kube-system`.
2. Видаляє ClusterRoleBinding-и: `<user>-binding`, `<user>-binding-view`, `<user>-binding-nodes`.
3. Видаляє Secret `<user>-token` (якщо є).
4. Видаляє ServiceAccount.
5. Видаляє локальний `<user>-kubeconfig`.

## Обмеження

- Токени, видані через `kubectl create token`, **не зберігаються** ніде в кластері. Якщо kubeconfig втрачено — єдиний шлях відновлення це видати новий токен через `--mkconfig --ttl <duration>`.
- Скрипт пише kubeconfig-и в CWD. Запускай його з директорії, де ти плануєш зберігати ці файли (або переноси їх після створення).
- CA кластера читається з **поточного kubectl-контексту**. Згенерований kubeconfig буде працювати тільки з тим самим кластером.
- `--list` потребує прав на читання `clusterrolebindings` і (для виявлення long-lived Secret-ів) `secrets` у `kube-users` та `kube-system`.

## Автор

z200801@gmail.com — оригінальна концепція та v1.0.
v2.x: рефакторинг з Claude (Anthropic).
