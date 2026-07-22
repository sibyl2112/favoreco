#!/usr/bin/env python3
"""Build deterministic PublicPlace upload records from the reviewed CSV masters."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RELIGIOUS_TYPES = {"temple", "buddhist_temple", "shrine"}
READING_EVIDENCE_METHODS = {
    "official_kana",
    "official_name_normalization",
    "official_brand_transliteration",
}


def read_rows(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(encoding="utf-8-sig", newline="") as source:
        return list(csv.DictReader(source))


def split_values(value: str) -> list[str]:
    return [item.strip() for item in value.split("|") if item.strip()]


def optional_float(value: str) -> float:
    return float(value) if value.strip() else 0.0


def optional_int(value: str) -> int | None:
    return int(value) if value.strip() else None


def iso_date(value: str) -> str:
    if not value.strip():
        raise ValueError("verifiedAt is required for published records")
    return f"{value.strip()}T00:00:00Z"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--missing-readings-output", type=Path)
    args = parser.parse_args()

    evidence = {
        row["placeID"]: row
        for row in read_rows("temple-shrine-selection-evidence.csv")
    }
    details = {
        row["placeID"]: row
        for row in read_rows("religious-place-details.csv")
    }
    memberships: dict[str, list[dict[str, object]]] = {}
    for row in read_rows("pilgrimage-memberships.csv"):
        membership = {
            "pilgrimageKey": row["pilgrimageKey"],
            "pilgrimageName": row["pilgrimageName"],
            "siteNumber": optional_int(row["siteNumber"]),
            "siteNumberLabel": row["siteNumberLabel"],
        }
        memberships.setdefault(row["placeID"], []).append(membership)

    place_rows = read_rows("place-catalog.csv")
    place_by_id = {row["placeID"]: row for row in place_rows}
    reading_evidence = read_rows("place-reading-evidence.csv")
    reading_evidence_ids = [row["placeID"] for row in reading_evidence]
    if len(reading_evidence_ids) != len(set(reading_evidence_ids)):
        raise SystemExit("duplicate placeID found in place-reading-evidence.csv")
    for row in reading_evidence:
        place = place_by_id.get(row["placeID"])
        if place is None:
            raise SystemExit(
                f"unknown placeID in place-reading-evidence.csv: {row['placeID']}"
            )
        if row["method"] not in READING_EVIDENCE_METHODS:
            raise SystemExit(
                f"unknown reading evidence method for {row['placeID']}: {row['method']}"
            )
        if not row["evidenceURL"].strip() or not row["verifiedAt"].strip():
            raise SystemExit(
                f"reading evidence source and verifiedAt are required: {row['placeID']}"
            )
        if place["reading"] != row["reading"]:
            raise SystemExit(
                f"reading evidence mismatch for {row['placeID']}: "
                f"master={place['reading']} evidence={row['reading']}"
            )
    records: list[dict[str, object]] = []
    excluded_review = 0
    for row in place_rows:
        type_keys = split_values(row["typeKeys"])
        if RELIGIOUS_TYPES.intersection(type_keys):
            selection = evidence.get(row["placeID"])
            if selection is None or selection["evidenceStatus"] != "confirmed":
                excluded_review += 1
                continue

        detail = details.get(row["placeID"], {})
        pilgrimage = memberships.get(row["placeID"], [])
        record = {
            "recordType": "PublicPlace",
            "recordName": row["placeID"],
            "fields": {
                "placeID": row["placeID"],
                "catalogID": row["catalogID"],
                "parentPlaceID": row["parentPlaceID"],
                "typeKeys": type_keys,
                "officialName": row["officialName"],
                "reading": row["reading"],
                "aliases": split_values(row["aliases"]),
                "prefecture": row["prefecture"],
                "municipality": row["municipality"],
                "address": row["address"],
                "latitude": optional_float(row["latitude"]),
                "longitude": optional_float(row["longitude"]),
                "officialURL": row["officialURL"],
                "capacity": optional_int(row["capacity"]),
                "operationalStatus": "closed" if row["status"] == "closed" else "open",
                "templeSect": detail.get("templeSect", ""),
                "enshrinedDeities": split_values(detail.get("enshrinedDeities", "")),
                "pilgrimageMembershipsJSON": json.dumps(
                    pilgrimage, ensure_ascii=False, separators=(",", ":")
                ),
                "updatedAt": iso_date(row["verifiedAt"]),
                "isPublished": True,
                "isDeleted": False,
            },
        }
        records.append(record)

    record_names = [record["recordName"] for record in records]
    if len(record_names) != len(set(record_names)):
        raise SystemExit("duplicate recordName found")
    if any(not record["fields"]["prefecture"] for record in records):
        raise SystemExit("prefecture is required for every record")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        for record in records:
            output.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    if args.missing_readings_output:
        missing = [row for row in place_rows if not row["reading"].strip()]
        args.missing_readings_output.parent.mkdir(parents=True, exist_ok=True)
        with args.missing_readings_output.open("w", encoding="utf-8-sig", newline="") as output:
            fieldnames = ["placeID", "catalogID", "officialName", "prefecture", "officialURL", "sourceURL"]
            writer = csv.DictWriter(output, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows({key: row[key] for key in fieldnames} for row in missing)
    print(json.dumps({
        "outputRecords": len(records),
        "excludedNeedsReviewReligiousPlaces": excluded_review,
        "readingPresent": sum(bool(record["fields"]["reading"]) for record in records),
        "readingMissing": sum(not record["fields"]["reading"] for record in records),
        "readingEvidenceRows": len(reading_evidence),
        "missingReadingsOutput": str(args.missing_readings_output) if args.missing_readings_output else "",
        "output": str(args.output),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
