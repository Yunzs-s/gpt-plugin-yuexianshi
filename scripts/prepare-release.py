"""Validate the Windows-only fork archive and generated release metadata."""
import hashlib
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
package = json.loads((root / 'gpt-niang-usage/package.json').read_text(encoding='utf-8-sig'))
version = package['version']
name = f'codex-quota-widget-v{version}-windows.zip'
dist = root / 'dist'
archive_path = dist / name
prefix = 'GPT娘额度挂件/'
with zipfile.ZipFile(archive_path) as archive:
    if archive.testzip() is not None:
        raise SystemExit('Corrupt Windows archive')
    manifest = json.loads(archive.read(prefix + 'gpt-niang-usage/.codex-plugin/plugin.json'))
    marketplace = json.loads(archive.read(prefix + '.agents/plugins/marketplace.json'))
    if manifest['version'] != version or manifest['name'] != 'codex-quota-widget' or package['name'] != manifest['name'] or marketplace['name'] != 'codex-quota-local':
        raise SystemExit('Fork package identity/version mismatch')
    for relative in ['assets/quotes.json', 'runtime/update-source.json']:
        packaged = archive.read(prefix + 'gpt-niang-usage/' + relative)
        source = (root / 'gpt-niang-usage' / relative).read_bytes()
        # Windows checkout may convert text JSON to CRLF while the Linux
        # publisher checkout keeps LF; compare content independent of EOL.
        if packaged.replace(b'\r\n', b'\n') != source.replace(b'\r\n', b'\n'):
            raise SystemExit('Outdated Windows package resource: ' + relative)
    if any(entry.startswith(prefix + 'macos/') for entry in archive.namelist()):
        raise SystemExit('Mac app must not be included in this Windows package')
digest = hashlib.sha256(archive_path.read_bytes()).hexdigest().upper()
(dist / 'SHA256SUMS.txt').write_text(f'{digest}  {name}\n', encoding='utf-8')
if not (dist / 'release-notes.md').is_file():
    raise SystemExit('Build Windows release notes first')
print(f'Validated Windows fork package {name}')
