const path = require('node:path');

// The template's cache policies, for a CDN in front of the blog: published
// pages may be served for 60 s and revalidated for 300 s more; a draft
// (`?dk=`, microCMS's preview) never.
const cachePolicies = {
  noCache: 'no-store, must-revalidate',
  publicIsr: 'public, s-maxage=60, stale-while-revalidate=300',
};

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Required by @opennextjs/cloudflare, which bundles `.next/standalone/**`
  // into the Worker. Traced from the monorepo root, so the workspace's
  // dependencies resolve from the root node_modules.
  output: 'standalone',
  outputFileTracingRoot: path.join(__dirname, '../..'),
  // The template's images are microCMS's (sized by its image API through the
  // query strings the components write) and three files in public/: nothing
  // for an image optimiser to do, so the Worker carries none.
  images: {
    unoptimized: true,
  },
  // The site's public origin (metadataBase, the Open Graph URLs). The deploy
  // sets BASE_URL per environment (apps/web/component.yaml); it is no secret.
  env: {
    BASE_URL: process.env.BASE_URL ?? '',
  },
  // Dev server only (`next build` ignores it): orun.work's live Preview tab
  // loads `next dev` from the preview's own host, and Next.js refuses the hot
  // reload and other /_next/* dev requests from an origin it is not told about.
  allowedDevOrigins: ['*.orun-preview.app', 'preview-gateway-stage.oruncloud.workers.dev'],
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'CDN-Cache-Control',
            value: cachePolicies.publicIsr,
          },
        ],
      },
      // The template set this one in proxy.ts (Next 16's Node proxy). On
      // Workers that proxy is experimental, and its header was appended to the
      // one above instead of replacing it; here the later rule wins.
      {
        source: '/blogs/:path*',
        has: [{ type: 'query', key: 'dk' }],
        headers: [
          {
            key: 'CDN-Cache-Control',
            value: cachePolicies.noCache,
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
