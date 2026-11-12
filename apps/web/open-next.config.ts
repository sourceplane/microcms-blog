// OpenNext Cloudflare adapter config.
//
// Every page is rendered per request (the layout is force-dynamic: the
// microCMS service and key are the Worker's, never the build's), so there is
// nothing to pre-render and nothing to revalidate. The static-assets
// incremental cache serves whatever the build did pre-render (its not-found
// page) from the Worker's static assets, with no R2, KV or D1 to provision.
import { defineCloudflareConfig } from '@opennextjs/cloudflare/config';
import staticAssetsIncrementalCache from '@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache';

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});
