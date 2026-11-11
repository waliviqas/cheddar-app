# Test helper (not part of the app): sends each saved net frame to SAM 3 on Replicate with the words
# "hockey goal frame" and saves the black-and-white mask it returns next to the clips.
import json, os, subprocess, sys, time, urllib.request
CLIPS = sys.argv[1]
OUT = os.path.join(CLIPS, "sam3-masks")
TOKEN = open(os.path.expanduser("~/.cheddar-secrets/replicate-token")).read().strip()
VERSION = "d73db077226443ba4fafd34e233b3626b552eac2a433f90c7c32a9ac89bd9e72"  # mattsays/sam3-image

def api(method, url, body=None, headers=None):
    h = {"Authorization": f"Bearer {TOKEN}"}; h.update(headers or {})
    with urllib.request.urlopen(urllib.request.Request(url, data=body, method=method, headers=h), timeout=600) as r:
        return json.load(r)

# Extra frame names (like measured-43mph-49mph) can be passed after the clips folder.
names = ["measured-" + e["clip"].split("/")[-1][:-4] for e in json.load(open(f"{CLIPS}/net-outline.json"))] + \
        [e["clip"].split("/")[-1][:-4] for e in json.load(open(f"{CLIPS}/net-corners.json"))] + sys.argv[2:]
for name in names:
    out = f"{OUT}/{name}.png"
    if os.path.exists(out): continue
    up = subprocess.run(["curl", "-s", "-H", f"Authorization: Bearer {TOKEN}", "-F", f"content=@{CLIPS}/net-frames/{name}.jpg;type=image/jpeg",
                         "https://api.replicate.com/v1/files"], capture_output=True, text=True, check=True)
    body = json.dumps({"version": VERSION, "input": {"image": json.loads(up.stdout)["urls"]["get"], "prompt": "hockey goal frame",
                                                      "mask_only": True, "return_zip": False}}).encode()
    for attempt in range(5):
        try:
            pred = api("POST", "https://api.replicate.com/v1/predictions", body, {"Content-Type": "application/json", "Prefer": "wait=60"})
            break
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            time.sleep(15)
    while pred["status"] not in ("succeeded", "failed", "canceled"):
        time.sleep(3); pred = api("GET", pred["urls"]["get"])
    if pred["status"] != "succeeded":
        print(name, "FAILED", pred.get("error")); continue
    urllib.request.urlretrieve(pred["output"], out)
    print(name, "saved")
    time.sleep(12)
