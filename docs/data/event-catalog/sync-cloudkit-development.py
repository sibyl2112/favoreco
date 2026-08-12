#!/usr/bin/env python3
"""Safely synchronize PublicRecurringEvent records to CloudKit Development."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


RECORD_TYPE = "PublicRecurringEvent"
STRING_LIST_FIELDS = {"aliases", "eventTypeKeys", "prefectures"}
TIMESTAMP_FIELDS = {"updatedAt"}
BOOL_FIELDS = {"isPublished", "isDeleted"}


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
            series_id = fields.get("eventSeriesID") if isinstance(fields, dict) else None
            if not isinstance(series_id, str) or not series_id:
                raise SystemExit(f"line {line_number}: eventSeriesID is required")
            records.append(record)
    ids = [record["fields"]["eventSeriesID"] for record in records]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate eventSeriesID in input")
    return records


def cktool_fields(fields: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for key, value in fields.items():
        if key in STRING_LIST_FIELDS:
            field_type = "stringListType"
        elif key in TIMESTAMP_FIELDS:
            field_type = "timestampType"
        elif key in BOOL_FIELDS:
            field_type = "boolType"
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
    payload = run_cktool([
        "query-records",
        *common_arguments(args),
        "--record-type", RECORD_TYPE,
        "--limit", "200",
    ])
    records = payload.get("records", [])
    if not isinstance(records, list):
        raise RuntimeError("unexpected cktool query response")
    if payload.get("continuationToken"):
        raise RuntimeError("more than 200 records found; refusing an incomplete sync")
    return records


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


def normalized_fields(fields: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for key, value in fields.items():
        normalized[key] = sorted(value) if key in STRING_LIST_FIELDS else value
    return normalized


def cloud_fields(record: dict[str, Any], keys: set[str]) -> dict[str, Any]:
    return normalized_fields({key: field_value(record, key) for key in keys})


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
        help="write to CloudKit Development; without this flag only validates the input",
    )
    args = parser.parse_args()

    expected = read_expected(args.input)
    if not args.apply:
        print(json.dumps({
            "mode": "validate-only",
            "records": len(expected),
            "uniqueSeriesIDs": len(expected),
            "environment": "development",
        }, ensure_ascii=False))
        return

    existing = query_existing(args)
    by_id: dict[str, list[dict[str, Any]]] = {}
    for record in existing:
        series_id = field_value(record, "eventSeriesID")
        if isinstance(series_id, str) and series_id:
            by_id.setdefault(series_id, []).append(record)

    created = 0
    replaced = 0
    unchanged = 0
    removed_duplicates = 0
    for item in expected:
        fields = item["fields"]
        series_id = fields["eventSeriesID"]
        matches = by_id.get(series_id, [])
        expected_fields = normalized_fields(fields)
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

        # Create the replacement before deleting old records so a failed create
        # never leaves the catalog without this series. If a later delete fails,
        # the next run detects and removes the remaining duplicate safely.
        create_record(args, fields)
        for record in matches:
            delete_record(args, record_name(record))
        if matches:
            replaced += 1
        else:
            created += 1

    unexpected = [
        record for record in existing
        if field_value(record, "eventSeriesID") not in {
            item["fields"]["eventSeriesID"] for item in expected
        }
    ]
    print(json.dumps({
        "expected": len(expected),
        "created": created,
        "replaced": replaced,
        "unchanged": unchanged,
        "removedDuplicates": removed_duplicates,
        "unexpectedRecordsKept": len(unexpected),
        "environment": "development",
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
