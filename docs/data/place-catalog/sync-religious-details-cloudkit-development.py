#!/usr/bin/env python3
"""Safely synchronize reviewed temple sects and shrine deities to Development."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


RECORD_TYPE = "PublicPlace"
STRING_LIST_FIELDS = {"typeKeys", "aliases", "enshrinedDeities"}
TIMESTAMP_FIELDS = {"updatedAt"}
BOOL_FIELDS = {"isPublished", "isDeleted"}
DOUBLE_FIELDS = {"latitude", "longitude"}
INT_FIELDS = {"capacity"}


def has_religious_details(fields: dict[str, Any]) -> bool:
    return bool(fields.get("templeSect") or fields.get("enshrinedDeities"))


def read_expected(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            if not line.strip():
                continue
            record = json.loads(line)
            if record.get("recordType") != RECORD_TYPE:
                raise SystemExit(f"line {line_number}: unexpected recordType")
            fields = record.get("fields")
            place_id = fields.get("placeID") if isinstance(fields, dict) else None
            if not isinstance(place_id, str) or not place_id:
                raise SystemExit(f"line {line_number}: placeID is required")
            if has_religious_details(fields):
                records.append(record)
    ids = [record["fields"]["placeID"] for record in records]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate placeID in religious detail input")
    return records


def cktool_fields(fields: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for key, value in fields.items():
        if value is None or value == "" or value == []:
            continue
        if key in STRING_LIST_FIELDS:
            field_type = "stringListType"
        elif key in TIMESTAMP_FIELDS:
            field_type = "timestampType"
        elif key in BOOL_FIELDS:
            field_type = "boolType"
        elif key in DOUBLE_FIELDS:
            field_type = "doubleType"
        elif key in INT_FIELDS:
            field_type = "int64Type"
        else:
            field_type = "stringType"
        result[key] = {"type": field_type, "value": value}
    return result


def run_cktool(arguments: list[str], *, stdin: str | None = None) -> dict[str, Any]:
    process = subprocess.run(
        ["xcrun", "cktool", *arguments],
        input=stdin,
        text=True,
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        message = process.stderr.strip() or process.stdout.strip()
        raise RuntimeError(message or f"cktool exited with {process.returncode}")
    output = process.stdout.strip()
    return json.loads(output) if output else {}


def common_arguments(args: argparse.Namespace) -> list[str]:
    return [
        "--team-id", args.team_id,
        "--container-id", args.container_id,
        "--environment", "development",
        "--database-type", "public",
    ]


def query_existing(args: argparse.Namespace) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    continuation: Any = None
    for _ in range(50):
        arguments = [
            "query-records",
            *common_arguments(args),
            "--record-type", RECORD_TYPE,
            "--limit", "200",
            "--sort-by", "placeID ASC",
        ]
        if continuation is not None:
            token = continuation if isinstance(continuation, str) else json.dumps(continuation)
            arguments.extend(["--continuation-token", token])
        payload = run_cktool(arguments)
        page = payload.get("records", [])
        if not isinstance(page, list):
            raise RuntimeError("unexpected cktool query response")
        records.extend(page)
        continuation = payload.get("continuationToken")
        if continuation is None:
            return records
    raise RuntimeError("more than 50 result pages found; refusing an incomplete sync")


def field_value(record: dict[str, Any], key: str) -> Any:
    value = record.get("fields", {}).get(key)
    if isinstance(value, dict) and "value" in value:
        return value["value"]
    return value


def record_name(record: dict[str, Any]) -> str:
    value = record.get("recordName") or record.get("record", {}).get("recordName")
    if not isinstance(value, str) or not value:
        raise RuntimeError("CloudKit recordName is missing")
    return value


def canonical_fields(fields: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in fields.items():
        if value is None or value == "" or value == []:
            continue
        result[key] = sorted(value) if key in STRING_LIST_FIELDS else value
    return result


def cloud_fields(record: dict[str, Any], keys: set[str]) -> dict[str, Any]:
    return canonical_fields({key: field_value(record, key) for key in keys})


def delete_record(args: argparse.Namespace, name: str) -> None:
    run_cktool([
        "delete-record",
        *common_arguments(args),
        "--record-name", name,
    ])


def create_record(args: argparse.Namespace, fields: dict[str, Any]) -> None:
    run_cktool([
        "create-record",
        *common_arguments(args),
        "--record-type", RECORD_TYPE,
        "--fields-stdin",
    ], stdin=json.dumps(cktool_fields(fields), ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--team-id", default="GDXKVW7W5X")
    parser.add_argument("--container-id", default="iCloud.com.nori.favoreco")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write religious detail records to Development; otherwise only validate",
    )
    args = parser.parse_args()

    expected = read_expected(args.input)
    if not args.apply:
        print(json.dumps({
            "mode": "validate-only",
            "religiousDetailRecords": len(expected),
            "uniquePlaceIDs": len(expected),
            "environment": "development",
        }, ensure_ascii=False))
        return

    existing = query_existing(args)
    by_id: dict[str, list[dict[str, Any]]] = {}
    for record in existing:
        place_id = field_value(record, "placeID")
        if isinstance(place_id, str) and place_id:
            by_id.setdefault(place_id, []).append(record)

    created = 0
    replaced = 0
    unchanged = 0
    removed_duplicates = 0
    for item in expected:
        fields = item["fields"]
        place_id = fields["placeID"]
        matches = by_id.get(place_id, [])
        expected_fields = canonical_fields(fields)
        exact = [
            record for record in matches
            if cloud_fields(record, set(fields)) == expected_fields
        ]
        if len(matches) == 1 and len(exact) == 1:
            unchanged += 1
            continue
        if exact:
            kept_name = record_name(exact[0])
            duplicates = [
                record for record in matches
                if record_name(record) != kept_name
            ]
            for record in duplicates:
                delete_record(args, record_name(record))
            removed_duplicates += len(duplicates)
            unchanged += 1
            continue

        # Keep the old published place until its complete replacement exists.
        create_record(args, fields)
        for record in matches:
            delete_record(args, record_name(record))
        if matches:
            replaced += 1
        else:
            created += 1

    print(json.dumps({
        "expectedReligiousDetails": len(expected),
        "existingPublicPlaces": len(existing),
        "created": created,
        "replaced": replaced,
        "unchanged": unchanged,
        "removedDuplicates": removed_duplicates,
        "environment": "development",
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
