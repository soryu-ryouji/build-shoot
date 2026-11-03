#!/usr/bin/env python3
"""按 i18n 文案重建 UI 中文字体子集。

游戏界面文本全部来自 i18n/*.json；这里把这些字符连同 ASCII 与常用标点
从 Noto Sans SC 里裁出来，避免 Web 导出因为字体子集缺字而显示方块。

用法：python tools/build_font_subset.py
源字体优先使用本机 NotoSansSC-VF.ttf，找不到时回退下载 Noto Sans CJK SC。
"""

from __future__ import annotations

import shutil
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/ui/font/source"
SRC = SOURCE_DIR / "NotoSansSC-VF.ttf"
LOCAL_FONT = Path(r"C:\Windows\Fonts\NotoSansSC-VF.ttf")
FALLBACK_FONT = SOURCE_DIR / "NotoSansCJKsc-Regular.otf"
FONT_URL = "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"

OUT_MAIN = ROOT / "assets/ui/font/game_font.otf"
OUT_NUMBERS = ROOT / "assets/ui/font/game_numbers.otf"

ASCII = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
PUNCT = (
    " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    "，。：；、？！「」『』（）【】《》·—–…×∞≡←→↑↓↔℃"
)
NUMBER_CHARS = ASCII + PUNCT + "∞×—–·+"


def ensure_source() -> Path:
    if SRC.exists():
        return SRC
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    if LOCAL_FONT.exists():
        shutil.copyfile(LOCAL_FONT, SRC)
        return SRC
    if FALLBACK_FONT.exists():
        return FALLBACK_FONT
    print(f"download {FONT_URL}")
    urllib.request.urlretrieve(FONT_URL, FALLBACK_FONT)
    return FALLBACK_FONT


def collect_chars() -> set[str]:
    chars = set(ASCII) | set(PUNCT)
    for path in sorted((ROOT / "i18n").glob("*.json")):
        data = json_loads(path)
        for value in data.values():
            if isinstance(value, str):
                chars.update(value)
    chars.update("≡×∞—–·")
    return chars


def json_loads(path: Path) -> dict:
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def subset_font(source: Path, out: Path, chars: set[str]) -> None:
    unicodes = sorted({ord(ch) for ch in chars if ch.strip() or ch == " "})
    options = subset.Options()
    options.name_IDs = [1, 2, 4, 6, 16, 17]
    options.layout_features = ["kern"]
    font = subset.load_font(str(source), options)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": 400})
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    font.save(str(out))
    print(f"subset {len(unicodes)} unicodes -> {out} ({out.stat().st_size} bytes)")


def main() -> None:
    source = ensure_source()
    subset_font(source, OUT_MAIN, collect_chars())
    subset_font(source, OUT_NUMBERS, set(NUMBER_CHARS))


if __name__ == "__main__":
    main()
