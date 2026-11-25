#!/usr/bin/env python3
"""Converts ../src/shared/Catalog.luau (constants + items table) into JavaScript, so the
preview draws exactly the parts, sizes and colours the game scripts define."""
import re
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "src" / "shared" / "Catalog.luau"


def convert() -> str:
    lua = SRC.read_text(encoding="utf-8")
    consts = re.findall(r"^local ([A-Z_]+) = (rgb\([^)]*\))$", lua, re.M)
    body = lua[lua.index("local items: { Item } = {") : lua.index("Catalog.Items = items")]
    body = body.replace("local items: { Item } = {", "ITEMS_START [", 1)
    body = body.rstrip()
    assert body.endswith("}")
    body = body[:-1] + "];"
    body = re.sub(r"--[^\n]*", "", body)
    body = re.sub(r"Enum\.(?:Material|PartType)\.(\w+)", r'"\1"', body)
    body = re.sub(r"\b([A-Z]\w*) = ", r"\1: ", body)
    # Lua array-of-parts tables "{ {" -> JS arrays; item/part tables stay objects.
    body = re.sub(r"Parts: \{", "Parts: [", body)
    body = re.sub(r"join\(\{", "join([", body)
    body = re.sub(r"\{ \{ Size", "[{ Size", body)
    # close the arrays opened above: balance by walking characters
    out, stack, i = [], [], 0
    while i < len(body):
        c = body[i]
        if c == "[":
            stack.append("]")
        elif c == "{":
            stack.append("}")
        elif c in "]}":
            c = stack.pop()
        out.append(c)
        i += 1
    js = "".join(out).replace("ITEMS_START", "const ITEMS =", 1)
    head = "\n".join(f"const {n} = {v};" for n, v in consts)
    return head + "\n" + js


if __name__ == "__main__":
    print(convert())
