import json
from pathlib import Path
import plistlib
import stat
import struct
import sys
import tempfile
import unittest
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build_stage1 import validate_archive

class Stage1ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'test.zip'

    def write(self, files, executable=()):
        files = {'README.txt': b'test', 'BUILD_INFO.json': b'{}', 'TEST_CHECKLIST.md': b'check', **files}
        with zipfile.ZipFile(self.path, 'w') as z:
            for name, data in files.items():
                info = zipfile.ZipInfo('package/' + name)
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | (0o755 if name in executable else 0o644)) << 16
                z.writestr(info, data)

    def pe(self, machine=0x8664):
        data = bytearray(256)
        data[:2] = b'MZ'
        struct.pack_into('<I', data, 0x3C, 128)
        data[128:132] = b'PE\0\0'
        struct.pack_into('<H', data, 132, machine)
        return data

    def test_windows_resources_and_architecture(self):
        for machine, passes in [(0x8664, True), (0xAA64, False)]:
            self.write({'CPPet.exe': self.pe(machine), 'CPPet.pck': b'x'*1024})
            if passes: validate_archive(self.path, 'windows')
            else:
                with self.assertRaises(ValueError): validate_archive(self.path, 'windows')
        self.write({'CPPet.exe': self.pe(), 'CPPet.pck': b''})
        with self.assertRaises(ValueError): validate_archive(self.path, 'windows')

    def test_linux_permissions(self):
        elf = bytearray(64)
        elf[:5] = b'\x7fELF\x02'
        struct.pack_into('<H', elf, 18, 62)
        files = {'CPPet.x86_64': elf, 'run.sh': b'#!/bin/sh\n'}
        self.write(files, executable=files)
        validate_archive(self.path, 'linux')
        self.write(files)
        with self.assertRaises(ValueError): validate_archive(self.path, 'linux')

    def test_mac_universal_and_modes(self):
        data = bytearray(48)
        struct.pack_into('>II', data, 0, 0xCAFEBABE, 2)
        struct.pack_into('>I', data, 8, 0x01000007)
        struct.pack_into('>I', data, 28, 0x0100000C)
        exe = 'CPPet.app/Contents/MacOS/CPPet'
        files = {'CPPet.app/Contents/Info.plist': plistlib.dumps({'CFBundleExecutable':'CPPet'}), exe:data,
                 'CPPet.app/Contents/Resources/CPPet.pck': b'data'}
        self.write(files, executable=[exe])
        validate_archive(self.path, 'macos')
        self.write(files)
        with self.assertRaises(ValueError): validate_archive(self.path, 'macos')

if __name__ == '__main__':
    unittest.main()
