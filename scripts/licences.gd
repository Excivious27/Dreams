class_name Licences
## "Credits and licences" text (s1_13-09): the in-game credits (data/epilogue.json, tools/gen_epilogue.py,
## which match docs/steam-store/ai-disclosure.md), the Godot Engine MIT notice and its third-party list,
## the symbol font's Bitstream Vera notice (embedded: fonts/*.txt is not exported; tools/licences_test.gd
## keeps it equal to fonts/LICENSE-symbols.txt) and GodotSteam's MIT notice when that addon ships.

const FONT_NOTICE := "fonts/symbols.ttf (\"Dreams Symbols\") is a cut-down copy of DejaVu Sans made by\ntools/make_symbol_font.py, renamed as the licence below requires.\nDejaVu fonts: https://dejavu-fonts.github.io/ . DejaVu changes are in the public domain.\n\nCopyright (c) 2003 by Bitstream, Inc. All Rights Reserved.\nBitstream Vera is a trademark of Bitstream, Inc.\nDejaVu changes are in public domain.\nLicense: bitstream-vera\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof the fonts accompanying this license (\"Fonts\") and associated\ndocumentation files (the \"Font Software\"), to reproduce and distribute the\nFont Software, including without limitation the rights to use, copy, merge,\npublish, distribute, and/or sell copies of the Font Software, and to permit\npersons to whom the Font Software is furnished to do so, subject to the\nfollowing conditions:\n\nThe above copyright and trademark notices and this permission notice shall\nbe included in all copies of one or more of the Font Software typefaces.\n\nThe Font Software may be modified, altered, or added to, and in particular\nthe designs of glyphs or characters in the Fonts may be modified and\nadditional glyphs or characters may be added to the Fonts, only if the fonts\nare renamed to names not containing either the words \"Bitstream\" or the word\n\"Vera\".\n\nThis License becomes null and void to the extent applicable to Fonts or Font\nSoftware that has been modified and is distributed under the \"Bitstream\nVera\" names.\n\nThe Font Software may be sold as part of a larger software package but no\ncopy of one or more of the Font Software typefaces may be sold by itself.\n\nTHE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS\nOR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT,\nTRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL BITSTREAM OR THE GNOME\nFOUNDATION BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING\nANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES,\nWHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF\nTHE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE\nFONT SOFTWARE.\n\nExcept as contained in this notice, the names of Gnome, the Gnome\nFoundation, and Bitstream Inc., shall not be used in advertising or\notherwise to promote the sale, use or other dealings in this Font Software\nwithout prior written authorization from the Gnome Foundation or Bitstream\nInc., respectively. For further information, contact: fonts at gnome dot"
const GODOTSTEAM_NOTICE := "GodotSteam (desktop builds only): MIT licence, copyright the GodotSteam contributors. Steamworks SDK copyright Valve Corporation."


static func credits() -> String:
	var f := FileAccess.open("res://data/epilogue.json", FileAccess.READ)
	if f == null:
		return ""
	var d: Variant = JSON.parse_string(f.get_as_text())
	return str((d as Dictionary).get("credits", "")) if d is Dictionary else ""


## Third-party components inside the engine, one line each ("FreeType: FTL").
static func engine_parts() -> String:
	var out: PackedStringArray = []
	for c: Dictionary in Engine.get_copyright_info():
		var lic: PackedStringArray = []
		for p: Dictionary in c.get("parts", []):
			var l := str(p.get("license", ""))
			if l != "" and not lic.has(l):
				lic.append(l)
		out.append("%s: %s" % [str(c.get("name", "")), ", ".join(lic)])
	return "\n".join(out)


## Hard-wrapped licence text re-flowed: single line breaks become spaces, blank lines stay.
static func reflow(s: String) -> String:
	var paras: PackedStringArray = []
	for p in s.strip_edges().split("\n\n"):
		paras.append(" ".join(p.split("\n")).strip_edges())
	return "\n\n".join(paras)


static func text() -> String:
	var parts: PackedStringArray = [credits(), "Godot Engine licence\n\n" + reflow(Engine.get_license_text()),
		"Components inside the Godot Engine\n\n" + engine_parts(), "Symbol font\n\n" + reflow(FONT_NOTICE)]
	if ClassDB.class_exists("Steam"):
		var gs := GODOTSTEAM_NOTICE
		for lp in ["res://addons/godotsteam/license.md", "res://addons/godotsteam/license.txt", "res://addons/godotsteam/LICENSE.txt", "res://addons/godotsteam/LICENSE"]:
			if FileAccess.file_exists(lp):  # full notice when the desktop preset includes it (P1 include_filter)
				gs += "\n\n" + FileAccess.get_file_as_string(lp)
				break
		parts.append(gs)
	return "\n\n".join(parts)
