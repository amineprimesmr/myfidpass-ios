#!/usr/bin/env python3
"""
Génère un QR code App Store stylisé pour flyer (modules ronds, yeux arrondis, logo au centre).
Dépendances : pip install 'qrcode[pil]'
"""

from __future__ import annotations

import glob
import os

import qrcode
from PIL import Image, ImageDraw
from qrcode.constants import ERROR_CORRECT_H
from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.colormasks import SolidFillColorMask
from qrcode.image.styles.moduledrawers.pil import CircleModuleDrawer, RoundedModuleDrawer

# Lien App Store (page française)
APP_STORE_URL = "https://apps.apple.com/fr/app/myfidpass/id6759921605"

# Couleurs (proches de l’inspiration « soft UI »)
PASTEL_BLUE = (214, 228, 240)
WHITE = (255, 255, 255)
LIGHT_GREY = (237, 240, 245)
FG_BLACK = (20, 22, 28)

# Taille d’impression : augmenter box_size pour plus de pixels (flyer A5/A4)
BOX_SIZE = 20
BORDER_MODULES = 4
EMBEDDED_RATIO = 0.22


def _find_app_icon() -> str | None:
    base = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "myfidpass",
        "Assets.xcassets",
        "AppIcon.appiconset",
    )
    paths = sorted(glob.glob(os.path.join(base, "*.png")))
    return paths[0] if paths else None


def build_qr_inner() -> Image.Image:
    icon_path = _find_app_icon()
    embed_kwargs = {}
    if icon_path:
        embed_kwargs["embedded_image_path"] = icon_path
        embed_kwargs["embedded_image_ratio"] = EMBEDDED_RATIO

    color_mask = SolidFillColorMask(back_color=LIGHT_GREY, front_color=FG_BLACK)

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=BOX_SIZE,
        border=BORDER_MODULES,
    )
    qr.add_data(APP_STORE_URL)
    qr.make(fit=True)

    img = qr.make_image(
        image_factory=StyledPilImage,
        module_drawer=CircleModuleDrawer(),
        eye_drawer=RoundedModuleDrawer(radius_ratio=0.82),
        color_mask=color_mask,
        **embed_kwargs,
    )
    return img.get_image().convert("RGBA")


def add_rounded_frame(
    inner: Image.Image,
    *,
    outer_bg: tuple[int, int, int] = PASTEL_BLUE,
    ring_color: tuple[int, int, int] = WHITE,
    ring_width: int = 28,
    outer_margin: int = 72,
    corner_radius: int = 56,
) -> Image.Image:
    """Carte grise (QR), bordure blanche épaisse, fond bleu pastel, coins très arrondis."""
    iw, ih = inner.size
    card_w = iw + 2 * ring_width
    card_h = ih + 2 * ring_width
    total_w = card_w + 2 * outer_margin
    total_h = card_h + 2 * outer_margin

    out = Image.new("RGB", (total_w, total_h), outer_bg)
    draw = ImageDraw.Draw(out)

    x0 = outer_margin
    y0 = outer_margin
    # Anneau blanc
    draw.rounded_rectangle(
        (x0, y0, x0 + card_w, y0 + card_h),
        radius=corner_radius,
        fill=ring_color,
    )
    # Intérieur : le QR recouvre la zone grise (même teinte que le fond du QR)
    inner_x = x0 + ring_width
    inner_y = y0 + ring_width
    out.paste(inner, (inner_x, inner_y))

    return out


def main() -> None:
    inner = build_qr_inner()
    final = add_rounded_frame(inner)
    out_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)))
    out_path = os.path.join(out_dir, "flyer-qrcode-appstore-myfidpass.png")
    final.save(out_path, "PNG", optimize=True)
    print(f"OK → {out_path} ({final.size[0]}×{final.size[1]} px)")
    print("Teste le scan avec l’app Appareil photo avant impression.")


if __name__ == "__main__":
    main()
