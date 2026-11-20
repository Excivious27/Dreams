#!/usr/bin/env python3
"""Post-export fixes for the Web build (run by .github/workflows/deploy.yml).

    python3 web/post_export.py build/web [git-sha]

- Service worker: its own downloads skip the browser HTTP cache (phones get the
  NEW game on update), a navigation to the bare folder URL (/Dreams/) falls back
  to the cached index.html, and a failed network fetch falls back to the cached
  copy / offline page instead of the browser's error (offline launch).
- Manifest: maskable icons (web/icon_maskable_*.png, crystal inside the 80%
  safe zone) so Android doesn't shrink the icon onto a white disc.
- build.json: git sha + index.pck/index.wasm hashes, so the deploy can skip
  re-uploading an unchanged game (phones would re-download ~100 MB).
Fails loudly when Godot's service worker no longer has the text it patches.
"""
import hashlib, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def patch_sw(sw: str) -> str:
    if "Dreams (C9 P4): streamed music cache." in sw:
        return sw  # already patched (a restored build folder): patching twice would fail
    def rep(a, b):
        nonlocal sw
        assert a in sw, "service worker changed, can't find: " + a[:70]
        sw = sw.replace(a, b, 1)
    rep("cache.addAll(CACHED_FILES)", "cache.addAll(CACHED_FILES.map((u) => new Request(u, {cache: 'reload'})))")
    rep("self.fetch(event.request)", "self.fetch(event.request.mode === 'navigate' ? event.request : new Request(event.request, {cache: 'no-cache'}))")
    rep("let cached = await cache.match(event.request);",
        "let cached = await cache.match(event.request);\n"
        "\t\t\t\tif (cached == null && isNavigate) { cached = await cache.match('index.html'); } // /Dreams/ = index.html (offline launch)")
    rep("// Try network if don't have it in cache.\n\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);\n\t\t\t\treturn response;",
        "// Try network if don't have it in cache.\n\t\t\t\ttry {\n\t\t\t\t\treturn await fetchAndCache(event, cache, isCacheable);\n"
        "\t\t\t\t} catch (e) {\n\t\t\t\t\tconst fb = await caches.match(isNavigate ? 'index.html' : event.request);\n"
        "\t\t\t\t\treturn fb || caches.match(OFFLINE_URL);\n\t\t\t\t}")
    sw += MUSIC_SW
    return sw


# Streamed songs (music/<name>.ogg?v=<ver>) are kept in their own Cache Storage
# (off the page heap, survives game updates since the key carries the version);
# an older version of the same song is dropped when a new one is stored.
MUSIC_SW = """
// Dreams (C9 P4): streamed music cache.
const MUSIC_CACHE = 'Dreams-music-v1';
self.addEventListener('fetch', (event) => {
	const url = new URL(event.request.url);
	if (event.request.method !== 'GET' || !/\\/music\\/[^/]+\\.ogg$/.test(url.pathname)) {
		return;
	}
	event.respondWith((async () => {
		const cache = await caches.open(MUSIC_CACHE);
		const hit = await cache.match(event.request);
		if (hit) {
			return hit;
		}
		const res = await fetch(event.request);
		if (res && res.ok && url.search) {
			const keys = await cache.keys();
			await Promise.all(keys.filter((k) => new URL(k.url).pathname === url.pathname).map((k) => cache.delete(k)));
			await cache.put(event.request, res.clone());
		}
		return res;
	})());
});
"""


def patch_manifest(out: str) -> None:
    mp = os.path.join(out, "index.manifest.json")
    m = json.load(open(mp))
    icons = [i for i in m.get("icons", []) if "maskable" not in str(i.get("purpose", ""))]
    for n in (192, 512):
        name = "icon_maskable_%d.png" % n
        shutil.copy(os.path.join(HERE, name), os.path.join(out, name))
        icons.append({"src": name, "sizes": "%dx%d" % (n, n), "type": "image/png", "purpose": "maskable"})
    m["icons"] = icons
    json.dump(m, open(mp, "w"), indent=1)


def sha(p: str) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> None:
    out = sys.argv[1]
    git = sys.argv[2] if len(sys.argv) > 2 else ""
    swp = os.path.join(out, "index.service.worker.js")
    open(swp, "w").write(patch_sw(open(swp).read()))
    patch_manifest(out)
    music = sorted(os.listdir(os.path.join(out, "music"))) if os.path.isdir(os.path.join(out, "music")) else []
    mh = hashlib.sha256()
    for t in music:
        mh.update(t.encode())
        mh.update(sha(os.path.join(out, "music", t)).encode())
    game = {"pck": sha(os.path.join(out, "index.pck")), "wasm": sha(os.path.join(out, "index.wasm")), "music": mh.hexdigest()}
    json.dump({"sha": git, "game": game}, open(os.path.join(out, "build.json"), "w"))
    print("post_export: sw patched, maskable icons added, build.json", git[:8])


if __name__ == "__main__":
    main()
