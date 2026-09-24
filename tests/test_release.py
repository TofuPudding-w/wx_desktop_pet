"""Release gates and draft publishing, using temporary files and a fake GitHub API."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
import urllib.error
import urllib.parse
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from release_metadata import project_version, release_metadata
from package_linux import package_linux, RELEASE_FILES
from publish_release import GitHub, verified_assets, create_draft

COMMIT = "a" * 40


class FakeGitHub:
    def __init__(self, release=None):
        self.release = release
        self.assets = []
        self.calls = []
        self.commit = COMMIT
        self.lookup_error = None
        self.annotated = False

    def request(self, method, path, data=None, content_type=None):
        self.calls.append((method, path, data))
        if path.startswith("/git/ref/"):
            return {"object": {"type": "tag" if self.annotated else "commit", "sha": self.commit}}
        if path.startswith("/git/tags/"):
            return {"object": {"type": "commit", "sha": self.commit}}
        if path.startswith("/releases?per_page=100&page="):
            if self.lookup_error:
                raise urllib.error.HTTPError(path, self.lookup_error, "lookup failed", None, None)
            return [dict(self.release, tag_name="v0.1.0")] if self.release else []
        if path == "/releases" and method == "POST":
            self.release = dict(data, id=42, html_url="https://github.com/owner/repo/releases/tag/v0.1.0",
                                upload_url="https://uploads.github.com/repos/owner/repo/releases/42/assets{?name,label}")
            return self.release
        if path.endswith("/assets?per_page=100"):
            return self.assets
        if method == "GET" and path == "/releases/42":
            return self.release
        if path.startswith("https://uploads.github.com/"):
            asset = {"name": urllib.parse.parse_qs(urllib.parse.urlparse(path).query)["name"][0],
                     "digest": "sha256:" + hashlib.sha256(data).hexdigest(), "size": len(data), "state": "uploaded"}
            self.assets.append(asset)
            return asset
        raise AssertionError((method, path))


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "project.godot").write_text('[application]\nconfig/version="0.1.0"\n')
        self.directory = self.root / "dist/CPPet-v0.1.0-Linux-x64"
        for name in RELEASE_FILES:
            path = self.directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture " + name.encode())

    def assets(self):
        archive = package_linux(self.root)
        return verified_assets(archive.parent, archive.name)

    def test_version_from_application_section(self):
        self.assertEqual(project_version(self.root), "0.1.0")
        self.assertEqual(release_metadata(self.root, "v0.1.0")["archive"], "CPPet-v0.1.0-Linux-x64.zip")

    def test_tag_mismatch_rejected(self):
        for tag in ("v0.2.0", "main", "v0.1.0;exit", "../v0.1.0"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_metadata(self.root, tag)

    def test_malformed_version_rejected(self):
        (self.root / "project.godot").write_text('[application]\nconfig/version="$(bad)"\n')
        with self.assertRaises(ValueError):
            project_version(self.root)

    def test_other_section_cannot_supply_version(self):
        (self.root / "project.godot").write_text('[other]\nconfig/version="0.1.0"\n')
        with self.assertRaises(ValueError):
            project_version(self.root)

    def test_zip_excludes_unlisted_files_and_preserves_modes(self):
        (self.directory / "private.log").write_text("not a release asset")
        archive = package_linux(self.root)
        with zipfile.ZipFile(archive) as output:
            self.assertIsNone(output.testzip())
            self.assertEqual(len(output.namelist()), len(RELEASE_FILES))
            self.assertFalse(any(name.endswith("private.log") for name in output.namelist()))
            binary = output.getinfo("CPPet-v0.1.0-Linux-x64/CPPet.x86_64")
            self.assertEqual((binary.external_attr >> 16) & 0o777, 0o755)

    def test_zip_is_reproducible(self):
        archive = package_linux(self.root)
        first = archive.read_bytes()
        self.assertEqual(package_linux(self.root).read_bytes(), first)

    def test_missing_package_file_rejected(self):
        (self.directory / "run.sh").unlink()
        with self.assertRaises(ValueError):
            package_linux(self.root)

    def test_symlink_rejected(self):
        target = self.directory / "run.sh"
        target.unlink()
        target.symlink_to(self.directory / "README.txt")
        with self.assertRaises(ValueError):
            package_linux(self.root)

    def test_checksum_corruption_rejected(self):
        archive = package_linux(self.root)
        archive.write_bytes(archive.read_bytes() + b"changed")
        with self.assertRaises(ValueError):
            verified_assets(archive.parent, archive.name)

    def test_checksum_wrong_filename_rejected(self):
        archive = package_linux(self.root)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix(".zip.sha256").write_text(digest + "  another.zip\n")
        with self.assertRaises(ValueError):
            verified_assets(archive.parent, archive.name)

    def test_create_is_draft_prerelease_not_latest(self):
        api = FakeGitHub()
        url = create_draft(api, "v0.1.0", COMMIT, "notes", self.assets())
        self.assertTrue(url.startswith("https://github.com/"))
        self.assertTrue(api.release["draft"])
        self.assertTrue(api.release["prerelease"])
        self.assertEqual(api.release["make_latest"], "false")
        self.assertEqual(len(api.assets), 2)
        self.assertFalse(any(method in ("PATCH", "DELETE") for method, _, _ in api.calls))

    def test_matching_draft_retry_does_not_upload_again(self):
        api = FakeGitHub()
        assets = self.assets()
        create_draft(api, "v0.1.0", COMMIT, "notes", assets)
        count = len(api.calls)
        create_draft(api, "v0.1.0", COMMIT, "notes", assets)
        self.assertFalse(any(method == "POST" for method, _, _ in api.calls[count:]))

    def test_published_release_never_modified(self):
        api = FakeGitHub({"draft": False})
        with self.assertRaises(ValueError):
            create_draft(api, "v0.1.0", COMMIT, "notes", self.assets())
        self.assertTrue(all(method == "GET" for method, _, _ in api.calls))

    def test_remote_tag_mismatch_prevents_creation(self):
        api = FakeGitHub()
        api.commit = "b" * 40
        with self.assertRaises(ValueError):
            create_draft(api, "v0.1.0", COMMIT, "notes", self.assets())
        self.assertEqual(len(api.calls), 1)

    def test_annotated_tag_supported(self):
        api = FakeGitHub()
        api.annotated = True
        create_draft(api, "v0.1.0", COMMIT, "notes", self.assets())
        self.assertEqual(len(api.assets), 2)

    def test_permission_error_is_not_treated_as_absent_release(self):
        api = FakeGitHub()
        api.lookup_error = 403
        with self.assertRaises(urllib.error.HTTPError):
            create_draft(api, "v0.1.0", COMMIT, "notes", self.assets())
        self.assertFalse(any(method == "POST" for method, _, _ in api.calls))

    def test_different_draft_asset_not_overwritten(self):
        api = FakeGitHub()
        assets = self.assets()
        create_draft(api, "v0.1.0", COMMIT, "notes", assets)
        api.assets[0]["digest"] = "sha256:changed"
        count = len(api.calls)
        with self.assertRaises(ValueError):
            create_draft(api, "v0.1.0", COMMIT, "notes", assets)
        self.assertTrue(all(method == "GET" for method, _, _ in api.calls[count:]))

    def test_reject_missing_auth_and_malformed_repository(self):
        for repository, token in (("owner/repo", ""), ("../repo", "x"), ("owner/repo/extra", "x")):
            with self.subTest(repository=repository), self.assertRaises(ValueError):
                GitHub(repository, token)

    def test_reject_unexpected_upload_host_before_sending_token(self):
        api = GitHub("owner/repo", "test-token")
        with self.assertRaises(ValueError):
            api.request("POST", "https://example.com/upload", b"file")


if __name__ == "__main__":
    unittest.main()
