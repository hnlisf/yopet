"""Generate torso-only alpha masks for the one-piece fish artwork.

Each source body has a hand-audited envelope that follows its body axis while
remaining inside the dorsal, pectoral and anal fin seams.  Intersecting that
envelope with source alpha gives the renderer a stable, row-aligned skin mask.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "custom_fish" / "complete"
OUTPUT_DIR = ROOT / "assets" / "custom_fish" / "masks"
DIAGNOSTIC_DIR = ROOT / "build" / "custom_fish_mask_diagnostics"


@dataclass(frozen=True)
class MaskSource:
    output_name: str
    source_name: str
    rows: int
    seed_x: float
    seed_y: float
    face_end: float
    tail_start: float
    core_points: tuple[tuple[float, float], ...]


ROUND_CORE = ((.225, .36), (.36, .31), (.50, .35), (.59, .45), (.59, .55), (.50, .64), (.39, .67), (.31, .58), (.225, .54))
STREAM_CORE = ((.21, .43), (.35, .40), (.52, .42), (.615, .47), (.615, .52), (.49, .54), (.36, .55), (.32, .51), (.21, .51))
DIAMOND_CORE = ((.22, .38), (.34, .34), (.46, .39), (.605, .46), (.605, .54), (.47, .60), (.36, .64), (.29, .57), (.22, .51))
DISC_CORE = ((.225, .34), (.37, .28), (.50, .34), (.585, .44), (.585, .56), (.49, .65), (.39, .68), (.33, .57), (.225, .54))
BOTTOM_CORE = ((.215, .42), (.36, .39), (.52, .42), (.615, .47), (.615, .52), (.49, .54), (.37, .54), (.30, .49), (.215, .49))
BOX_CORE = ((.225, .38), (.35, .34), (.49, .38), (.60, .45), (.60, .54), (.49, .59), (.38, .60), (.32, .52), (.225, .51))
EEL_CORE = ((.215, .43), (.33, .41), (.45, .47), (.56, .50), (.64, .44), (.645, .50), (.56, .57), (.45, .56), (.34, .50), (.215, .49))


SOURCES = (
    MaskSource("round-sheet-mask.png", "round-sheet-v2.png", 3, .40, .50, .225, .595, ROUND_CORE),
    MaskSource("light-sheet-mask.png", "light-sheet.png", 3, .42, .48, .210, .615, STREAM_CORE),
    MaskSource("diamond-sheet-mask.png", "diamond-sheet.png", 3, .42, .50, .220, .615, DIAMOND_CORE),
    MaskSource("disc-sheet-mask.png", "disc-sheet-v2.png", 3, .41, .50, .225, .590, DISC_CORE),
    MaskSource("disc-petal-v3-mask.png", "disc-petal-v3.png", 1, .41, .50, .225, .590, DISC_CORE),
    MaskSource("torpedo-sheet-mask.png", "torpedo-sheet.png", 3, .42, .47, .205, .625, STREAM_CORE),
    MaskSource("bottom-sheet-mask.png", "bottom-sheet.png", 3, .43, .47, .215, .620, BOTTOM_CORE),
    MaskSource("box-sheet-mask.png", "box-sheet.png", 3, .42, .48, .225, .605, BOX_CORE),
    MaskSource("eel-sheet-mask.png", "eel-sheet.png", 3, .45, .49, .215, .645, EEL_CORE),
)


def vertical_anchor(row: Image.Image) -> float:
    """Locate the painted head/body band so each sprite row gets its own mask."""
    width, height = row.size
    samples: list[int] = []
    pixels = row.load()
    for y in range(round(height * .20), round(height * .76)):
        for x in range(round(width * .06), round(width * .30)):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > 180
                and red > 175
                and green > 175
                and blue > 155
                and max(red, green, blue) - min(red, green, blue) < 95
            ):
                samples.append(y)
    if not samples:
        return .5
    return (sum(samples) / len(samples)) / height


def flood_body(
    row: Image.Image,
    source: MaskSource,
    *,
    vertical_offset: float,
) -> Image.Image:
    width, height = row.size
    core = Image.new("L", row.size, 0)
    ImageDraw.Draw(core).polygon(
        [
            (round(x * width), round((y + vertical_offset) * height))
            for x, y in source.core_points
        ],
        fill=255,
    )
    source_alpha = row.getchannel("A")
    result = ImageChops.multiply(core, source_alpha)
    # A small inset keeps softened pigment safely inside contour ink.
    return result.filter(ImageFilter.MinFilter(5))


def diagnostic(row: Image.Image, mask: Image.Image) -> Image.Image:
    base = Image.new("RGBA", row.size, (4, 22, 34, 255))
    base.alpha_composite(row)
    cyan = Image.new("RGBA", row.size, (103, 226, 224, 0))
    cyan.putalpha(mask.point(lambda value: round(value * .46)))
    base.alpha_composite(cyan)
    return base


def generate(source: MaskSource) -> None:
    sheet = Image.open(SOURCE_DIR / source.source_name).convert("RGBA")
    row_height = sheet.height // source.rows
    rows = [
        sheet.crop((0, row_index * row_height, sheet.width, (row_index + 1) * row_height))
        for row_index in range(source.rows)
    ]
    anchors = [vertical_anchor(row) for row in rows]
    reference_anchor = anchors[len(anchors) // 2]
    masks: list[Image.Image] = []
    previews: list[Image.Image] = []
    for row_index, row in enumerate(rows):
        mask = flood_body(
            row,
            source,
            vertical_offset=anchors[row_index] - reference_anchor,
        )
        masks.append(mask)
        previews.append(diagnostic(row, mask))

    mask_sheet = Image.new("L", sheet.size, 0)
    preview_sheet = Image.new("RGBA", sheet.size, (4, 22, 34, 255))
    for row_index, mask in enumerate(masks):
        y = row_index * row_height
        mask_sheet.paste(mask, (0, y))
        preview_sheet.paste(previews[row_index], (0, y))

    alpha_mask = Image.new("RGBA", sheet.size, (255, 255, 255, 0))
    alpha_mask.putalpha(mask_sheet)
    alpha_mask.save(OUTPUT_DIR / source.output_name, optimize=True)
    preview_sheet.save(DIAGNOSTIC_DIR / source.output_name.replace("mask", "preview"), optimize=True)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DIAGNOSTIC_DIR.mkdir(parents=True, exist_ok=True)
    for source in SOURCES:
        generate(source)
        print(f"generated {source.output_name}")


if __name__ == "__main__":
    main()
