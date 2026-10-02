#!/usr/bin/env python3
"""Create per-user Linux shortcuts pointing to this extracted portable package."""
import argparse
import os
from pathlib import Path
import subprocess


def desktop_quote(value):
    # Desktop Entry Exec quoting (not shell quoting); percent signs are field codes.
    value = str(value).replace('%', '%%')
    for character in ('\\', '"', '`', '$'):
        value = value.replace(character, '\\' + character)
    return '"' + value + '"'


def entry(folder):
    folder = Path(folder).resolve()
    if '\n' in str(folder) or '\r' in str(folder):
        raise ValueError('Package directory cannot contain newlines')
    # General Desktop Entry string escaping is applied after Exec quoting.
    command = desktop_quote(folder / 'run.sh').replace('\\', '\\\\')
    icon = str(folder / 'icon.png').replace('\\', '\\\\')
    return ('[Desktop Entry]\nType=Application\nName=WangXian Desktop Pet\n'
            'Name[zh_CN]=忘羡桌宠\nComment=WangXian Desktop Pet\n'
            f'Exec={command}\nIcon={icon}\nTerminal=false\nCategories=Game;\n'
            'X-WXPet-Launcher=true\n')


def install(folder, desktop, applications):
    folder = Path(folder).resolve()
    for required in ['run.sh', 'CPPet.x86_64', 'icon.png']:
        if not (folder / required).is_file():
            raise ValueError('Extract the whole package first: missing ' + required)
    destinations = list(dict.fromkeys([Path(desktop) / 'wx-desktop-pet.desktop', Path(applications) / 'wx-desktop-pet.desktop']))
    for path in destinations:
        if path.exists() and 'X-WXPet-Launcher=true' not in path.read_text():
            raise ValueError('Refusing to overwrite an unrelated launcher: ' + str(path))
    for path in destinations:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(entry(folder))
        path.chmod(0o755)
    return destinations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--desktop-dir', type=Path)
    parser.add_argument('--applications-dir', type=Path)
    args = parser.parse_args()
    desktop = args.desktop_dir
    if desktop is None:
        try:
            desktop = Path(subprocess.check_output(['xdg-user-dir', 'DESKTOP'], text=True).strip())
        except (OSError, subprocess.CalledProcessError):
            desktop = Path.home() / 'Desktop'
    applications = args.applications_dir or Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'applications'
    for path in install(args.package, desktop, applications):
        print('Created:', path)
    print('On GNOME, right-click the desktop shortcut and choose Allow Launching if prompted.')
    print('Keep the extracted folder in place. After moving/updating it, rerun this script.')


if __name__ == '__main__':
    main()
