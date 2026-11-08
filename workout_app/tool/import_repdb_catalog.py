#!/usr/bin/env python3
"""Generate the offline app catalogue from the pinned RepDB Free release.

Download the two URLs in SOURCES, then run:
  python3 tool/import_repdb_catalog.py exercises.json repdb-free.zip

Only files explicitly referenced by the snapshot's flat illustrations are
copied. The archive is never extracted wholesale (including premium samples).
Updates require reviewing the new release and deliberately changing its hashes.
"""
import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "snapshot": {
        "url": "https://exercise-dataset.com/exercises.json",
        "sha256": "ecaeece74163382d74d0082639cee83b466dec5c3e2430efaf327e3dd5357443",
    },
    "archive": {
        "url": "https://cdn.repdb.co/repdb-assets/site/repdb-free.zip",
        "sha256": "5422288dc92a7a8ef002257cde978afeb02c90ea2dba10e495f2065587de85b0",
    },
}
EXPECTED_COUNT = 701
COMMON_LIFTS = (
    "squat", "bench-press", "deadlift", "ohp", "barbell-row",
    "romanian-deadlift", "db-bench-press", "single-arm-db-row", "lateral-raise",
    "bicep-curl", "tricep-pushdown", "lat-pulldown", "seated-cable-row",
    "leg-press", "db-goblet-squat", "push-up", "reverse-lunge",
    "dumbbell-calf-raise",
)
POSES = {"start": "Start", "peak": "Peak", "main": "Position"}


def verified_bytes(path, kind):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCES[kind]["sha256"]:
        raise ValueError(f"Unreviewed {kind}: SHA-256 differs from the pinned release")
    return data


def flat_path(value):
    if not isinstance(value, str) or not re.fullmatch(
        r"images/flat/[a-z0-9]+(?:-[a-z0-9]+)*\.webp", value
    ):
        raise ValueError(f"Invalid flat illustration path: {value!r}")
    return PurePosixPath(value)


def validate_still(data, path):
    if len(data) < 20 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError(f"Not a WebP image: {path}")
    if struct.unpack_from("<I", data, 4)[0] + 8 != len(data):
        raise ValueError(f"Incomplete WebP image: {path}")
    offset, picture = 12, False
    while offset + 8 <= len(data):
        chunk, size = struct.unpack_from("<4sI", data, offset)
        if offset + 8 + size > len(data):
            raise ValueError(f"Incomplete WebP chunk: {path}")
        if chunk in (b"ANIM", b"ANMF"):
            raise ValueError(f"Animated image is not a still illustration: {path}")
        picture |= chunk in (b"VP8 ", b"VP8L")
        offset += 8 + size + (size % 2)
    if not picture or offset != len(data):
        raise ValueError(f"Invalid WebP image: {path}")


def required_text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing {field}")
    return value


def text_list(value, field, required=False):
    if not isinstance(value, list) or (required and not value):
        raise ValueError(f"Missing {field}")
    return [required_text(x, field) for x in value]


def dart(value):
    return json.dumps(value, ensure_ascii=False).replace("$", r"\$")


def build_catalogue(snapshot, archive):
    records = snapshot["exercises"]
    if snapshot["count"] != EXPECTED_COUNT or len(records) != EXPECTED_COUNT:
        raise ValueError("Unexpected RepDB catalogue size")
    english = json.loads(archive.read("free.en.json"))
    source_records = {e["id"]: e for e in english["exercises"]}
    body_labels = english["enum_labels"]["body_part"]
    equipment = english["equipment"]
    ids, files, exercises = set(), {}, []
    for record in records:
        source_id = record["id"]
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", source_id) or source_id in ids:
            raise ValueError(f"Invalid or duplicate exercise ID: {source_id}")
        ids.add(source_id)
        name = required_text(record["name_en"], "name_en")
        instructions = text_list(record["instructions_en"], "instructions_en", True)
        tips = text_list(record.get("tips_en", []), "tips_en")
        # Verify the snapshot and asset release agree about the same movement.
        source = source_records[source_id]
        if source["name"] != name or source["instructions"] != instructions:
            raise ValueError(f"Snapshot/archive content mismatch: {source_id}")
        images = record["images"]["flat"]
        if set(images) not in ({"start", "peak"}, {"main"}):
            raise ValueError(f"Unexpected pose layout: {source_id}")
        if set(source["images"]["flat"]) != set(images):
            raise ValueError(f"Snapshot/archive pose mismatch: {source_id}")
        illustrations = []
        for pose in POSES:
            if pose not in images:
                continue
            relative = flat_path(images[pose])
            image_path = str(relative)
            if image_path not in files:
                info = archive.getinfo(image_path)
                if info.file_size > 2 * 1024 * 1024:
                    raise ValueError(f"Oversized illustration: {image_path}")
                image = archive.read(info)
                validate_still(image, image_path)
                files[image_path] = image
            illustrations.append({
                "label": POSES[pose],
                "asset": "assets/exercises/repdb/flat/" + relative.name,
            })
        equipment_id = record.get("equipment")
        equipment_name = equipment[equipment_id]["name"] if equipment_id else "Bodyweight"
        exercises.append({
            "id": "repdb_" + source_id,
            "sourceId": source_id,
            "name": name,
            "muscleGroup": body_labels[record["body_part"]],
            "equipment": equipment_name,
            "description": record.get("description_en", ""),
            "instructions": instructions,
            "tips": tips,
            "illustrations": illustrations,
        })
    if set(source_records) != ids:
        raise ValueError("Snapshot/archive catalogue IDs differ")
    priority = {source_id: index for index, source_id in enumerate(COMMON_LIFTS)}
    exercises.sort(key=lambda e: (priority.get(e["sourceId"], len(priority)), e["name"].casefold()))
    return exercises, files


