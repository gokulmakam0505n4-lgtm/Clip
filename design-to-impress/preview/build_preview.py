#!/usr/bin/env python3
"""Builds design-to-impress-preview.html from preview_template.html plus the real catalogue."""
from pathlib import Path
from catalog_to_js import convert

HERE = Path(__file__).resolve().parent
html = (HERE / "preview_template.html").read_text(encoding="utf-8").replace("/*@@CATALOG@@*/", convert())
(HERE / "design-to-impress-preview.html").write_text(html, encoding="utf-8")
print("Wrote", HERE / "design-to-impress-preview.html")
