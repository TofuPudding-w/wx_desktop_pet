"""Create a draft prerelease from verified artifacts; never publish or overwrite assets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
from release_metadata import release_metadata, release_archives, ROOT


class GitHub:
    def __init__(self, repository, token):
        if (not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository)
                or any(part in (".", "..") for part in repository.split("/"))):
            raise ValueError("Invalid GitHub repository")
        if not token:
            raise ValueError("GH_TOKEN is required (Actions supplies GITHUB_TOKEN automatically)")
        self.base = "https://api.github.com/repos/" + repository
        self.token = token

    def request(self, method, path, data=None, content_type="application/json"):
        url = path if path.startswith("https://") else self.base + path
        if urllib.parse.urlparse(url).netloc not in ("api.github.com", "uploads.github.com"):
            raise ValueError("Unexpected GitHub API host")
        headers = {"Authorization": "Bearer " + self.token,
                   "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
                   "Content-Type": content_type, "User-Agent": "CPPet-release"}
        if isinstance(data, dict):
            data = json.dumps(data).encode()
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.load(response)


def verified_assets(directory, archive_name):
    archive = directory / archive_name
    checksum = directory / (archive_name + ".sha256")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if checksum.read_text().split() != [digest, archive_name]:
        raise ValueError("Release archive checksum or filename does not match")
    return [(archive, digest), (checksum, hashlib.sha256(checksum.read_bytes()).hexdigest())]


def create_draft(api, tag, commit, notes, assets):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("A full source commit SHA is required")
    # Annotated and lightweight tags both resolve to the exact build commit.
    ref = api.request("GET", "/git/ref/tags/" + tag)["object"]
    for _ in range(5):
        if ref["type"] != "tag":
            break
        ref = api.request("GET", "/git/tags/" + ref["sha"])["object"]
    if ref["type"] != "commit" or ref["sha"] != commit:
        raise ValueError("Remote tag does not match the built source commit")
    # The by-tag endpoint documents published releases; list with push access
    # also returns drafts, so interrupted draft uploads can be resumed.
    release = None
    page = 1
    while release is None:
        batch = api.request("GET", f"/releases?per_page=100&page={page}")
        matches = [item for item in batch if item["tag_name"] == tag]
        if len(matches) > 1:
            raise ValueError("Multiple releases use this tag; inspect them before retrying")
        if matches:
            release = matches[0]
        if len(batch) < 100:
            break
        page += 1
    if release is None:
        release = api.request("POST", "/releases", {
            "tag_name": tag, "target_commitish": commit, "name": "CP 桌宠 " + tag,
            "body": notes, "draft": True, "prerelease": True, "make_latest": "false"})
    if not release["draft"]:
        raise ValueError("Release is already public; refusing to modify it")
    existing = {asset["name"]: asset for asset in api.request("GET", f"/releases/{release['id']}/assets?per_page=100")}
    for path, digest in assets:
        old = existing.get(path.name)
        if old:
            if old.get("digest") == "sha256:" + digest and old.get("size") == path.stat().st_size:
                continue
            raise ValueError(f"Draft already has a different {path.name}; inspect it before replacing")
        # Recheck draft status immediately before each upload.
        if not api.request("GET", f"/releases/{release['id']}")["draft"]:
            raise ValueError("Release was published during upload; stopping")
        upload_url = release["upload_url"].split("{", 1)[0]
        upload_url += "?" + urllib.parse.urlencode({"name": path.name})
        uploaded = api.request("POST", upload_url, path.read_bytes(), "application/octet-stream")
        if uploaded.get("state") != "uploaded" or uploaded.get("size") != path.stat().st_size:
            raise ValueError(f"Upload did not complete: {path.name}")
    return release["html_url"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--assets", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    metadata = release_metadata(tag=args.tag)
    assets = []
    for archive in release_archives(metadata["version"]):
        assets.extend(verified_assets(args.assets, archive))
    notes = (ROOT / "releases" / (args.tag + ".md")).read_text()
    api = GitHub(os.environ.get("GITHUB_REPOSITORY", ""), os.environ.get("GH_TOKEN", ""))
    url = create_draft(api, args.tag, args.commit, notes, assets)
    print("Draft ready (not published): " + url)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as output:
            output.write(f"Draft prerelease: [{args.tag}]({url})\n\nLinux, Windows and experimental macOS ZIPs and SHA-256 files uploaded. Not publicly published.\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, urllib.error.URLError) as error:
        raise SystemExit(f"Release stopped: {error}")
