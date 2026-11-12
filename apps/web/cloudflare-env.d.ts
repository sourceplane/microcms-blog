// The bindings wrangler.jsonc declares, and the Worker secrets the deploy
// pushes (tooling/wire/worker-secrets.mjs), as the Worker sees them.
interface CloudflareEnv {
  ASSETS: Fetcher;
  // Optional: the blog shows its sample posts without them.
  MICROCMS_SERVICE_DOMAIN?: string;
  MICROCMS_API_KEY?: string;
}
