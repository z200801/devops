[English](README.md) | **Українська**

# rustfs — Docker Swarm stack

RustFS — S3-сумісне об'єктне сховище, розгорнуте як Docker Swarm стек,
за зворотним проксі Traefik v3 з захистом fail2ban від перебору паролів.
Розроблено як заміну MinIO на одновузловому Swarm з одним менеджером.

## Архітектура

```
client
  └─► host nginx (public TLS, port 443)
        └─► Traefik websecure :19001 (self-signed TLS, stack-internal)
              ├─► rustfs S3 API  :9000  (Host: S3_HOST)
              └─► rustfs console :9001  (Host: CONSOLE_HOST)
```

Два сервіси у стеку `rustfs`:

| Сервіс          | Образ               | Опубліковані порти |
|-----------------|---------------------|--------------------|
| `rustfs_traefik`| `traefik:v3.7.10`   | 19000→80 (HTTP, лише редірект), 19001→443 (HTTPS) |
| `rustfs_rustfs` | `rustfs/rustfs:latest` | відсутні (лише внутрішня мережа) |

Іменовані томи: `rustfs-data` (об'єкти S3), `rustfs-logs`.  
Overlay-мережа: `rustfs-edge` (ім'я зафіксовано, attachable).

## Передумови

- Docker Engine з ініціалізованим Swarm (`docker swarm init` на вузлі)
- `make`, `bash`
- `mcli` (MinIO client, встановлений як `mcli` — **не** `mc`) для smoke-тестів
- Доступ у зовнішню мережу з вузла Swarm при першому деплої (Traefik завантажує
  плагін `tomMoulard/fail2ban` з каталогу плагінів)

## Налаштування

### 1. Файл змінних середовища

```bash
cp .env.example .env
$EDITOR .env
```

| Змінна | Опис |
|---|---|
| `S3_HOST` | Хостнейм, що маршрутується до S3 API (за замовчуванням: `s3.example.local`) |
| `CONSOLE_HOST` | Хостнейм, що маршрутується до консолі (за замовчуванням: `console.s3.example.local`) |
| `WEB_PORT` | HTTP-порт Traefik на хості (за замовчуванням: `19000`) |
| `WEBSECURE_PORT` | HTTPS-порт Traefik на хості (за замовчуванням: `19001`) |
| `TRUSTED_PROXY_IPS` | IP Docker ingress/gateway, який Traefik бачить як TCP-пір — див. §Upstream proxy |

`S3_HOST` і `CONSOLE_HOST` повинні резолвитись на адресу вузла Swarm з
будь-якого хоста, де запускається smoke-тест (DNS або `/etc/hosts`).

### 2. Створення Docker secrets

Креди RustFS зберігаються як Docker Swarm secrets (не в `.env`).

```bash
make secret-create ACCESS_KEY=<your-access-key> SECRET_KEY=<your-secret-key>
```

Обидва значення мінімум 8 символів. Секрети створюються один раз і
зберігаються між редеплоями стека.

> **Ротація кореневих кредів** вимагає зупинки стека (простій ~30–60 сек).
> Бакети, об'єкти та IAM-користувачі зберігаються — data volume не зачіпається.
>
> ```bash
> make secret-rotate ACCESS_KEY=<новий-ключ> SECRET_KEY=<новий-секрет>
> ```
>
> Після ротації переналаштуйте mcli (`make alias-set`) і оновіть всі S3-клієнти
> новими кредами. Для ротації без простою використовуйте сервісні акаунти
> (див. [§Сервісні акаунти](#сервісні-акаунти-ротація-кредів)).

> **Без Docker secrets:** розкоментуйте `RUSTFS_ACCESS_KEY` /
> `RUSTFS_SECRET_KEY` у `.env`, замініть `RUSTFS_ACCESS_KEY_FILE` /
> `RUSTFS_SECRET_KEY_FILE` на `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`
> у `stack.yml` `environment:`, і видаліть секції `secrets:` зі
> `stack.yml`.

### 3. Деплой

```bash
make deploy
```

`make deploy` виконує чотири дії послідовно:

1. Перевіряє існування Docker secrets `rustfs_access_key` і `rustfs_secret_key`
   (помилка з підказкою `make secret-create` якщо відсутні).
2. Створює об'єкти `docker config` для `traefik_config/traefik.yml` і
   `traefik_config/dynamic/fail2ban.yml` (ідемпотентно; імена з хеш-вмістом
   гарантують створення нового об'єкта при зміні файлу).
3. Завантажує `.env` у shell.
4. Виконує `docker stack deploy -c stack.yml rustfs`.

Для повторного деплою після зміни конфігураційного файлу:

```bash
make deploy   # detects new hash, creates new docker config, updates the stack
```

### 4. Перевірка сервісів

```bash
docker service ls
# Expected: rustfs_traefik 1/1, rustfs_rustfs 1/1

# Traefik healthcheck (ping endpoint on :8080, internal):
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker ps -q -f name=rustfs_traefik)"
# Expected: healthy

# RustFS healthcheck:
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker ps -q -f name=rustfs_rustfs)"
# Expected: healthy

# RustFS ports must NOT be published (only Traefik publishes):
docker service inspect rustfs_rustfs --format '{{json .Endpoint.Ports}}'
# Expected: null
```

### 5. Smoke-тест (mcli)

Потребує, щоб `S3_HOST` резолвився на вузол, `mcli` у `PATH`, і запущений
стек (креди читаються з Docker secrets контейнера):

```bash
make test
```

Скрипт виконує:
1. Налаштовує псевдонім mcli, що вказує на `https://${S3_HOST}:${WEBSECURE_PORT}`
   (path-style, self-signed TLS, підпис S3v4).
2. Створює бакет `smoke-test`.
3. Завантажує `smoke.txt`, скачує його і перевіряє через `diff`.
4. Виконує `make deploy` (повторний деплой) і поллить `GET /health` через Traefik
   (до 90 с, кожні 3 с) до готовності сервісу.
5. Повторно скачує і перевіряє об'єкт (перевірка збереження даних).

Очікуваний вивід:

```
PASS: upload/download match
PASS: object survived redeploy
==> smoke OK
```

Передайте `--skip-redeploy`, щоб виконати лише перевірку завантаження/скачування без повторного деплою.

## Доступ до консолі

Відкрийте `https://${CONSOLE_HOST}` у браузері. Форма входу в консоль RustFS
має два поля, що відповідають root-кредам S3 (з Docker secrets):

| Поле    | Значення            |
|---------|---------------------|
| Account | `RUSTFS_ACCESS_KEY` |
| Key     | `RUSTFS_SECRET_KEY` |

У RustFS немає окремого користувача консолі — це ті самі ключі, що використовує `mcli`.

## Модель доступу

| Роль | Консоль | mcli / S3-клієнти | Скоуп |
|---|---|---|---|
| **Admin** (`RUSTFS_ACCESS_KEY`) | Повний доступ | Усі бакети + admin API | Без обмежень |
| **User** (провізіонується через `user-create`) | Недоступна | Лише власні бакети `<user>-*` | Ізольований політикою |

**Admin** — кореневі креди (з Docker secrets). Адміни автентифікуються в
консолі та використовують усі таргети `make admin-*` / `make user-*`.

**User** — ізольований акаунт, чия політика обмежує S3-доступ до бакетів
`<user>-*`. Підключається лише через S3-клієнти або `mcli` — **консоль
недоступна**: non-admin юзер перенаправляється на `/rustfs/console/403`,
оскільки консоль потребує `admin:*` (see [rustfs#2553](https://github.com/rustfs/rustfs/issues/2553)).
Коли #2553 буде виправлено, scoped-юзери отримають scoped-view консолі
без жодних змін тут.

## Політики

RustFS використовує AWS-style IAM-модель політик. Декілька вбудованих
політик (`readwrite`, `readonly`, `writeonly`, `diagnostics`) завжди доступні.
Кастомні політики — статичний JSON: RustFS не підтримує policy-змінні
(`${aws:username}` тощо), тому ізоляція per-user вимагає окремої політики
на кожного користувача з жорстко заданим іменем (конвенція: `<user>-<суфікс>`,
наприклад `alice-rw`). Таргет `user-create` робить це автоматично через
`policies/user-rw.json.tpl`.

### Файли політик

| Файл | Опис |
|---|---|
| `policies/user-rw.json.tpl` | Per-user RW шаблон (`__USER__`→ім'я, використовується `user-create`) |
| `policies/shared-ro.json` | Read-only доступ до спільного бакета (`shared`) |
| `policies/dropbox-wo.json` | Write-only drop-box (лише запис у `dropbox/`, читання заборонене) |
| `policies/team-rw.json` | Per-team RW на всі бакети `team-*` |
| `policies/user_rw.aws-ref.json` | MinIO/AWS reference з policy-змінними — **не працює на RustFS** |

### Застосування політик вручну

```bash
# Завантажити і прикріпити shared-ro до alice
make admin-policy-create POLICY=shared-ro FILE=policies/shared-ro.json
make admin-policy-attach POLICY=shared-ro FLAGS='--user alice'

# Завантажити і прикріпити dropbox-wo до bob
make admin-policy-create POLICY=dropbox-wo FILE=policies/dropbox-wo.json
make admin-policy-attach POLICY=dropbox-wo FLAGS='--user bob'

# Завантажити і прикріпити team-rw до carol
make admin-policy-create POLICY=team-rw FILE=policies/team-rw.json
make admin-policy-attach POLICY=team-rw FLAGS='--user carol'

# Перегляд / список
make admin-policy-list
make admin-policy-info POLICY=shared-ro
make admin-policy-entities POLICY=shared-ro

# Відкріпити і видалити
make admin-policy-detach POLICY=shared-ro FLAGS='--user alice'
make admin-policy-remove POLICY=shared-ro
```

> `FLAGS='--user <name>'` повинен бути в лапках у командному рядку — без
> лапок shell розбиває `--user alice` на два слова і make отримує лише `--user`.

> **admin-policy-\* працює з RustFS.** Лише `admin-info` повертає HTTP 500
> (rustfs#1571). Імена бакетів видимі всім автентифікованим користувачам
> незалежно від політики (rustfs#3279).

## Upstream proxy

Цей стек розроблено для роботи за nginx на рівні хоста, який термінує
публічний TLS і пересилає HTTPS на порт `websecure` Traefik:

```nginx
upstream upstream_s3 {
    server 127.0.0.1:19001;   # Traefik HTTPS/websecure — NOT 19000
    keepalive 16;
}
```

**Обов'язкові заголовки**, які nginx повинен передавати:

```nginx
proxy_set_header Host              $host;   # Traefik routes by Host
proxy_set_header X-Real-IP         $remote_addr;  # fail2ban source criterion
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

**`TRUSTED_PROXY_IPS`** — повинен відповідати адресі Docker ingress/gateway,
яку Traefik бачить як TCP-пір (НЕ LAN IP nginx). Вимірюється так:

```bash
# After first deploy, send one request through nginx, then:
docker service logs rustfs_traefik 2>&1 | grep -i clientaddr | tail -5
```

Оновіть `forwardedHeaders.trustedIPs` у `traefik_config/traefik.yml` виміряним
CIDR (на обох entrypoint: `web` і `websecure`), потім виконайте `make deploy`.
Без цього fail2ban блокуватиме адресу Docker ingress замість реального IP клієнта.

TLS: Traefik використовує вбудований самопідписаний сертифікат (файли сертифікатів
не потрібні). nginx повинен встановити `proxy_ssl_verify off` при пересиланні до нього.

Повний приклад конфігурації nginx знаходиться у `nginx_config/s3.nginx.conf`.

## fail2ban

Плагін `tomMoulard/fail2ban` (v0.9.0) завантажується як експериментальний плагін
Traefik і підключається до роутерів S3 і консолі.

| Параметр | Значення |
|---|---|
| `statuscode` | `401,403,429` |
| `maxretry` | 20 |
| `findtime` | 10 хв |
| `bantime` | 3 год |
| Джерело бану | заголовок `X-Real-IP` |
| Allowlist | `127.0.0.1/32`, `::1/128` |

Параметри блокування знаходяться у `traefik_config/dynamic/fail2ban.yml`. Після
редагування виконайте `make deploy` — новий хеш вмісту автоматично створить новий
об'єкт docker config.

`logLevel: DEBUG` встановлено для початкової перевірки. У продакшні знизьте до
`INFO`, відредагувавши `traefik_config/dynamic/fail2ban.yml` і повторно задеплоївши.

## Управління через mcli

Makefile надає `mcli`-таргети для управління S3.
Усі S3-рівневі таргети працюють з RustFS; `mcli` повинен бути у `PATH` (see `make install`).

### Налаштування

```bash
make install     # download mcli to /usr/local/bin (once per machine)
make alias-set   # configure alias "rustfs" (читає креди з запущеного стека)
```

`make alias-set` читає `RUSTFS_ACCESS_KEY` і `RUSTFS_SECRET_KEY` напряму з
Docker secrets контейнера — креди у `.env` не потрібні.
Перевизначте через `USERNAME=<key> PASSWORD=<secret>` для підключення до зовнішнього інстансу.

### Операції з бакетами

```bash
make bucket-create BUCKET=mybucket              # створити бакет
make bucket-create BUCKET=photos USER=alice     # створити бакет "alice-photos"
make bucket-list                                # список всіх бакетів
make bucket-list BUCKET=mybucket                # список об'єктів у бакеті
make bucket-remove BUCKET=mybucket              # видалити бакет
make bucket-anonymous-download BUCKET=mybucket  # встановити публічну політику завантаження
```

Якщо вказано `USER=<ім'я>`, ім'я бакета автоматично доповнюється префіксом
`<user>-`. Користувач `alice` вже має політику (`alice-rw`) з `s3:*` на
бакети `alice-*`, тому бакет одразу доступний цьому користувачу.

Користувачі можуть також створювати власні бакети `<user>-*` безпосередньо
зі своїх кредів (через mcli або будь-який S3-клієнт) — політика забезпечує
виконання конвенції іменування на рівні S3. Бакети з іншими префіксами
відхиляються політикою.

### Провізіонування користувачів

`user-create` і `user-delete` обгортають admin API для провізіонування
ізольованих акаунтів. Кожен користувач отримує політику `<ім'я>-rw`, яка
обмежує доступ лише до бакетів `<ім'я>-*`.

```bash
make user-create USER=alice                   # створити юзера + політику, вивести згенерований пароль
make user-create USER=alice PASSWORD=mypass   # те саме з явним паролем
make user-delete USER=alice                   # видалити юзера + політику (бакети лишаються)
make user-delete USER=alice DELETE_BUCKETS=1  # також видалити бакети alice-*
make user-info USER=alice                     # показати політику, бакети alice-*, сервісні акаунти
```

Згенерований пароль — `openssl rand -hex 24` (48-символьний hex, безпечний для SigV4).
`USER` повинен передаватися як аргумент `make` у командному рядку — ambient `$USER`
з оточення shell відхиляється.

Модель політики (`policies/user-rw.json.tpl`, плейсхолдер `__USER__` → ім'я):

| Дозвіл | Ресурс |
|---|---|
| `s3:ListAllMyBuckets` | `arn:aws:s3:::*` |
| `s3:ListBucket`, `s3:GetBucketLocation` | `arn:aws:s3:::alice-*` |
| `s3:*` | `arn:aws:s3:::alice-*` та `arn:aws:s3:::alice-*/*` |

> **rustfs#3279:** `s3:ListAllMyBuckets` авторизується до обчислення
> per-user-політики, тому будь-який автентифікований користувач може
> перелічити всі імена бакетів незалежно від політики. Доступ до об'єктів
> і бакетів ізолюється політикою. Видимість імен бакетів не обмежена
> політикою до вирішення #3279.

### Сервісні акаунти (ротація кредів)

Сервісні акаунти — це суб-креди, створені під батьківським користувачем. Вони
успадковують політику батька, а їхній secret key можна ротувати **онлайн** —
рестарт сервісу не потрібен. Це рекомендований шлях ротації без простою
(ротація кореневих кредів через Docker secrets вимагає зупинки стека — див. §Створення Docker secrets).

```bash
# Створити сервісний акаунт під root-адміном:
make svcacct-create USER=<root-access-key>
# Вивід: згенерований access-key + secret-key

# Створити з явним secret key:
make svcacct-create USER=<root-access-key> PASSWORD=<new-secret>

# Створити з терміном дії (без EXPIRY — постійний; лише ISO 8601 datetime):
make svcacct-create EXPIRY=2026-12-31T23:59:59Z
make svcacct-create USER=alice EXPIRY=2027-06-01T00:00:00Z

# Ротувати secret key (генерується автоматично якщо PASSWORD не вказано; старий ключ відхиляється одразу):
make svcacct-rotate SERVICE_ACCOUNT=<sa-access-key>
make svcacct-rotate SERVICE_ACCOUNT=<sa-access-key> PASSWORD=<new-secret>

# Список сервісних акаунтів для батьківського юзера:
make svcacct-list USER=<root-access-key>

# Інфо про конкретний сервісний акаунт:
make svcacct-info SERVICE_ACCOUNT=<sa-access-key>

# Видалити сервісний акаунт:
make svcacct-remove SERVICE_ACCOUNT=<sa-access-key>
```

Після `svcacct-rotate` переконфігуруйте клієнтів з новим secret key. Старий
ключ відхиляється одразу — рестарт не потрібен.

### Admin API

Таргети провізіонування — `user-add`, `user-remove`, `user-list`, `user-disable`,
`user-enable`, `admin-policy-create`, `admin-policy-attach`, `admin-policy-detach`,
`admin-policy-list` — працюють з RustFS. Діагностичний ендпоінт `admin-info`
повертає HTTP 500 (see [rustfs#1571](https://github.com/rustfs/rustfs/issues/1571)).
Для поточного провізіонування використовуйте `user-create` / `user-delete` / `user-info`.

## Teardown

Видалення стека (томи зберігаються):

```bash
docker stack rm rustfs
```

Видалення томів з даними (деструктивно — всі збережені об'єкти будуть втрачені):

```bash
docker volume rm rustfs_rustfs-data rustfs_rustfs-logs
```

Видалення Docker secrets (тільки після видалення стека):

```bash
make secret-remove
```

Видалення застарілих об'єктів docker config Traefik після оновлення конфігурації:

```bash
docker config ls --filter name=traefik_static
docker config rm <old-name>
```
