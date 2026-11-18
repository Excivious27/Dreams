"""Every copy-paste prompt Tom uses (Art Prompts 17 and later) asks for at most 3 images.
ChatGPT reliably breaks on more. Run by tools/check.sh."""
import re, glob, sys, os
D = os.path.join(os.path.dirname(__file__), "..", "docs")
bad = 0
for f in sorted(glob.glob(os.path.join(D, "ART-PROMPTS-*.md"))):
    m = re.search(r"ART-PROMPTS-(\d+)\.md$", f)
    if not m or int(m.group(1)) < 17:
        continue
    for block in re.split(r"\n## PROMPT ", open(f).read())[1:]:
        head = block.split("\n", 1)[0]
        body = block.split("\n---\n")[0]
        imgs = set(re.findall(r'"(w\d+[a-z]?_[^"]+\.png)"', body))
        mm = re.search(r"Make (ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|\d+) SEPARATE", body)
        word = mm.group(1) if mm else "ONE"
        if len(imgs) > 3 or word not in ("ONE", "TWO", "THREE"):
            bad += 1
            print("TOO MANY IMAGES:", os.path.basename(f), head, len(imgs), word)
print("prompt_size_check:", bad, "failures")
sys.exit(1 if bad else 0)
