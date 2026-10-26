# closure.py ISO_PATHS GRAPH...: whether a host builds offline from what the
# full ISO carries. ISO_PATHS: the ISO's store paths, one a line; GRAPH: `nix
# derivation show -r` of a host's system. A derivation whose outputs aren't
# there is built in the live system: fine unless it downloads (fixed-output)
# or needs something that can't be had either.
import json
import subprocess
import sys

sys.setrecursionlimit(50000)  # (stdenv's bootstrap chain is deep)
STORE = "/nix/store/"
present = {p.removeprefix(STORE) for p in open(sys.argv[1]).read().split()}
failed = False

for graph_file in sys.argv[2:]:
    drvs = json.load(open(graph_file))["derivations"]

    # downloads carry their hash, not their path: asked all at once
    fixed = [d for d, v in drvs.items() if any("hash" in o for o in v["outputs"].values())]
    fixed_out = {}
    if fixed:
        out = subprocess.run(
            ["nix-store", "--query", "--outputs", *[STORE + d for d in fixed]],
            check=True, capture_output=True, text=True,
        ).stdout.split()
        # one output each (fetchers)
        fixed_out = dict(zip(fixed, (p.removeprefix(STORE) for p in out)))

    def paths(drv, outs):
        if drv in fixed_out:
            return [fixed_out[drv]]
        return [drvs[drv]["outputs"][o]["path"] for o in outs]

    seen, why = {}, {}

    def can_have(drv, outs, parent):
        """Whether drv's outputs outs are there, or can be built offline."""
        key = (drv, tuple(sorted(outs)))
        if key not in seen:
            seen[key] = True
            if not all(p in present for p in paths(drv, outs)):
                if drv in fixed_out:
                    why[drv] = f"a download, for {parent.removesuffix('.drv').split('-', 1)[1]}"
                    seen[key] = False
                else:
                    deps = drvs[drv]["inputs"]["drvs"].items()
                    seen[key] = all([can_have(d, s["outputs"], drv) for d, s in deps])
        return seen[key]

    # the host: what nothing else in the graph needs
    used = {d for v in drvs.values() for d in v["inputs"]["drvs"]}
    top = [d for d in drvs if d not in used]
    if len(top) != 1:
        sys.exit(f"{graph_file}: {len(top)} roots")
    can_have(top[0], list(drvs[top[0]]["outputs"]), top[0])
    built = sum(1 for (d, o), ok in seen.items() if ok and not all(p in present for p in paths(d, o)))
    name = graph_file.rsplit("/", 1)[-1].removesuffix(".json")
    if why:
        failed = True
        print(f"{name}: can't be built offline from the ISO, {len(why)} downloads missing:")
        for drv, reason in sorted(why.items()):
            print(f"  {drv.removesuffix('.drv').split('-', 1)[1]}: {reason}")
    else:
        print(f"{name}: builds offline ({built} derivations built in the live system)")

sys.exit(1 if failed else 0)
