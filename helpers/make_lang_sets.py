# make_lang_sets.py
#!/usr/bin/env python3
"""
make_lang_sets.py  <lang>  <in_dir>
Creates  <in_dir>/<lang>_union.paths   and   <in_dir>/<lang>_intersection.paths
"""
import sys, pathlib, functools
lang, P = sys.argv[1], pathlib.Path(sys.argv[2])
sets = [ {l.split()[1] for l in f.read_text().splitlines()}
         for f in P.glob(f"{lang}_*.paths") ]
if not sets:
    sys.exit("no .paths found")
u = sorted(functools.reduce(set.union, sets))
i = sorted(functools.reduce(set.intersection, sets))
pathlib.Path(P,f"{lang}_union.paths").write_text("\n".join(u))
pathlib.Path(P,f"{lang}_intersection.paths").write_text("\n".join(i))
print("done", lang, len(u), len(i))
