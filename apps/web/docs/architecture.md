# web — architecture

Built by the turbo pipeline from `apps/web` and deployed with wrangler.

|                     |                                                 |
| ------------------- | ----------------------------------------------- |
| Worker config       | `apps/web/wrangler.jsonc`                       |
| Entry               | `.open-next/worker.js`                          |
| Compatibility date  | `2026-10-01`                                    |
| Compatibility flags | `nodejs_compat`, `global_fetch_strictly_public` |

## Bindings

| Binding  | Kind          | Source              |
| -------- | ------------- | ------------------- |
| `ASSETS` | Static assets | `.open-next/assets` |

## Secrets resolved by the lane (names only)

- `MICROCMS_API_KEY` (optional)
- `MICROCMS_SERVICE_DOMAIN` (optional)
