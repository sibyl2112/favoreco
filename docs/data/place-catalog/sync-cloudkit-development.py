#!/usr/bin/env python3
"""Safely synchronize the complete PublicPlace catalog to Development."""

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
            records.append(record)

    ids = [record["fields"]["placeID"] for record in records]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate placeID in input")
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
    for _ in range(100):
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
    raise RuntimeError("more than 100 result pages found; refusing an incomplete sync")


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


def build_plan(
    expected: list[dict[str, Any]],
    existing: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], int, int]:
    by_id: dict[str, list[dict[str, Any]]] = {}
    for record in existing:
        place_id = field_value(record, "placeID")
        if isinstance(place_id, str) and place_id:
            by_id.setdefault(place_id, []).append(record)

    creates: list[dict[str, Any]] = []
    replacements: list[dict[str, Any]] = []
    duplicate_deletes: list[dict[str, Any]] = []
    unchanged = 0

    for item in expected:
        fields = item["fields"]
        matches = by_id.get(fields["placeID"], [])
        expected_fields = canonical_fields(fields)
        exact = [
            record for record in matches
            if cloud_fields(record, set(fields)) == expected_fields
        ]
        if exact:
            unchanged += 1
            kept_name = record_name(exact[0])
            duplicate_deletes.extend(
                record for record in matches if record_name(record) != kept_name
            )
        elif matches:
            replacements.append({"item": item, "old": matches})
        else:
            creates.append(item)

    expected_ids = {item["fields"]["placeID"] for item in expected}
    unexpected = sum(
        1 for record in existing
        if field_value(record, "placeID") not in expected_ids
    )
    return creates, replacements, duplicate_deletes, unchanged, unexpected


def create_record(args: argparse.Namespace, fields: dict[str, Any]) -> None:
    run_cktool([
        "create-record",
        *common_arguments(args),
        "--record-type", RECORD_TYPE,
        "--fields-stdin",
    ], stdin=json.dumps(cktool_fields(fields), ensure_ascii=False))


def delete_record(args: argparse.Namespace, name: str) -> None:
    run_cktool([
        "delete-record",
        *common_arguments(args),
        "--record-name", name,
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--team-id", default="GDXKVW7W5X")
    parser.add_argument("--container-id", default="iCloud.com.nori.favoreco")
    parser.add_argument(
        "--plan",
        action="store_true",
        help="query Development and report the diff without writing",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="apply the reported diff to Development",
    )
    parser.add_argument(
        "--confirm-expected-count",
        type=int,
        help="required with --apply; must equal the local input count",
    )
    args = parser.parse_args()

    if args.plan and args.apply:
        raise SystemExit("choose either --plan or --apply")

    expected = read_expected(args.input)
    if not args.plan and not args.apply:
        print(json.dumps({
            "mode": "validate-only",
            "records": len(expected),
            "uniquePlaceIDs": len(expected),
            "environment": "development",
        }, ensure_ascii=False))
        return

    if args.apply and args.confirm_expected_count != len(expected):
        raise SystemExit(
            "--confirm-expected-count must exactly match the local input count"
        )

    existing = query_existing(args)
    if len(existing) < 3000:
        raise RuntimeError(
            f"only {len(existing)} existing PublicPlace records found; refusing a bulk sync"
        )

    creates, replacements, duplicate_deletes, unchanged, unexpected = build_plan(
        expected, existing
    )
    summary = {
        "mode": "apply" if args.apply else "plan",
        "expected": len(expected),
        "existing": len(existing),
        "create": len(creates),
        "replace": len(replacements),
        "unchanged": unchanged,
        "duplicateDeletes": len(duplicate_deletes),
        "unexpectedRecordsKept": unexpected,
        "environment": "development",
    }
    if not args.apply:
        print(json.dumps(summary, ensure_ascii=False))
        return

    for item in creates:
        create_record(args, item["fields"])
    for replacement in replacements:
        create_record(args, replacement["item"]["fields"])
        for old_record in replacement["old"]:
            delete_record(args, record_name(old_record))
    for duplicate in duplicate_deletes:
        delete_record(args, record_name(duplicate))

    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
