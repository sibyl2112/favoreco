#!/usr/bin/env python3
"""Offline release checks. Exit 1 means detected defects, not a release approval.

No cloud writes, package installation, purchases or existing simulator data deletion.
--simulator explicitly opts into XCTest on a DISPOSABLE audit device.
"""
import argparse
import datetime as dt
import json
import math
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'favorecoAPP/favorecoAPP'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--simulator', help='UUID of a dedicated Favoreco-Release-Audit simulator')
    parser.add_argument('--release-build', action='store_true')
    parser.add_argument('--derived-data-path', type=Path, help='Optional reusable Xcode build cache')
    args = parser.parse_args()
    out = args.output or Path(tempfile.mkdtemp(prefix='favoreco-release-audit-'))
    out.mkdir(parents=True, exist_ok=True)
    checks = []

    def check(name, ok, detail):
        checks.append(dict(name=name, status='PASS' if ok else 'FAIL', detail=detail))

    def run(name, command, timeout=1200):
        log = out / (name + '.log')
        try:
            with log.open('w') as f:
                result = subprocess.run(command, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
            check(name, result.returncode == 0, str(log))
            return result.returncode == 0
        except (OSError, subprocess.TimeoutExpired) as e:
            check(name, False, f'{e}; {log}')
            return False

    swift = list(APP.rglob('*.swift'))
    test_files = list((ROOT / 'favorecoAPP/favorecoAPPTests').glob('*.swift'))
    metrics = {'swiftFiles': len(swift), 'testFiles': len(test_files),
               'testMethods': sum(len(re.findall(r'func test\w+', p.read_text())) for p in test_files)}
    storekit = json.loads((APP / 'Configuration/Favoreco.storekit').read_text())
    products = storekit.get('products', []) + [p for g in storekit.get('subscriptionGroups', []) for p in g.get('subscriptions', [])]
    product_ids = [p['productID'] for p in products]
    source_ids = re.findall(r'"(com\.nori\.favoreco\.[a-z.]+)"', (APP / 'Services/PurchaseManager.swift').read_text())
    check('storekit-product-ids', len(product_ids) == len(set(product_ids)) and set(product_ids) == set(source_ids),
          'Local configuration only; App Store Connect availability not verified.')
    metrics['storekitProducts'] = len(product_ids)
    main_tab = (APP / 'Views/MainTabView.swift').read_text()
    body = main_tab.split('    var body: some View {', 1)[1].split('    private func openPendingCreateAction', 1)[0]
    check('root-sheet-router-scope', body.rfind('.environmentObject(createEntryContextRouter)') > body.rfind('.sheet('),
          'Source guard: router must wrap all root sheets. Does not prove taps/save transitions.')
    manifest = APP / 'PrivacyInfo.xcprivacy'
    required = {'UserDefaults': 'CA92.1', 'FileTimestamp': 'C617.1', 'DiskSpace': 'E174.1'}
    try:
        data = plistlib.loads(manifest.read_bytes())
        declared = {x['NSPrivacyAccessedAPIType']: x['NSPrivacyAccessedAPITypeReasons']
                    for x in data.get('NSPrivacyAccessedAPITypes', [])}
        check('privacy-required-reasons', all(v in declared.get('NSPrivacyAccessedAPICategory' + k, []) for k, v in required.items()),
              'Known API usages only; App Privacy answers require separate review.')
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException) as e:
        check('privacy-required-reasons', False, str(e))
    info = plistlib.loads((ROOT / 'favorecoAPP/Config/Info.plist').read_bytes())
    check('backup-package-type', any('favorecobackup' in x.get('UTTypeTagSpecification', {}).get('public.filename-extension', [])
          and 'com.apple.package' in x.get('UTTypeConformsTo', []) for x in info.get('UTExportedTypeDeclarations', [])),
          'Backup extension registration; actual Files import is a separate device check.')
    for kind in ['place', 'event']:
        run(kind + '-catalog-generation', [sys.executable, str(ROOT / f'docs/data/{kind}-catalog/generate-cloudkit-records.py'),
            '--output', str(out / f'{kind}-records.jsonl')], timeout=60)
    places_file = out / 'place-records.jsonl'
    if places_file.exists():
        rows = [json.loads(line)['fields'] for line in places_file.read_text().splitlines()]
        ids = [r['placeID'] for r in rows]
        id_set = set(ids)
        orphan = [{'id': r['placeID'], 'parent': r['parentPlaceID']} for r in rows
                  if r.get('parentPlaceID') and r['parentPlaceID'] not in id_set]
        bad_coordinates = []
        for r in rows:
            lat, lon = r.get('latitude'), r.get('longitude')
            if (lat is None) != (lon is None) or (lat is not None and
                not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180)):
                bad_coordinates.append(r['placeID'])
        metrics.update(publicPlaces=len(rows), missingReadings=sum(not r.get('reading') for r in rows),
                       coordinatePairs=sum(bool(r.get('latitude')) and bool(r.get('longitude')) for r in rows))
        check('place-unique-ids', len(ids) == len(id_set), f'{len(ids)} public candidate places')
        check('place-parent-references', not orphan, orphan)
        check('place-coordinates', not bad_coordinates, bad_coordinates)
        missing = [r['placeID'] for r in rows if any(not r.get(k) for k in ['officialName', 'prefecture', 'sourceURL', 'updatedAt'])]
        check('place-required-fields', not missing, missing)
    if args.simulator:
        # Refuse an ordinary personal simulator even when its UUID was supplied accidentally.
        devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j']))
        device = next((d for ds in devices['devices'].values() for d in ds if d['udid'] == args.simulator), None)
        safe = device is not None and device['name'].startswith('Favoreco-Release-Audit')
        check('isolated-simulator', safe, device['name'] if device else 'unknown UUID')
        if safe:
            run('xctest', ['xcodebuild', 'test', '-project', str(ROOT / 'favorecoAPP/favorecoAPP.xcodeproj'),
                '-scheme', 'favorecoAPP', '-destination', f'platform=iOS Simulator,id={args.simulator}',
                '-derivedDataPath', str(args.derived_data_path or out / 'DerivedData'), '-resultBundlePath', str(out / 'tests.xcresult'),
                '-parallel-testing-enabled', 'NO'])
    if args.release_build:
        run('release-build', ['xcodebuild', 'build', '-project', str(ROOT / 'favorecoAPP/favorecoAPP.xcodeproj'),
            '-scheme', 'favorecoAPP', '-configuration', 'Release', '-destination', 'generic/platform=iOS',
            '-derivedDataPath', str(out / 'ReleaseDerivedData'), 'CODE_SIGNING_ALLOWED=NO'])
    manual = ['7 genres: create/save/edit/relaunch/cancel/delete through actual buttons',
              'Repeat-entry sheet and multiple-photo picker hang regressions',
              '0/1/many records; long text; Dynamic Type; dark mode; VoiceOver; swipe interference',
              'Physical device permission denial, offline use, notifications, photo load, backup restore',
              'CloudKit production count and multiple-device sync',
              'StoreKit purchase/restore/expiry on sandbox and App Store Connect configuration']
    result = dict(generatedAt=dt.datetime.now(dt.timezone.utc).isoformat(),
                  releaseApproved=False, metrics=metrics, checks=checks, manualRequired=manual)
    (out / 'report.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print(f'Artifacts: {out}')
    return int(any(c['status'] == 'FAIL' for c in checks))


if __name__ == '__main__':
    raise SystemExit(main())
