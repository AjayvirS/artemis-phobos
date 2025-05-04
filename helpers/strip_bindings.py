# strip_bindings.py
#!/usr/bin/env python3
"""
strip_bindings.py  <txt>  <lang>  <exercise>  <out_dir>
Produces   <out_dir>/<lang>_<exercise>.paths
"""
import sys, re, subprocess, pathlib
rx = re.compile(r"^(/[^ ]+)\s+->\s+([rwn])$")
bootstrap = {"/bin","/sbin","/usr","/lib","/lib64","/lib32","/libx32",
             "/etc","/proc","/dev","/tmp","/var/tmp","/var/cache"}
norm = lambda p: subprocess.run(
    ["realpath","--canonicalize-missing","--no-symlinks",p],
    text=True,capture_output=True,check=True).stdout.strip()
src, lang, ex, outdir = sys.argv[1:]
keep = []
for line in open(src):
    m = rx.match(line)
    if m:
        path, mode = m.groups()
        if path in bootstrap:  # skip constant binds
            continue
        keep.append(f"{mode} {norm(path)}")
pathlib.Path(outdir).mkdir(parents=True, exist_ok=True)
out = pathlib.Path(outdir) / f"{lang}_{ex}.paths"
out.write_text("\n".join(sorted(set(keep))))
print("wrote", out)
