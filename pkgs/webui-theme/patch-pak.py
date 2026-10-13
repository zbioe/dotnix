# Themes the browser's own pages through its resources.pak (format v5):
#  - the stylesheets every internal page loads (md_colors.css,
#    text_defaults.css, text_defaults_md.css) import the browser's colors
#    (chrome://theme/colors.css: GTK's, or the theme's) and get EXTRA.css
#    appended;
#  - white and near-white grey backgrounds written straight into the pages'
#    code (often inside shadow DOM, out of any stylesheet's reach) become
#    var(--nx-bg/--nx-2, original), the palette wherever EXTRA.css is loaded
#    and the original elsewhere;
#  - the variables EXTRA.css maps (`--x: ... !important`) are also rewritten
#    where components declare them for themselves (a declaration on a shadow
#    host beats an inherited one, !important or not): `--x: v` becomes
#    `--x: var(--nx-v-x, v)`, and EXTRA.css defines --nx-v-x.
#  - the focused address bar's outline (the dropdown page's search box) is a
#    thin line in --nx-omnibox-field-ring (else --nx-omnibox-ring) instead of
#    a 2px ring in the accent;
#  - the pages' own <link> to colors.css also asks for the browser's colors
#    (sets=ui -> sets=ui,chrome): the page refreshes that one when the
#    colors change, not the import above.
# Only internal pages are touched (resources naming chrome://resources), not
# the stylesheets Blink uses for websites.
# usage: patch-pak.py IN.pak OUT.pak EXTRA.css... [--whites-only]
# (--whites-only: packs without the shared stylesheets, e.g. Brave's own)
import gzip
import re
import struct
import sys

import brotli

IMPORT = b'@import url("//theme/colors.css?sets=ui,chrome");\n'
SHEETS = [
    b"--md-loading-message-color",  # md_colors.css
    b"dynamically processed by a C++ data source handler",  # text_defaults*.css
    b"chromium/ui/webui/resources/css/text_defaults_md.css",  # Brave's own copy
]
# white, and the light greys of Google's palette (#f1f3f4, #f8f9fa, ...)
LIGHT = re.compile(
    rb"(background(?:-color)?\s*:\s*)(#[0-9a-f]{6}\b|#fff\b|white|rgb\(\s*\d+,\s*\d+,\s*\d+\s*\))(?=\s*[;}!\"'`])",
    re.I,
)


def surface(m):
    """var(--nx-bg/--nx-2, original) for white and near-white neutrals"""
    raw = m[2].lower()
    if raw in (b"white", b"#fff"):
        rgb = (255, 255, 255)
    elif raw.startswith(b"#"):
        rgb = tuple(int(raw[i:i + 2], 16) for i in (1, 3, 5))
    else:
        rgb = tuple(int(x) for x in re.findall(rb"\d+", raw))
    if min(rgb) < 0xE0 or max(rgb) - min(rgb) > 0x0C:
        return m[0]
    tone = b"--nx-bg" if min(rgb) == 255 else b"--nx-2"
    return m[1] + b"var(" + tone + b", " + m[2] + b")"


def decode(blob):
    if blob[:2] == b"\x1f\x8b":
        return "gzip", gzip.decompress(blob)
    if blob[:2] == b"\x1e\x9b":  # Chromium's brotli: magic, 6-byte size, data
        return "brotli", brotli.decompress(blob[8:])
    return None, None


def encode(kind, text):
    if kind == "gzip":
        return gzip.compress(text, mtime=0)
    return b"\x1e\x9b" + len(text).to_bytes(6, "little") + brotli.compress(text)


OMNIBOX_RING = (
    b"#inputWrapper{--cr-searchbox-shadow:none;box-shadow:0 0 0 2px var(--cr-focus-outline-color)}",
    b"#inputWrapper{--cr-searchbox-shadow:none;box-shadow:0 0 0 1px var(--nx-omnibox-field-ring,var(--nx-omnibox-ring,var(--cr-focus-outline-color)))}",
)
UI_ONLY = re.compile(rb"(theme/colors\.css\?sets=ui)(?=[\"'&])")

DECL = re.compile(rb"(--[\w-]+)\s*:\s*([^;{}]+?)\s*!important\s*;")


def mapped(css):
    """--x -> value for every `--x: value !important;` of EXTRA.css"""
    return {k: v for k, v in DECL.findall(css) if not k.startswith(b"--nx-")}


def rewriter(names):
    alt = b"|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    pattern = re.compile(rb"(?<![\w-])(" + alt + rb")(\s*:\s*)(?!var\(--nx-v-)([^;{}`'\"]+?)(\s*[;}])")
    return lambda text: pattern.subn(lambda m: m[1] + m[2] + b"var(--nx-v-" + m[1][2:] + b", " + m[3] + b")" + m[4], text)


def is_sheet(text):
    return text.lstrip().startswith(b"/*") and b"<html" not in text and any(m in text for m in SHEETS)


def main(src, dst, *css_paths):
    whites_only = "--whites-only" in css_paths
    data = open(src, "rb").read()
    version, encoding, count, aliases = struct.unpack_from("<IIHH", data, 0)
    assert version == 5, f"pak version {version}"
    table = 12
    entries = [struct.unpack_from("<HI", data, table + i * 6) for i in range(count + 1)]
    alias_table = data[table + (count + 1) * 6: table + (count + 1) * 6 + aliases * 4]
    blobs = [data[entries[i][1]:entries[i + 1][1]] for i in range(count)]

    extra = b"".join(open(p, "rb").read() for p in css_paths if p != "--whites-only")
    names = mapped(extra)
    extra += b"\nhtml:not(#z) {\n" + b"".join(
        b"  --nx-v-" + k[2:] + b": " + v + b";\n" for k, v in names.items()
    ) + b"}\n"
    rewrite = rewriter(names)
    sheets = whites = decls = rings = 0
    for i, blob in enumerate(blobs):
        kind, text = decode(blob)
        if kind is None:
            continue
        new = text
        # before the rewrites below, which change its text
        rings += new.count(OMNIBOX_RING[0])
        new = new.replace(*OMNIBOX_RING)
        if b"//resources/" in text:
            new, n = LIGHT.subn(surface, new)
            whites += n
            new, n = rewrite(new)
            decls += n
        new = UI_ONLY.sub(rb"\1,chrome", new)
        if not whites_only and is_sheet(text):
            new = IMPORT + new + b"\n" + extra
            sheets += 1
        if new != text:
            blobs[i] = encode(kind, new)
    # md_colors.css, text_defaults.css and text_defaults_md.css
    assert whites_only or sheets == 3, f"found {sheets} of the 3 shared stylesheets"
    print(f"patch-pak: {sheets} stylesheets, {whites} fixed whites, {decls} own declarations, {rings} address bar outlines")

    header = struct.pack("<IIHH", version, encoding, count, aliases)
    offset = len(header) + (count + 1) * 6 + len(alias_table)
    out = [header]
    for i in range(count):
        out.append(struct.pack("<HI", entries[i][0], offset))
        offset += len(blobs[i])
    out.append(struct.pack("<HI", entries[count][0], offset))
    out.append(alias_table)
    out.extend(blobs)
    open(dst, "wb").write(b"".join(out))


main(*sys.argv[1:])
