"""Shrink a VARCO GLB to a triangle budget Roblox accepts for one MeshPart.

Usage:
  uv run --python 3.12 --with trimesh --with fast-simplification python tools/decimate_mesh.py IN.glb OUT.glb [--faces 9000]
"""
import argparse

import trimesh


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--faces", type=int, default=9000)
    args = parser.parse_args()

    mesh = trimesh.load(args.src, force="mesh")
    mesh.visual = trimesh.visual.ColorVisuals(mesh)
    # VARCO splits vertices along seams; decimating unwelded seams tears visible cracks.
    mesh.merge_vertices(merge_tex=True, merge_norm=True)
    before = len(mesh.faces)
    if before > args.faces:
        mesh = mesh.simplify_quadric_decimation(face_count=args.faces)
    mesh.visual = trimesh.visual.ColorVisuals(mesh)
    mesh.export(args.dst)
    open_edges = len(trimesh.grouping.group_rows(mesh.edges_sorted, require_count=1))
    print(f"faces {before} -> {len(mesh.faces)}, open edges {open_edges}, extents {mesh.extents.round(3).tolist()}")


if __name__ == "__main__":
    main()
