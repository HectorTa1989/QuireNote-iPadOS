"""Inspect and update QuireNote review information using App Store Connect API."""

import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt


API = "https://api.appstoreconnect.apple.com/v1"
APP_ID = "6833061876"


def api_request(token, method, path, data=None):
    body = None if data is None else json.dumps(data).encode("utf-8")
    request = urllib.request.Request(
        API + path,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"App Store Connect {method} {path}: HTTP {error.code}: {details}") from error


def token_from_environment():
    now = int(time.time())
    private_key = os.environ["APPSTORE_PRIVATE_KEY"].replace("\\n", "\n")
    return jwt.encode(
        {"iss": os.environ["APPSTORE_ISSUER_ID"], "iat": now, "exp": now + 1199,
         "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": os.environ["APPSTORE_KEY_ID"], "typ": "JWT"},
    )


def versions(token):
    query = urllib.parse.urlencode({"limit": "200", "include": "appStoreReviewDetail,build"})
    response = api_request(token, "GET", f"/apps/{APP_ID}/appStoreVersions?{query}")
    included = {(item["type"], item["id"]): item for item in response.get("included", [])}
    for version in response["data"]:
        attributes = version["attributes"]
        platform = attributes.get("platform")
        if platform not in {"IOS", "MAC_OS"}:
            continue
        related = version.get("relationships", {})
        detail_data = related.get("appStoreReviewDetail", {}).get("data")
        build_data = related.get("build", {}).get("data")
        detail_id = detail_data["id"] if detail_data else None
        build = included.get(("builds", build_data["id"])) if build_data else None
        yield {
            "platform": platform,
            "version": attributes.get("versionString"),
            "state": attributes.get("appStoreState"),
            "version_id": version["id"],
            "review_detail_id": detail_id,
            "build_number": build.get("attributes", {}).get("version") if build else None,
        }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["status", "write-notes"])
    parser.add_argument("--platform", choices=["IOS", "MAC_OS"])
    parser.add_argument("--notes-file", type=Path)
    args = parser.parse_args()
    token = token_from_environment()
    entries = list(versions(token))
    if args.command == "status":
        for entry in entries:
            detail_id = entry["review_detail_id"]
            notes_length = None
            if detail_id:
                detail = api_request(token, "GET", f"/appStoreReviewDetails/{detail_id}")
                notes_length = len(detail["data"]["attributes"].get("notes") or "")
            print(f"{entry['platform']} {entry['version']}: {entry['state']}; "
                  f"build={entry['build_number']}; detail={detail_id}; notes_length={notes_length}")
        return
    if not args.platform or not args.notes_file:
        parser.error("write-notes requires --platform and --notes-file")
    candidates = [entry for entry in entries if entry["platform"] == args.platform]
    if not candidates:
        raise RuntimeError(f"No {args.platform} App Store version")
    target = sorted(candidates, key=lambda entry: entry["version"], reverse=True)[0]
    detail_id = target["review_detail_id"]
    if not detail_id:
        raise RuntimeError(f"{args.platform} version has no App Review detail")
    notes = args.notes_file.read_text(encoding="utf-8")
    body = {"data": {"type": "appStoreReviewDetails", "id": detail_id,
                     "attributes": {"notes": notes}}}
    api_request(token, "PATCH", f"/appStoreReviewDetails/{detail_id}", body)
    verify = api_request(token, "GET", f"/appStoreReviewDetails/{detail_id}")
    if verify["data"]["attributes"].get("notes") != notes:
        raise RuntimeError("App Review notes did not match after update")
    print(f"Updated {args.platform} App Review notes for version {target['version']}")


if __name__ == "__main__":
    main()
