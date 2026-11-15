"""Shrink a VARCO GLB to a triangle budget Roblox accepts for one MeshPart, keeping its UVs and texture.

Usage:
  uv run --python 3.12 --with trimesh --with pymeshlab --with pillow --with scipy --with networkx python tools/decimate_mesh.py IN.glb OUT.glb [--faces 9000] [--texture 1024]
"""
import argparse

import numpy as np
import pymeshlab
import trimesh
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--faces", type=int, default=9000)
    parser.add_argument("--texture", type=int, default=1024)
    args = parser.parse_args()

    mesh = trimesh.load(args.src, force="mesh")
    image = mesh.visual.material.baseColorTexture or mesh.visual.material.image
    uv = np.asarray(mesh.visual.uv, dtype=np.float64)
    before = len(mesh.faces)

    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=mesh.vertices, face_matrix=mesh.faces, v_tex_coords_matrix=uv))
    ms.compute_texcoord_transfer_vertex_to_wedge()
    # VARCO splits vertices along UV seams; welding them first keeps decimation from tearing cracks.
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.001))
    ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=args.faces, preserveboundary=True)
    out = ms.current_mesh()

    corners = out.vertex_matrix()[out.face_matrix()].reshape(-1, 3)
    corner_uv = out.wedge_tex_coord_matrix()
    faces = np.arange(len(corners)).reshape(-1, 3)
    texture = image.convert("RGB").resize((args.texture, args.texture), Image.LANCZOS)
    material = trimesh.visual.material.PBRMaterial(baseColorTexture=texture, metallicFactor=0.0, roughnessFactor=0.6)
    result = trimesh.Trimesh(corners, faces, visual=trimesh.visual.TextureVisuals(uv=corner_uv, material=material), process=False)
    result.merge_vertices(merge_norm=True)
    result.export(args.dst)

    welded = result.copy()
    welded.merge_vertices(merge_tex=True, merge_norm=True)
    open_edges = len(trimesh.grouping.group_rows(welded.edges_sorted, require_count=1))
    print(f"faces {before} -> {len(result.faces)}, open edges {open_edges}, texture {texture.size}, extents {result.extents.round(3).tolist()}")


if __name__ == "__main__":
    main()
