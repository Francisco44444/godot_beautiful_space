"""Prepara mapas normal/roughness para los materiales medievales.

Los materiales CC0 de Poly Haven incluyen normal y rugosidad separados. Godot
y Terrain3D pueden leer ambos desde una sola textura RGBA: normal en RGB y
rugosidad en alfa. Las dos texturas originales del héroe derivan su relieve del
albedo mediante diferencias centrales periódicas.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CC0 = ROOT / "assets" / "textures" / "cc0" / "polyhaven"
MEDIEVAL = ROOT / "assets" / "textures" / "medieval"
SIZE = (1024, 1024)


def pack_polyhaven(folder: Path) -> None:
    normal = np.asarray(Image.open(folder / "normal.jpg").convert("RGB").resize(SIZE), dtype=np.uint8)
    roughness = np.asarray(Image.open(folder / "roughness.jpg").convert("L").resize(SIZE), dtype=np.uint8)
    packed = np.dstack((normal, roughness))
    Image.fromarray(packed, mode="RGBA").save(folder / "normal_roughness.png", optimize=True)
    print(f"PACKED {folder.relative_to(ROOT)}/normal_roughness.png")


def derive_surface(name: str, strength: float, roughness: float) -> None:
    albedo_path = MEDIEVAL / f"{name}_albedo.png"
    image = Image.open(albedo_path).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    image.save(albedo_path, optimize=True)
    rgb = np.asarray(image, dtype=np.float32) / 255.0
    height = rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    normal = np.dstack((-dx, -dy, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    encoded = np.clip(normal * 0.5 + 0.5, 0.0, 1.0)
    alpha = np.full((*height.shape, 1), roughness, dtype=np.float32)
    rgba = np.concatenate((encoded, alpha), axis=2)
    Image.fromarray(np.uint8(rgba * 255.0), mode="RGBA").save(
        MEDIEVAL / f"{name}_normal_roughness.png", optimize=True
    )
    print(f"DERIVED {name}: roughness={roughness:.2f}")


def main() -> None:
    for material in ("forest_ground_03", "mossy_cobblestone", "mossy_rock"):
        pack_polyhaven(CC0 / material)
    derive_surface("forest_wool", 4.8, 0.94)
    derive_surface("aged_leather", 3.2, 0.72)


if __name__ == "__main__":
    main()
