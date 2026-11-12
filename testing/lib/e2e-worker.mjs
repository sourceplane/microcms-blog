// THE E2E'S OWN ENTRY, never shipped: the built Worker, with its requests to
// microCMS sent to a local stand-in (testing/lib/fake-microcms.py).
//
// microcms-js-sdk builds `https://<service>.microcms.io/api/v1/…` itself and
// calls the global fetch, with no option for another host. So this wraps the
// global fetch BEFORE the Worker's modules load (a dynamic import, after the
// wrap: Next.js captures the fetch it patches when its server starts), and
// sends a request for any *.microcms.io host to E2E_MICROCMS_ORIGIN, naming
// the host it was for in x-microcms-host. Everything else is untouched, and
// the product code is exactly what deploys. testing/e2e.test.sh copies this
// next to the staged build's .open-next/.
let origin = "";
const realFetch = globalThis.fetch;
globalThis.fetch = (input, init) => {
  const request = new Request(input, init);
  const url = new URL(request.url);
  if (origin && url.hostname.endsWith(".microcms.io")) {
    const headers = new Headers(request.headers);
    headers.set("x-microcms-host", url.hostname);
    return realFetch(new URL(url.pathname + url.search, origin), { method: request.method, headers });
  }
  return realFetch(input, init);
};
const { default: worker } = await import("./.open-next/worker.js");
export default {
  fetch(request, env, ctx) {
    origin = env.E2E_MICROCMS_ORIGIN || "";
    return worker.fetch(request, env, ctx);
  },
};
