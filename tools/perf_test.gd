extends SceneTree
## Performance guards (headless, fast):
## - TriBatch builds one triangle list from fans and antialiased lines;
## - Art.trim_cache keeps what the last scene used and drops the rest past the budget.
## Frame/bake numbers: tools/perf_probe.gd (needs xvfb for draw calls).
const TriBatch := preload("res://scripts/tri_batch.gd")
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("PERF FAIL: ", msg)

func _run() -> void:
	var tb := TriBatch.new()
	_ok(tb.is_empty(), "new batch is empty")
	tb.fan(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]), PackedColorArray([Color.WHITE]))
	_ok(tb.idx.size() == 6 and tb.pts.size() == 4 and tb.cols.size() == 4, "quad = 2 triangles, 4 points")
	tb.fan(PackedVector2Array([Vector2(0, 0), Vector2(1, 0)]), PackedColorArray([Color.WHITE]))
	_ok(tb.idx.size() == 6, "a 2-point fan adds nothing")
	tb.line(Vector2(0, 0), Vector2(20, 0), Color.RED, 2.0)
	_ok(tb.idx.size() == 6 + 30 and tb.pts.size() == 12, "line = core quad + feather ring (10 triangles)")
	_ok(tb.cols[11].a == 0.0 and tb.cols[4].a == 1.0, "feather fades to clear")
	tb.line(Vector2(5, 5), Vector2(5, 5), Color.RED, 2.0)
	_ok(tb.pts.size() == 12, "zero-length line skipped")
	var ci := Node2D.new()
	root.add_child(ci)
	tb.flush(ci)
	_ok(tb.is_empty(), "flush empties the batch")
	ci.queue_free()
	# Texture cache: used keys survive a trim past the budget, unused ones go.
	Art.trim_cache()
	var a := Art.tex("tiles", "tilled_dry")
	var b := Art.tex("tiles", "tilled_wet")
	_ok(a != null and b != null, "test textures load")
	Art.trim_cache()  # new scene: nothing used yet
	Art.tex("tiles", "tilled_dry")  # the next scene uses only this one
	var keep_total := Art._total
	Art._total = Art.CACHE_BUDGET + 1  # pretend we're over the budget
	Art.trim_cache()
	_ok(Art._tex.has("tiles/tilled_dry"), "texture the last scene used is kept")
	_ok(not Art._tex.has("tiles/tilled_wet"), "texture the last scene never used is dropped")
	_ok(Art._total == Art.CACHE_BUDGET + 1 - (keep_total - int(Art._bytes.get("tiles/tilled_dry", 0))), "memory estimate follows evictions")
	Art._total = Art.CACHE_CEILING + 1
	Art.trim_cache()
	_ok(Art._tex.is_empty() and Art._total == 0, "past the ceiling everything goes")
	# CONDUCT 2 helpers: rects, circles, plain lines and arcs all land in one batch.
	var t2 := TriBatch.new()
	t2.rect(Rect2(0, 0, 4, 4), Color.WHITE)
	_ok(t2.idx.size() == 6, "rect = 2 triangles")
	t2.circle(Vector2(10, 10), 2.0, Color.RED)
	_ok(t2.pts.size() == 4 + 12, "small circle = 12 points")
	t2.circle(Vector2(10, 10), 30.0, Color.RED)
	_ok(t2.pts.size() == 16 + 64, "big circle capped at 64 points (Godot's own count)")
	var before := t2.idx.size()
	t2.seg(Vector2(0, 0), Vector2(0, 10), Color.RED, 1.0)
	_ok(t2.idx.size() == before + 6, "plain line = one quad")
	_ok(is_equal_approx(t2.pts[t2.pts.size() - 4].x, 0.5) or is_equal_approx(t2.pts[t2.pts.size() - 4].x, -0.5), "1 px line spans half a pixel each side")
	before = t2.idx.size()
	t2.arc(Vector2.ZERO, 2.0, 0.0, PI, 4, Color.RED, 1.0)
	_ok(t2.idx.size() == before + 24, "arc of 4 segments = 4 quads")
	# ScreenCover: an opaque mini-game hides the map under it; nested screens count.
	var gm := GameMap.new()
	var c1 := ScreenCover.cover(gm)
	_ok(c1 == gm and not gm.visible, "cover hides the map")
	var c2 := ScreenCover.cover(gm)
	ScreenCover.uncover(c2)
	_ok(not gm.visible, "still hidden while another screen is open")
	ScreenCover.uncover(c1)
	_ok(gm.visible and not gm.has_meta("screen_covers"), "last screen closed: map shows again")
	ScreenCover.uncover(c1)
	_ok(gm.visible, "a second uncover is harmless")
	var plain := Node2D.new()
	_ok(ScreenCover.cover(plain) == null and plain.visible, "only a GameMap is ever hidden")
	gm.free()
	plain.free()
	# RegionData: regions.json parsed once and shared.
	var ra := RegionData.all()
	_ok(not ra.is_empty() and RegionData.all() == ra and is_same(RegionData.all(), ra), "regions.json parsed once per session")
	_ok(RegionData.region("bf_orchard_line").has("battle"), "a battlefield entry reads back")
	print("perf_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
