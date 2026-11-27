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
API_ROOT = "https://api.appstoreconnect.apple.com"
APP_ID = "6833061876"


def api_request(token, method, path, data=None):
    body = None if data is None else json.dumps(data).encode("utf-8")
    request = urllib.request.Request(
        path if path.startswith("https://") else (API_ROOT + path if path.startswith("/v2/") else API + path),
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


def configure_iap(token):
    """Create the launch Pro product, resuming safely after partial setup."""
    existing = api_request(token, "GET", f"/apps/{APP_ID}/inAppPurchasesV2?limit=200")["data"]
    matches = [item for item in existing if item["attributes"]["productId"] == "quire.pro"]
    if len(matches) > 1:
        raise RuntimeError("Multiple quire.pro products found")
    if matches:
        product = matches[0]
    else:
        body = {"data": {"type": "inAppPurchases", "attributes": {
            "name": "QuireNote Pro Lifetime", "productId": "quire.pro",
            "inAppPurchaseType": "NON_CONSUMABLE",
            "reviewNote": "Unlocks unlimited notebooks with a one-time purchase. In Settings, tap Unlock QuireNote Pro; restore is on the same screen. No account is required.",
            "familySharable": True,
        }, "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
        product = api_request(token, "POST", "/v2/inAppPurchases", body)["data"]
        print("Created QuireNote Pro non-consumable")
    product_id = product["id"]
    attrs = product["attributes"]
    if attrs["inAppPurchaseType"] != "NON_CONSUMABLE":
        raise RuntimeError("Existing quire.pro is not non-consumable")
    if not attrs.get("familySharable"):
        api_request(token, "PATCH", f"/v2/inAppPurchases/{product_id}",
                    {"data": {"type": "inAppPurchases", "id": product_id,
                              "attributes": {"familySharable": True}}})
    version_response = api_request(token, "GET", f"/v2/inAppPurchases/{product_id}/versions?limit=200")
    versions_data = version_response["data"]
    drafts = [v for v in versions_data if v["attributes"]["state"] == "PREPARE_FOR_SUBMISSION"]
    if drafts:
        version = drafts[-1]
    elif not versions_data:
        body = {"data": {"type": "inAppPurchaseVersions", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": product_id}}}}}
        version = api_request(token, "POST", "/inAppPurchaseVersions", body)["data"]
    else:
        version = versions_data[-1]
    localizations = api_request(token, "GET", f"/inAppPurchaseVersions/{version['id']}/localizations?limit=200")["data"]
    if not any(loc["attributes"]["locale"] == "en-US" for loc in localizations):
        body = {"data": {"type": "inAppPurchaseLocalizations", "attributes": {
            "locale": "en-US", "name": "QuireNote Pro Lifetime",
            "description": "Unlock unlimited notebooks with one purchase. No subscription."
        }, "relationships": {"version": {"data": {"type": "inAppPurchaseVersions", "id": version["id"]}}}}}
        api_request(token, "POST", "/v2/inAppPurchaseLocalizations", body)
        print("Added English purchase description")
    try:
        schedule = api_request(token, "GET", f"/v2/inAppPurchases/{product_id}/iapPriceSchedule")["data"]
    except RuntimeError as error:
        if "HTTP 404" not in str(error):
            raise
        schedule = None
    if not schedule:
        url = f"/v2/inAppPurchases/{product_id}/pricePoints?filter%5Bterritory%5D=USA&limit=200"
        points = []
        while url:
            page = api_request(token, "GET", url)
            points += page["data"]
            url = page.get("links", {}).get("next")
        matches = [point for point in points if point["attributes"]["customerPrice"] == "14.99"]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one USD 14.99 price point; found {len(matches)}")
        price_id = "launch-price"
        body = {"data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": product_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": price_id}]}}},
            "included": [{"type": "inAppPurchasePrices", "id": price_id,
                          "attributes": {"startDate": None}, "relationships": {
                              "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": product_id}},
                              "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": matches[0]["id"]}}}}]}
        api_request(token, "POST", "/inAppPurchasePriceSchedules", body)
        print("Set USD 14.99 launch price")
    print(f"QuireNote Pro: id={product_id}; version={version['id']}; state={version['attributes']['state']}")


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
    parser.add_argument("command", choices=["status", "write-notes", "list-builds", "select-build", "attach-demo", "list-submissions", "list-iap", "configure-iap"])
    parser.add_argument("--platform", choices=["IOS", "MAC_OS"])
    parser.add_argument("--notes-file", type=Path)
    parser.add_argument("--build-number")
    parser.add_argument("--file", type=Path)
    args = parser.parse_args()
    token = token_from_environment()
    if args.command == "configure-iap":
        configure_iap(token)
        return
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
