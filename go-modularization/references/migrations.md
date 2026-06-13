# Migrations

Read this file before creating or renaming any migration file.

Pick layout by DB topology. Mixing within one DB instance is **forbidden**.
If the topology is not determinable from existing migrations or config → Step 0.

**Shared DB (sequence global per technology):**

```text
migrations/<technology>/<seq>_<service|shared>_<verb>_<desc>.<up|down>.sql
migrations/<technology>/<seq>_<service|shared>_<verb>_<desc>.<ext>     # forward-only (e.g. mongo .js)
```

Examples: `migrations/postgres/002_taobao_create_orders_table.up.sql`
(+ paired `.down.sql`), `migrations/mongo/003_amazon_create_scraping_collections.js`.

**Per-service DB (sequence per service per technology):**

```text
migrations/<service>/<technology>/<seq>_<verb>_<desc>.<up|down>.sql    # monorepo
migrations/<technology>/<seq>_<verb>_<desc>.<up|down>.sql              # single-service
```

Examples: `migrations/orders/postgres/001_create_orders_table.up.sql`,
`migrations/orders/mongo/003_create_scraping_collections.js`.

## Filename grammar

| Slot         | Rule                                                                                              |
| ------------ | ------------------------------------------------------------------------------------------------- |
| `<seq>`      | zero-padded int (`001`, `002`)                                                                    |
| `<service>`  | shared layout only; owner of service-scoped migration                                             |
| `shared`     | reserved literal for cross-cutting migration in shared layout; never combine with service name    |
| `<verb>`     | **closed set**: `create`, `add`, `drop`, `alter`, `rename`, `backfill`, `fix`, `refactor`, `seed` |
| `<desc>`     | snake_case noun phrase                                                                            |
| `<up\|down>` | required for SQL; forbidden for forward-only                                                      |
| `<ext>`      | `.sql` or native (e.g. `.js` for Mongo)                                                           |

Validation regex (SQL): `^[0-9]{3,}_([a-z][a-z0-9]*_)?(create|add|drop|alter|rename|backfill|fix|refactor|seed)_[a-z0-9_]+\.(up|down)\.sql$` — every `.up.sql` paired with its `.down.sql`. Forward-only: same prefix, single native extension, no `.up`/`.down`. Shared layout requires the `<service|shared>` token; per-service layout forbids it.

## Forbidden

- Free-form verbs (`_misc`, `_stuff`, bare `_update`).
- Combining `shared` token with a service name (`001_shared_taobao_...`).
- Verb as suffix or dotted segment (`_lock_fix`, `.fix.down.sql`).
- Multiple verbs in one filename.
- Migrations under `data_repositories/` or `services/<service>/`.
- Cross-service writes in shared DB — `shared` token only for genuinely
  cross-cutting changes (touches objects read/written by 2+ services, or
  DB-global objects: extensions, trigger functions, roles).

**Declarative infra config is not a migration.** RabbitMQ topology and similar
live at `infra/<technology>/` (e.g. `infra/rabbit/topology.json`).

Sequence collisions resolved at PR/rebase time. No reservation system. Renumber
only your own unmerged files; never renumber a migration that may have been
applied in any environment.

More valid/invalid examples: [`layout-examples.md`](layout-examples.md).
