#!/usr/bin/env python3
"""Build deterministic PublicRecurringEvent CloudKit upload records."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent
TEMPLATE_KEYS = {"museum", "theater", "live"}
DATE_STATUSES = {"confirmed", "unannounced"}


def read_rows(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(encoding="utf-8-sig", newline="") as source:
        return list(csv.DictReader(source))


def split_values(value: str) -> list[str]:
    return [item.strip() for item in value.split("|") if item.strip()]


def required_url(value: str, context: str) -> str:
    parsed = urlparse(value.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise SystemExit(f"invalid URL for {context}: {value}")
    return value.strip()


def optional_date(value: str) -> str | None:
    if not value.strip():
        return None
    parsed = date.fromisoformat(value.strip())
    return f"{parsed.isoformat()}T00:00:00Z"


def required_timestamp(value: str, context: str) -> str:
    resolved = optional_date(value)
    if resolved is None:
        raise SystemExit(f"verifiedAt is required: {context}")
    return resolved


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    series_rows = read_rows("recurring-event-catalog.csv")
    edition_rows = read_rows("recurring-event-editions.csv")
    series_ids = [row["eventSeriesID"] for row in series_rows]
    edition_ids = [row["editionID"] for row in edition_rows]
    if len(series_ids) != len(set(series_ids)):
        raise SystemExit("duplicate eventSeriesID found")
    if len(edition_ids) != len(set(edition_ids)):
        raise SystemExit("duplicate editionID found")

    series_id_set = set(series_ids)
    editions_by_series: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in edition_rows:
        context = row["editionID"]
        if row["eventSeriesID"] not in series_id_set:
            raise SystemExit(f"unknown eventSeriesID for {context}")
        if row["dateStatus"] not in DATE_STATUSES:
            raise SystemExit(f"invalid dateStatus for {context}: {row['dateStatus']}")
        start = optional_date(row["startDate"])
        end = optional_date(row["endDate"])
        if row["dateStatus"] == "confirmed" and (start is None or end is None):
            raise SystemExit(f"confirmed edition requires startDate and endDate: {context}")
        if start and end and start > end:
            raise SystemExit(f"startDate is after endDate: {context}")
        editions_by_series[row["eventSeriesID"]].append({
            "id": row["editionID"],
            "label": row["editionLabel"],
            "startDate": start,
            "endDate": end,
            "dateStatus": row["dateStatus"],
            "status": row["editionStatus"],
            "prefectures": split_values(row["prefectures"]),
            "areaSummary": row["areaSummary"],
            "officialURL": required_url(row["officialURL"], context),
            "sourceURL": required_url(row["sourceURL"], context),
            "verifiedAt": required_timestamp(row["verifiedAt"], context),
        })

    records: list[dict[str, object]] = []
    for row in series_rows:
        context = row["eventSeriesID"]
        if row["templateKey"] not in TEMPLATE_KEYS:
            raise SystemExit(f"invalid templateKey for {context}: {row['templateKey']}")
        prefectures = split_values(row["prefectures"])
        if not prefectures:
            raise SystemExit(f"prefectures is required: {context}")
        editions = sorted(
            editions_by_series.get(context, []),
            key=lambda item: item["startDate"] or "",
        )
        if not editions:
            raise SystemExit(f"at least one edition is required: {context}")
        updated_at = max(
            [required_timestamp(row["verifiedAt"], context)]
            + [str(edition["verifiedAt"]) for edition in editions]
        )
        records.append({
            "recordType": "PublicRecurringEvent",
            "recordName": context,
            "fields": {
                "eventSeriesID": context,
                "officialName": row["officialName"],
                "reading": row["reading"],
                "aliases": split_values(row["aliases"]),
                "templateKey": row["templateKey"],
                "eventTypeKeys": split_values(row["eventTypeKeys"]),
                "recurrenceKey": row["recurrenceKey"],
                "recurrenceLabel": row["recurrenceLabel"],
                "prefectures": prefectures,
                "areaSummary": row["areaSummary"],
                "officialURL": required_url(row["officialURL"], context),
                "sourceURL": required_url(row["sourceURL"], context),
                "status": row["status"],
                "editionsJSON": json.dumps(
                    editions,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                "updatedAt": updated_at,
                "isPublished": True,
                "isDeleted": False,
            },
        })

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        for record in records:
            output.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")

    print(json.dumps({
        "outputRecords": len(records),
        "editions": len(edition_rows),
        "templates": {
            key: sum(record["fields"]["templateKey"] == key for record in records)
            for key in sorted(TEMPLATE_KEYS)
        },
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "output": str(args.output),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
