extends SceneTree
## C6 P2: every data/music_loops.json entry names a looping song that exists, sits
## inside the song, and Music applies it (loop_point + _start sets loop_offset).

func _initialize() -> void:
	var M: Variant = load("res://scripts/music.gd")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/music_loops.json"))
	var fails := 0
	if not (d is Dictionary):
		print("FAIL music_loops.json is not a dictionary"); quit(1); return
	for k in d:
		var path := "res://audio/music/%s.ogg" % k
		if not FileAccess.file_exists(path):
			print("FAIL %s: no %s" % [k, path]); fails += 1; continue
		if k in M.ONCE:
			print("FAIL %s: play-once songs don't loop" % k); fails += 1
		var st := AudioStreamOggVorbis.load_from_file(path)
		var off := float(M.loop_point(k))
		if absf(off - float(d[k])) > 0.001:
			print("FAIL %s: loop_point %.3f vs %.3f" % [k, off, d[k]]); fails += 1
		if off <= 0.0 or off >= st.get_length() - 5.0:
			print("FAIL %s: offset %.2f outside the song (%.1f s)" % [k, off, st.get_length()]); fails += 1
	if float(M.loop_point("no_such_song")) != 0.0:
		print("FAIL unknown song should loop to 0"); fails += 1
	var src := FileAccess.get_file_as_string("res://scripts/music.gd")
	if src.find("loop_offset = loop_point(name)") < 0:
		print("FAIL Music._start no longer applies loop_point"); fails += 1
	print("music_loops_test: %d entries, %d failures" % [d.size(), fails])
	quit(1 if fails else 0)
