"""Inspect and update QuireNote review information using App Store Connect API."""

import argparse
import hashlib
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
            return {} if response.status == 204 else json.load(response)
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


def builds(token):
    query = urllib.parse.urlencode({"limit": "200"})
    response = api_request(token, "GET", f"/apps/{APP_ID}/builds?{query}")
    recent = sorted(response["data"], key=lambda item: item["attributes"].get("uploadedDate") or "", reverse=True)[:12]
    for build in recent:
        prerelease = api_request(token, "GET", f"/builds/{build['id']}/preReleaseVersion").get("data")
        yield {
            "id": build["id"],
            "number": build["attributes"].get("version"),
            "state": build["attributes"].get("processingState"),
            "platform": prerelease.get("attributes", {}).get("platform") if prerelease else None,
            "version": prerelease.get("attributes", {}).get("version") if prerelease else None,
        }


def attach_demo(token, platform, file):
    entries = [entry for entry in versions(token) if entry["platform"] == platform]
    if len(entries) != 1 or not entries[0]["review_detail_id"]:
        raise RuntimeError(f"Expected exactly one {platform} review detail")
    detail_id = entries[0]["review_detail_id"]
    size = file.stat().st_size
    if size == 0 or file.suffix.lower() != ".mp4" or "simulator" not in file.name.lower():
        raise RuntimeError("Expected a nonempty, explicitly labeled simulator MP4")
    existing = api_request(token, "GET", f"/appStoreReviewDetails/{detail_id}/appStoreReviewAttachments")
    for item in existing.get("data", []):
        attributes = item.get("attributes", {})
        if attributes.get("fileName") == file.name and attributes.get("fileSize") == size:
            print(f"Attachment already present for {platform}: {file.name}")
            return
    body = {"data": {"type": "appStoreReviewAttachments",
                     "attributes": {"fileName": file.name, "fileSize": size},
                     "relationships": {"appStoreReviewDetail": {
                         "data": {"type": "appStoreReviewDetails", "id": detail_id}}}}}
    reservation = api_request(token, "POST", "/appStoreReviewAttachments", body)["data"]
    attachment_id = reservation["id"]
    operations = reservation["attributes"]["uploadOperations"]
    if not operations:
        raise RuntimeError("Apple returned no upload operations")
    checksum = hashlib.md5()
    with file.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            checksum.update(chunk)
    with file.open("rb") as stream:
        for operation in operations:
            stream.seek(operation["offset"])
            chunk = stream.read(operation["length"])
            if len(chunk) != operation["length"]:
                raise RuntimeError("Could not read the requested video byte range")
            headers = {header["name"]: header["value"] for header in operation["requestHeaders"]}
            request = urllib.request.Request(operation["url"], data=chunk,
                                             method=operation["method"], headers=headers)
            with urllib.request.urlopen(request, timeout=180) as response:
                if response.status < 200 or response.status >= 300:
                    raise RuntimeError(f"Video part upload failed: HTTP {response.status}")
    commit = {"data": {"type": "appStoreReviewAttachments", "id": attachment_id,
                       "attributes": {"uploaded": True, "sourceFileChecksum": checksum.hexdigest()}}}
    api_request(token, "PATCH", f"/appStoreReviewAttachments/{attachment_id}", commit)
    for _ in range(30):
        status = api_request(token, "GET", f"/appStoreReviewAttachments/{attachment_id}")
        state = status["data"]["attributes"].get("assetDeliveryState", {}).get("state")
        if state == "COMPLETE":
            print(f"Attached {file.name} to {platform} App Review detail; state=COMPLETE")
            return
        if state == "FAILED":
            raise RuntimeError(f"App Review attachment processing failed: {file.name}")
        time.sleep(10)
    raise RuntimeError(f"App Review attachment did not finish processing: {file.name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["status", "write-notes", "list-builds", "select-build", "attach-demo", "list-submissions", "list-iap"])
    parser.add_argument("--platform", choices=["IOS", "MAC_OS"])
    parser.add_argument("--notes-file", type=Path)
    parser.add_argument("--build-number")
    parser.add_argument("--file", type=Path)
    args = parser.parse_args()
    token = token_from_environment()
    if args.command == "list-builds":
        for build in list(builds(token))[:12]:
            print(f"{build['platform']} {build['version']} build {build['number']}: "
                  f"{build['state']}; id={build['id']}")
        return
    if args.command == "list-submissions":
        response = api_request(token, "GET", f"/apps/{APP_ID}/reviewSubmissions?limit=200")
        for item in response["data"]:
            attrs = item["attributes"]
            print(f"{attrs.get('platform')}: {attrs.get('state')}; id={item['id']}")
        return
    if args.command == "list-iap":
        response = api_request(token, "GET", f"/apps/{APP_ID}/inAppPurchasesV2?limit=200")
        for item in response["data"]:
            attrs = item["attributes"]
            print(f"{attrs.get('productId')}: {attrs.get('state')} ({attrs.get('inAppPurchaseType')})")
        if not response["data"]:
            print("No in-app purchases configured")
        return
    if args.command == "attach-demo":
        if not args.platform or not args.file:
            parser.error("attach-demo requires --platform and --file")
        attach_demo(token, args.platform, args.file)
        return
    entries = list(versions(token))
    if args.command == "select-build":
        if not args.platform or not args.build_number:
            parser.error("select-build requires --platform and --build-number")
        candidates = [entry for entry in entries if entry["platform"] == args.platform]
        if len(candidates) != 1:
            raise RuntimeError(f"Expected exactly one {args.platform} App Store version")
        target = candidates[0]
        if target["state"] not in {"REJECTED", "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}:
            raise RuntimeError(f"Refusing to change a build while {args.platform} is {target['state']}")
        matching = [build for build in builds(token) if build["platform"] == args.platform
                    and build["version"] == "1.0.0" and build["number"] == args.build_number
                    and build["state"] == "VALID"]
        if len(matching) != 1:
            raise RuntimeError(f"Expected exactly one valid {args.platform} build {args.build_number}")
        body = {"data": {"type": "builds", "id": matching[0]["id"]}}
        api_request(token, "PATCH", f"/appStoreVersions/{target['version_id']}/relationships/build", body)
        verify = api_request(token, "GET", f"/appStoreVersions/{target['version_id']}/relationships/build")
        if verify.get("data", {}).get("id") != matching[0]["id"]:
            raise RuntimeError("Selected build did not match after update")
        print(f"Selected {args.platform} build {args.build_number} for App Store version {target['version']}")
        return
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
