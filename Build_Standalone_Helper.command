#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHON="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
if [[ ! -x "$PYTHON" ]]; then echo "Python 3.13 not found at expected path"; exit 1; fi
"$PYTHON" -m pip install --user 'pyinstaller>=6,<7'
"$PYTHON" -m PyInstaller --noconfirm --clean --onefile --name arc_tv_service --collect-all pyatv ARC/apple_tv_service.py
if [[ ! -f dist/arc_tv_service ]]; then echo "Helper build failed"; exit 1; fi
cp dist/arc_tv_service ARC/arc_tv_service
chmod +x ARC/arc_tv_service
"$PYTHON" - <<'PYINNER'
from pathlib import Path
p=Path('ARC.xcodeproj/project.pbxproj'); s=p.read_text()
if 'F9 = {isa = PBXFileReference;' not in s:
 s=s.replace('/* End PBXFileReference section */', ' F9 = {isa = PBXFileReference; lastKnownFileType = file; path = arc_tv_service; sourceTree = "<group>"; };\n/* End PBXFileReference section */'.replace('\n','\n'))
 s=s.replace('/* End PBXBuildFile section */', ' A9 = {isa = PBXBuildFile; fileRef = F9; };\n/* End PBXBuildFile section */'.replace('\n','\n'))
 s=s.replace('children = (F1,F2,F6,F7);', 'children = (F1,F2,F6,F7,F9);')
 s=s.replace('files = (A7,A8);', 'files = (A7,A8,A9);')
 p.write_text(s)
print('Standalone helper prepared and added to Xcode project.')
PYINNER
printf '\nDone. Open ARC.xcodeproj and build.\n'
