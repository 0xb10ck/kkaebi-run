"""Godot 4 .import sidecar generator for generated PNGs.

Defaults: importer=texture, compress/mode=lossless, mipmaps=false,
fix_alpha_border=true, hdr_as_srgb=false, filter off.
Does not overwrite an existing .import file.
"""
from __future__ import annotations

from pathlib import Path
from typing import Iterable, List


_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{rel_path}"
dest_files=["res://.godot/imported/{file_name}-{hashish}.ctex"]

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _rel_to_res(path: Path) -> str:
    root = _project_root()
    try:
        rel = path.resolve().relative_to(root)
    except ValueError:
        rel = path
    return str(rel).replace("\\", "/")


def _stable_hash(rel_path: str) -> str:
    # Stable per-path token. Real Godot regenerates this on first import.
    import hashlib
    return hashlib.md5(rel_path.encode("utf-8")).hexdigest()[:16]


def write_import_sidecar(png_path: Path, overwrite: bool = False) -> Path:
    import_path = png_path.with_suffix(png_path.suffix + ".import")
    if import_path.exists() and not overwrite:
        return import_path
    rel = _rel_to_res(png_path)
    body = _TEMPLATE.format(
        rel_path=rel,
        file_name=png_path.name,
        hashish=_stable_hash(rel),
    )
    with open(import_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    return import_path


def write_sidecars_for(paths: Iterable[Path], overwrite: bool = False) -> List[Path]:
    out: List[Path] = []
    for p in paths:
        if p.suffix.lower() != ".png":
            continue
        out.append(write_import_sidecar(p, overwrite=overwrite))
    return out


def write_sidecars_in_dir(root_dir: Path, overwrite: bool = False) -> List[Path]:
    out: List[Path] = []
    for p in root_dir.rglob("*.png"):
        out.append(write_import_sidecar(p, overwrite=overwrite))
    return out