def generate(exercises):
    lines = [
        "// GENERATED by tool/import_repdb_catalog.py. Do not hand edit.",
        "// RepDB Free: licensed for in-app use with attribution; see bundled license.",
        "part of 'exercise_catalog.dart';", "",
        "const List<ExerciseDefinition> exerciseCatalog = [",
    ]
    for exercise in exercises:
        lines.append("  ExerciseDefinition(")
        for key, value in exercise.items():
            if key == "illustrations":
                rendered = "[" + ", ".join(
                    "ExerciseIllustration(label: " + dart(item["label"]) + ", asset: " + dart(item["asset"]) + ")"
                    for item in value
                ) + "]"
            elif isinstance(value, list):
                rendered = "[" + ", ".join(dart(x) for x in value) + "]"
            else:
                rendered = dart(value)
            lines.append(f"    {key}: {rendered},")
        lines.append("  ),")
    lines.append("];")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    snapshot = json.loads(verified_bytes(args.snapshot, "snapshot"))
    verified_bytes(args.archive, "archive")
    with zipfile.ZipFile(args.archive) as archive:
        exercises, files = build_catalogue(snapshot, archive)
        license_text = archive.read("LICENSE.md")
        if b"Free Tier License" not in license_text or b"Attribution required" not in license_text:
            raise ValueError("Unexpected free-tier license")
    # Everything is validated before modifying generated files.
    image_root = ROOT / "assets/exercises/repdb/flat"
    image_root.mkdir(parents=True, exist_ok=True)
    wanted = set()
    for name, data in files.items():
        target = image_root / PurePosixPath(name).name
        target.write_bytes(data)
        wanted.add(target.name)
    for stale in image_root.glob("*.webp"):
        if stale.name not in wanted:
            stale.unlink()
    (ROOT / "lib/data/exercise_catalog.g.dart").write_text(generate(exercises))
    (ROOT / "assets/exercises/licenses/REPDB-FREE-LICENSE.md").write_bytes(license_text)
    coverage = {
        "source": "RepDB Free", "exercises": len(exercises),
        "illustratedExercises": len(exercises), "bundledImages": len(files),
        "pairedPoseExercises": sum(len(e["illustrations"]) == 2 for e in exercises),
        "singlePoseExercises": sum(len(e["illustrations"]) == 1 for e in exercises),
    }
    manifest = {
        **coverage, "importedAt": "2026-11-08", "sources": SOURCES,
        "archiveGeneratedAt": english_date(args.archive),
        "artworkProvenance": "Original AI-generated works commissioned by RepDB; no AI derivation performed by this app.",
        "changes": "English source wording and flat images unmodified; namespaced app IDs and common-lift ordering; no premium samples.",
        "files": [{"sourcePath": name, "sha256": hashlib.sha256(data).hexdigest()} for name, data in sorted(files.items())],
    }
    (ROOT / "assets/exercises/coverage.json").write_text(json.dumps(coverage, indent=2) + "\n")
    (ROOT / "assets/exercises/repdb/manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(coverage))


def english_date(path):
    with zipfile.ZipFile(path) as archive:
        return json.loads(archive.read("free.en.json"))["generated_at"]


if __name__ == "__main__":
    main()
