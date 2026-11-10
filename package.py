from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent
qa = '--qa' in sys.argv
name = '任务潮汐测试' if qa else '任务潮汐'
bundle = root / 'dist' / (name + '.app')
contents = bundle / 'Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Resources').mkdir(exist_ok=True)
shutil.copy2(root / ('TaskTide-QA' if qa else 'TaskTide'), contents / 'MacOS' / 'TaskTide')
if (root / 'AppIcon.icns').exists():
    shutil.copy2(root / 'AppIcon.icns', contents / 'Resources' / 'AppIcon.icns')
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump({
        'CFBundleExecutable': 'TaskTide',
        'CFBundleIdentifier': 'local.tasktide.qa' if qa else 'local.tasktide.mac',
        'CFBundleName': name, 'CFBundleDisplayName': name,
        'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1',
        'CFBundleShortVersionString': '1.1.0',
        'LSMinimumSystemVersion': '14.0',
        'NSHighResolutionCapable': True,
        'CFBundleDevelopmentRegion': 'zh_CN',
        'CFBundleLocalizations': ['zh_CN'],
        'CFBundleIconFile': 'AppIcon',
        'NSHumanReadableCopyright': '本机单机任务管理工具',
    }, f)
subprocess.run(['codesign', '--force', '--sign', '-', str(bundle)], check=True)
print(bundle)
