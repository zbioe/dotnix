# ublock-read.py IDB.sqlite: uBlock Origin's settings (from LibreWolf's
# storage.local) as the JSON its managed storage takes
import json
import sqlite3
import struct
import sys

import snappy

TAG_NULL, TAG_UNDEFINED, TAG_BOOLEAN, TAG_INT32, TAG_STRING = 0xFFFF0000, 0xFFFF0001, 0xFFFF0002, 0xFFFF0003, 0xFFFF0004
TAG_ARRAY, TAG_OBJECT, TAG_END = 0xFFFF0007, 0xFFFF0008, 0xFFFF0013


def clone(data):
    """Decodes a structured clone holding strings, booleans, numbers, arrays and objects."""
    pos = 8  # the header pair

    def pair():
        nonlocal pos
        low, high = struct.unpack_from("<II", data, pos)
        pos += 8
        return low, high

    def string(low):
        nonlocal pos
        length, latin1 = low & 0x7FFFFFFF, bool(low & 0x80000000)
        size = length if latin1 else length * 2
        text = data[pos:pos + size].decode("latin1" if latin1 else "utf-16-le")
        pos += (size + 7) // 8 * 8
        return text

    def value():
        low, high = pair()
        if high == TAG_STRING:
            return string(low)
        if high == TAG_BOOLEAN:
            return bool(low)
        if high in (TAG_NULL, TAG_UNDEFINED):
            return None
        if high == TAG_INT32:
            return struct.unpack("<i", struct.pack("<I", low))[0]
        if high == TAG_ARRAY:
            items = {}
            while True:
                klow, khigh = pair()
                if khigh == TAG_END:
                    return [items[i] for i in sorted(items)]
                items[klow] = value()
        if high == TAG_OBJECT:
            obj = {}
            while True:
                klow, khigh = pair()
                if khigh == TAG_END:
                    return obj
                key = string(klow) if khigh == TAG_STRING else klow
                obj[key] = value()
        # a double: the pair is the number itself
        return struct.unpack("<d", struct.pack("<II", low, high))[0]

    return value()


db = sqlite3.connect(sys.argv[1])
store = {}
for key, data in db.execute("select key, data from object_data"):
    name = "".join(chr(b - 1) for b in bytes(key)[1:])
    if name.startswith("cache"):
        continue
    try:
        store[name] = clone(snappy.decompress(bytes(data)))
    except Exception:
        pass

lists = store.get("selectedFilterLists") or []
admin = {
    key: store[key]
    for key in ("dynamicFilteringString", "hostnameSwitchesString", "urlFilteringString")
    if isinstance(store.get(key), str)
}
# trusted sites: an array here, "whitelist" for adminSettings
if isinstance(store.get("netWhitelist"), list):
    admin["whitelist"] = store["netWhitelist"]
print(json.dumps({
    "name": "uBlock0@raymondhill.net",
    "description": "_",
    "type": "storage",
    "data": {
        "toOverwrite": {
            "filterLists": lists,
            "filters": (store.get("user-filters") or "").splitlines(),
        },
        "userSettings": [["advancedUserEnabled", "true" if store.get("advancedUserEnabled") else "false"]],
        "adminSettings": json.dumps(admin),
    },
}, indent=2))
