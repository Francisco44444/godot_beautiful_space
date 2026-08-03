"""Prepara texturas PBR empaquetadas para Terrain3D y los materiales medievales.

Terrain3D necesita albedo RGB + altura A y normal OpenGL RGB + rugosidad A.
Sin el canal de altura no puede mezclar relieves entre capas. Los materiales
principales proceden de ambientCG (CC0); los tres materiales Poly Haven
anteriores se mantienen empaquetados para compatibilidad. Las dos texturas del
héroe derivan su relieve del albedo mediante diferencias centrales periódicas.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CC0 = ROOT / "assets" / "textures" / "cc0" / "polyhaven"
MEDIEVAL = ROOT / "assets" / "textures" / "medieval"
AMBIENTCG = ROOT / "assets" / "textures" / "cc0" / "ambientcg"
PHOTOREALISTIC = ROOT / "assets" / "models" / "photorealistic"
SIZE = (1024, 1024)


def pack_polyhaven(folder: Path) -> None:
    normal = np.asarray(Image.open(folder / "normal.jpg").convert("RGB").resize(SIZE), dtype=np.uint8)
    roughness = np.asarray(Image.open(folder / "roughness.jpg").convert("L").resize(SIZE), dtype=np.uint8)
    packed = np.dstack((normal, roughness))
    Image.fromarray(packed, mode="RGBA").save(folder / "normal_roughness.png", optimize=True)
    print(f"PACKED {folder.relative_to(ROOT)}/normal_roughness.png")


def pack_ambientcg(asset_id: str) -> None:
    folder = AMBIENTCG / asset_id
    prefix = f"{asset_id}_1K-JPG"
    albedo = np.asarray(
        Image.open(folder / f"{prefix}_Color.jpg").convert("RGB").resize(SIZE),
        dtype=np.uint8,
    )
    height = np.asarray(
        Image.open(folder / f"{prefix}_Displacement.jpg").convert("L").resize(SIZE),
        dtype=np.uint8,
    )
    normal = np.asarray(
        Image.open(folder / f"{prefix}_NormalGL.jpg").convert("RGB").resize(SIZE),
        dtype=np.uint8,
    )
    roughness = np.asarray(
        Image.open(folder / f"{prefix}_Roughness.jpg").convert("L").resize(SIZE),
        dtype=np.uint8,
    )
    Image.fromarray(np.dstack((albedo, height)), mode="RGBA").save(
        folder / "albedo_height.png", optimize=True
    )
    Image.fromarray(np.dstack((normal, roughness)), mode="RGBA").save(
        folder / "normal_roughness.png", optimize=True
    )
    print(f"PACKED {folder.relative_to(ROOT)} (albedo+height, normal+roughness)")


def make_grass_cutout(asset_id: str) -> None:
    """Recupera un canal alfa estable desde los atlas JPEG sobre fondo negro.

    Los GLTF originales apuntan a difusos JPEG, que no pueden almacenar alfa.
    Se conserva el color original y se convierte la intensidad máxima RGB en
    una máscara suave: el ruido de compresión casi negro desaparece y los
    bordes antialias de las briznas permanecen. El material GLTF usa luego
    alpha MASK, apropiado para vegetación instanciada en Godot.
    """
    folder = PHOTOREALISTIC / asset_id / "textures"
    source = folder / f"{asset_id}_diff_1k.jpg"
    target = folder / f"{asset_id}_diff_alpha_1k.png"
    rgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.uint8)
    intensity = np.max(rgb.astype(np.float32), axis=2)

    # JPEG deja ruido de 1-10 niveles sobre el fondo negro. Entre 4 y 48 se
    # conserva una transición suave; con alphaCutoff=0.20 el corte efectivo
    # queda cerca de 17/255 y elimina el halo sin comerse las hojas oscuras.
    alpha = np.clip((intensity - 4.0) / 44.0, 0.0, 1.0)
    alpha = alpha * alpha * (3.0 - 2.0 * alpha)
    rgba = np.dstack((rgb, np.uint8(np.rint(alpha * 255.0))))
    Image.fromarray(rgba, mode="RGBA").save(target, optimize=True)
    print(f"CUTOUT {target.relative_to(ROOT)}")


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
    for asset_id in ("Ground037", "Ground030", "Rock063"):
        pack_ambientcg(asset_id)
    for material in ("forest_ground_03", "mossy_cobblestone", "mossy_rock", "metal_plate"):
        pack_polyhaven(CC0 / material)
    for grass in ("grass_medium_01", "grass_bermuda_01"):
        make_grass_cutout(grass)
    derive_surface("forest_wool", 4.8, 0.94)
    derive_surface("aged_leather", 3.2, 0.72)


if __name__ == "__main__":
    main()
