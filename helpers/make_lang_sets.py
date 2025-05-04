# make_lang_sets.py
#!/usr/bin/env python3
"""
make_lang_sets.py  <lang>  <in_dir>
Creates  <in_dir>/<lang>_union.paths   and   <in_dir>/<lang>_intersection.paths
"""
import sys
import pathlib
import functools

lang = sys.argv[1]
P = pathlib.Path(sys.argv[2])

files = list(P.glob(f"{lang}_*.paths"))
if not files:
    sys.exit("no .paths found")

sets = [set(f.read_text().splitlines()) for f in files]

u = sorted(functools.reduce(set.union, sets))
i = sorted(functools.reduce(set.intersection, sets))

# Write output files
union_file = P / f"{lang}_union.paths"
intersection_file = P / f"{lang}_intersection.paths"

union_file.write_text("\n".join(u))
intersection_file.write_text("\n".join(i))

print("done", lang, "union size:", len(u), "intersection size:", len(i))
