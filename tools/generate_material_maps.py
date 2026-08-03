"""Optimiza los albedos originales y deriva mapas normal/roughness repetibles.

Las normales se calculan con diferencias centrales y muestreo circular: así los
bordes usan el píxel opuesto y no introducen una costura adicional al repetirse.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "assets" / "textures" / "realistic"
TARGET_SIZE = (1024, 1024)

# Fuerza del relieve y rugosidad perceptual por tipo de superficie.
SURFACES = {
    "horse_coat": (2.2, 0.72),
    "pine_bark": (7.5, 0.92),
    "granite": (5.2, 0.86),
    "meadow": (3.6, 0.94),
    "trail": (4.4, 0.9),
}


def build_normal_roughness(albedo: Image.Image, strength: float, roughness: float) -> Image.Image:
    rgb = np.asarray(albedo.convert("RGB"), dtype=np.float32) / 255.0
    height = rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength

    normal = np.dstack((-dx, -dy, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    encoded = np.clip(normal * 0.5 + 0.5, 0.0, 1.0)
    alpha = np.full((*height.shape, 1), roughness, dtype=np.float32)
    rgba = np.concatenate((encoded, alpha), axis=2)
    return Image.fromarray(np.uint8(rgba * 255.0), mode="RGBA")


def clean_foliage_alpha() -> None:
    """Convierte el fondo ajedrezado de la lámina generada en alfa real."""
    foliage_path = TEXTURES / "pine_branch_albedo.png"
    if not foliage_path.exists():
        return

    image = Image.open(foliage_path).convert("RGB").resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    rgb = np.asarray(image, dtype=np.float32) / 255.0
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = np.divide(
        maximum - minimum,
        np.maximum(maximum, 0.001),
        out=np.zeros_like(maximum),
    )
    # El tablero es neutro y luminoso; las agujas y ramitas son oscuras o
    # cromáticas. La rampa conserva el antialiasing fino del contorno.
    alpha = np.maximum(saturation * 7.0, (0.79 - maximum) * 7.0)
    alpha = np.clip(alpha, 0.0, 1.0)
    rgba = np.dstack((rgb, alpha))
    Image.fromarray(np.uint8(rgba * 255.0), mode="RGBA").save(foliage_path, optimize=True)
    print(f"GENERATED pine_branch alpha card: {TARGET_SIZE[0]}px")


def main() -> None:
    for name, (strength, roughness) in SURFACES.items():
        albedo_path = TEXTURES / f"{name}_albedo.png"
        albedo = Image.open(albedo_path).convert("RGB").resize(TARGET_SIZE, Image.Resampling.LANCZOS)
        albedo.save(albedo_path, optimize=True)

        normal = build_normal_roughness(albedo, strength, roughness)
        normal.save(TEXTURES / f"{name}_normal_roughness.png", optimize=True)
        print(f"GENERATED {name}: {TARGET_SIZE[0]}px, roughness={roughness:.2f}")

    clean_foliage_alpha()


if __name__ == "__main__":
    main()
