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
	print("perf_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)
