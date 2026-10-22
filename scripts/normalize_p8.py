#!/usr/bin/env python3
"""Turns the ASC_KEY_P8 secret into a proper AuthKey .p8 (PEM) file, whatever way it
was pasted into GitHub:
  - the raw file contents (-----BEGIN PRIVATE KEY----- ...)
  - the same with literal "\\n" instead of line breaks, or with surrounding quotes
  - base64 of the whole file
  - only the key body (the base64 lines between the BEGIN/END lines)
Prints only non-secret diagnostics. Usage: normalize_p8.py OUTPUT_PATH  (reads $ASC_KEY_P8)
"""
import base64
import binascii
import os
import re
import sys

HEADER, FOOTER = "-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"


def pem_from_body(body: str) -> str:
    body = re.sub(r"\s+", "", body)
    return HEADER + "\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64)) + "\n" + FOOTER + "\n"


def from_pem_text(text: str):
    m = re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY-----(.*?)-----END [A-Z ]*PRIVATE KEY-----", text, re.S)
    if not m:
        return None
    body = m.group(1)
    try:
        der = base64.b64decode(re.sub(r"\s+", "", body), validate=True)
    except (binascii.Error, ValueError):
        return None
    return pem_from_body(body) if der[:1] == b"\x30" else None


def normalize(raw: str):
    text = raw.strip().strip('"').strip("'").replace("\\n", "\n").replace("\r", "")
    pem = from_pem_text(text)
    if pem:
        return pem, "PEM text"
    compact = re.sub(r"\s+", "", text)
    try:
        decoded = base64.b64decode(compact + "=" * (-len(compact) % 4), validate=True)
    except (binascii.Error, ValueError):
        return None, "not PEM and not base64"
    if decoded[:1] == b"\x30" and len(decoded) > 60:
        return pem_from_body(base64.b64encode(decoded).decode()), "bare key body (no BEGIN/END lines)"
    try:
        inner = decoded.decode("utf-8")
    except UnicodeDecodeError:
        return None, "base64 that is not a key"
    pem = from_pem_text(inner.replace("\\n", "\n"))
    return (pem, "base64 of the .p8 file") if pem else (None, "base64 of something that is not a .p8 key")


def main():
    raw = os.environ.get("ASC_KEY_P8", "")
    print(f"ASC_KEY_P8: {len(raw)} chars, {raw.count(chr(10)) + 1} lines, contains BEGIN: {'BEGIN' in raw}")
    pem, kind = normalize(raw)
    if not pem:
        print(f"Could not read ASC_KEY_P8 ({kind}). Paste the full contents of AuthKey_XXXX.p8 into the secret.")
        sys.exit(1)
    with open(sys.argv[1], "w") as f:
        f.write(pem)
    os.chmod(sys.argv[1], 0o600)
    print(f"API key recognized as: {kind}")


if __name__ == "__main__":
    main()
