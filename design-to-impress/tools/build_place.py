#!/usr/bin/env python3
"""Packs src/ into DesignToImpress.rbxlx, a place file you can open straight in Roblox Studio.

Mirrors default.project.json, so it is the same layout Rojo would build:
  ReplicatedStorage/Shared        <- src/shared
  ServerScriptService/Server      <- src/server
  StarterPlayer/StarterPlayerScripts/Client <- src/client
Files ending .server.luau become Scripts, .client.luau LocalScripts, anything else ModuleScripts.

Usage: python3 tools/build_place.py [output.rbxlx]
"""
import itertools
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
_ref = itertools.count()


def ref():
    return f"RBX{next(_ref):08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, props="", children=""):
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>{props}</Properties>{children}</Item>'
    )


def script_item(path: Path):
    name = path.name
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if name.endswith(suffix):
            source = path.read_text(encoding="utf-8")
            return item(cls, name[: -len(suffix)], f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    return ""


def folder(name, directory: Path):
    kids = "".join(script_item(p) for p in sorted(directory.iterdir()) if p.is_file())
    return item("Folder", name, children=kids)


def baseplate():
    cf = "<X>0</X><Y>-8</Y><Z>0</Z>" + "".join(
        f"<R{r}{c}>{1 if r == c else 0}</R{r}{c}>" for r in range(3) for c in range(3)
    )
    props = (
        '<bool name="Anchored">true</bool><bool name="Locked">true</bool>'
        '<Vector3 name="size"><X>2048</X><Y>16</Y><Z>2048</Z></Vector3>'
        f'<CoordinateFrame name="CFrame">{cf}</CoordinateFrame>'
        '<Color3uint8 name="Color3uint8">4284769380</Color3uint8>'
    )
    return item("Part", "Baseplate", props)


def build(out: Path):
    src = ROOT / "src"
    doc = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        + item("Workspace", "Workspace", children=baseplate())
        + item("ReplicatedStorage", "ReplicatedStorage", children=folder("Shared", src / "shared"))
        + item("ServerScriptService", "ServerScriptService", children=folder("Server", src / "server"))
        + item(
            "StarterPlayer",
            "StarterPlayer",
            children=item("StarterPlayerScripts", "StarterPlayerScripts", children=folder("Client", src / "client")),
        )
        + "</roblox>\n"
    )
    out.write_text(doc, encoding="utf-8")
    print(f"Wrote {out}")


if __name__ == "__main__":
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "DesignToImpress.rbxlx")
