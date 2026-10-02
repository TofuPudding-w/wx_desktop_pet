import importlib.util
from pathlib import Path
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('shortcut', Path(__file__).resolve().parents[1] / 'tools/launchers/create_shortcut.py')
shortcut = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shortcut)

class ShortcutTests(unittest.TestCase):
    def test_install_and_update_special_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            package = root / '绘图 $pet %1 "quote" `tick`'
            package.mkdir()
            for name in ['run.sh', 'CPPet.x86_64', 'icon.png']:
                (package/name).touch()
            paths = shortcut.install(package, root/'desktop', root/'apps')
            self.assertEqual(len(paths), 2)
            text = paths[0].read_text()
            self.assertIn('%%1', text)
            self.assertIn('X-WXPet-Launcher=true', text)
            self.assertIn('\\\\$', text)
            self.assertTrue(paths[0].stat().st_mode & 0o111)
            self.assertEqual(shortcut.install(package, root/'desktop', root/'apps'), paths)
            paths[0].write_text('[Desktop Entry]\nName=Unrelated\n')
            with self.assertRaises(ValueError): shortcut.install(package, root/'desktop', root/'apps')
            self.assertIn('Unrelated', paths[0].read_text())

    def test_missing_package_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError): shortcut.install(tmp, Path(tmp)/'desktop', Path(tmp)/'apps')

if __name__ == '__main__': unittest.main()
