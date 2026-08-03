#!/usr/bin/env python3
"""
VUC License Guardian — Phone-Home + Hardware-Bound + Self-Destruct
====================================================================
- Verifies license authenticity against license server
- Binds to hardware ID (SHA-256 of hostname + CPU + MAC + architecture)
- If offline > 72 hours without successful check-in: corrupts the binary
- Flags unauthorized distribution (same license on multiple machines)
- Tamper detection: SHA-256 binary hash check on startup
- Freemium enforcement: 100MB limit, basic backends only
"""

import os, sys, hashlib, json, time, subprocess, platform, uuid, shutil
from pathlib import Path
from datetime import datetime, timedelta

# ═══════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════

APP_ROOT = Path(__file__).resolve().parent.parent
LICENSE_SERVER = "https://license.fractalresonance.grand/api/v1/verify"
MAX_OFFLINE_HOURS = 72  # 3 days offline → self-destruct
STATE_FILE = APP_ROOT / "config" / ".license_state"
BINARY_PATH = APP_ROOT / "bin" / "vlzx"
INTEGRITY_FILE = APP_ROOT / "config" / "integrity.sha256"
LICENSE_KEY_FILE = APP_ROOT / "config" / "license.key"
WATERMARK = b"VUC:LICENSED:FRG:2026"  # Embedded in every compressed file header


# ═══════════════════════════════════════════════════════
# HARDWARE ID
# ═══════════════════════════════════════════════════════

def get_hardware_id():
    """Generate unique hardware fingerprint."""
    info = (
        platform.node() +
        platform.processor() +
        str(uuid.getnode()) +
        platform.machine()
    )
    return hashlib.sha256(info.encode()).hexdigest()[:32]


# ═══════════════════════════════════════════════════════
# TAMPER DETECTION
# ═══════════════════════════════════════════════════════

def verify_integrity():
    """Check if the binary has been tampered with."""
    if not BINARY_PATH.exists():
        print("[GUARDIAN] Binary not found — integrity fail")
        return False
    
    if not INTEGRITY_FILE.exists():
        print("[GUARDIAN] No integrity file — first run or tampered")
        return True  # First run, allow
    
    current_hash = hashlib.sha256(BINARY_PATH.read_bytes()).hexdigest()
    expected_hash = ""
    with open(INTEGRITY_FILE) as f:
        for line in f:
            if "vlzx:" in line:
                expected_hash = line.split(":")[1].strip()
    
    if current_hash != expected_hash:
        print("[GUARDIAN] ⚠️ BINARY HASH MISMATCH — TAMPER DETECTED")
        return False
    
    return True


# ═══════════════════════════════════════════════════════
# PHONE HOME — LICENSE VERIFICATION
# ═══════════════════════════════════════════════════════

def phone_home():
    """Call the license server to verify this installation."""
    import urllib.request, urllib.error
    
    hw_id = get_hardware_id()
    
    # Check if license key exists
    license_data = None
    if LICENSE_KEY_FILE.exists():
        with open(LICENSE_KEY_FILE) as f:
            license_data = json.load(f)
    
    payload = json.dumps({
        "hardware_id": hw_id,
        "version": "1.0.0",
        "license_key": license_data.get("signature", "") if license_data else "",
        "timestamp": datetime.utcnow().isoformat(),
    }).encode()
    
    try:
        req = urllib.request.Request(
            LICENSE_SERVER,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        resp = urllib.request.urlopen(req, timeout=10)
        result = json.loads(resp.read())
        
        # Update state
        save_state({
            "last_checkin": datetime.utcnow().isoformat(),
            "tier": result.get("tier", "freemium"),
            "status": result.get("status", "ok"),
            "hardware_id": hw_id,
        })
        
        return result.get("tier", "freemium")
        
    except Exception as e:
        print(f"[GUARDIAN] Phone-home failed: {e}")
        return check_offline_state()


# ═══════════════════════════════════════════════════════
# OFFLINE GRACE PERIOD — SELF-DESTRUCT
# ═══════════════════════════════════════════════════════

def save_state(state):
    """Save license state to encrypted file."""
    data = json.dumps(state).encode()
    # Simple XOR obfuscation (not crypto, just obfuscation)
    key = hashlib.sha256(get_hardware_id().encode()).digest()
    obfuscated = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
    STATE_FILE.write_bytes(obfuscated)

def load_state():
    """Load license state."""
    if not STATE_FILE.exists():
        return None
    try:
        data = STATE_FILE.read_bytes()
        key = hashlib.sha256(get_hardware_id().encode()).digest()
        decoded = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
        return json.loads(decoded)
    except:
        return None

def check_offline_state():
    """Check if we've been offline too long. If so, self-destruct."""
    state = load_state()
    if not state:
        return "freemium"  # First run, no state
    
    last_checkin = datetime.fromisoformat(state.get("last_checkin", "2000-01-01"))
    hours_offline = (datetime.utcnow() - last_checkin).total_seconds() / 3600
    
    if hours_offline > MAX_OFFLINE_HOURS:
        print(f"[GUARDIAN] ⚠️ OFFLINE {hours_offline:.0f}h — EXCEEDS {MAX_OFFLINE_HOURS}h LIMIT")
        print("[GUARDIAN] Self-destruct initiated...")
        self_destruct()
        return "freemium"
    
    print(f"[GUARDIAN] Offline {hours_offline:.1f}h — grace until {MAX_OFFLINE_HOURS - hours_offline:.1f}h remaining")
    return state.get("tier", "freemium")


# ═══════════════════════════════════════════════════════
# WATERMARK EMBEDDING
# ═══════════════════════════════════════════════════════

def embed_watermark(compressed_data):
    """Embed a licensing watermark in the compressed file."""
    # Watermark goes after the 4-byte magic + 4-byte size header
    # Format: VUC magic (4B) + size (4B) + watermark (16B) + data
    if len(compressed_data) < 8:
        return compressed_data
    
    magic = compressed_data[:4]
    header = compressed_data[4:8]
    rest = compressed_data[8:]
    
    # Check if watermark already present
    if len(compressed_data) >= 24 and compressed_data[8:24] == WATERMARK[:16]:
        return compressed_data
    
    return magic + header + WATERMARK[:16] + rest

def verify_watermark(compressed_data):
    """Check if the file has a valid VUC watermark."""
    if len(compressed_data) < 24:
        return False
    return compressed_data[8:24] == WATERMARK[:16]


# ═══════════════════════════════════════════════════════
# SELF-DESTRUCT
# ═══════════════════════════════════════════════════════

def self_destruct():
    """Corrupt the binary to prevent unauthorized use."""
    if not BINARY_PATH.exists():
        return
    
    # 1. Overwrite with zeros
    size = BINARY_PATH.stat().st_size
    BINARY_PATH.write_bytes(b"\x00" * size)
    
    # 2. Delete license files
    for f in [LICENSE_KEY_FILE, STATE_FILE, INTEGRITY_FILE]:
        if f.exists():
            f.unlink()
    
    # 3. Leave a warning
    (APP_ROOT / "config" / "WARNING.txt").write_text(
        "[VUC LICENSE VIOLATION]\n"
        "This installation has been deactivated.\n"
        "Offline grace period exceeded or tamper detected.\n"
        "Contact galaxys9bjw@gmail.com to restore.\n"
    )
    
    print("[GUARDIAN] Self-destruct complete. Binary corrupted.")
    sys.exit(1)


# ═══════════════════════════════════════════════════════
# FREEMIUM ENFORCEMENT
# ═══════════════════════════════════════════════════════

def enforce_freemium(input_file=None, backend="vlzx"):
    """Enforce freemium limits."""
    tier = check_offline_state() or "freemium"
    
    if tier == "enterprise":
        return True
    
    # Freemium checks
    if input_file and Path(input_file).exists():
        size_mb = Path(input_file).stat().st_size / (1024 * 1024)
        if size_mb > 100:
            print(f"[FREEMIUM] File too large ({size_mb:.0f}MB > 100MB limit)")
            return False
    
    # Restrict backends
    allowed = {"vrle", "vlzr", "passthrough"}
    if backend.lower() not in allowed:
        print(f"[FREEMIUM] Backend '{backend}' not available in freemium tier")
        print(f"[FREEMIUM] Available: {', '.join(sorted(allowed))}")
        return False
    
    return True


# ═══════════════════════════════════════════════════════
# DISTRIBUTION DETECTION
# ═══════════════════════════════════════════════════════

def check_distribution():
    """Check if this license is being used on unauthorized machines."""
    state = load_state()
    if not state:
        return
    
    hw_id = get_hardware_id()
    stored_hw = state.get("hardware_id", "")
    
    if stored_hw and hw_id != stored_hw:
        print(f"[GUARDIAN] ⚠️ LICENSE MOVED TO DIFFERENT HARDWARE")
        print(f"[GUARDIAN] Stored: {stored_hw[:16]}... Current: {hw_id[:16]}...")
        
        # Phone home to report
        try:
            import urllib.request
            payload = json.dumps({
                "event": "hardware_mismatch",
                "original_hw": stored_hw,
                "current_hw": hw_id,
                "timestamp": datetime.utcnow().isoformat(),
            }).encode()
            req = urllib.request.Request(
                "https://license.fractalresonance.grand/api/v1/report",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            urllib.request.urlopen(req, timeout=5)
        except:
            pass
        
        # Initiate self-destruct on unauthorized redistribution
        self_destruct()


# ═══════════════════════════════════════════════════════
# MAIN — Run at app startup
# ═══════════════════════════════════════════════════════

def guardian_startup():
    """Called when the VUC app starts. Verifies everything."""
    print("[GUARDIAN] VUC License Guardian v1.0")
    
    # 1. Check integrity
    if not verify_integrity():
        print("[GUARDIAN] Tamper detected — aborting")
        sys.exit(1)
    
    # 2. Check distribution
    check_distribution()
    
    # 3. Phone home or check offline state
    tier = phone_home()
    
    # 4. Update last checkin
    state = load_state()
    if state:
        state["last_checkin"] = datetime.utcnow().isoformat()
        save_state(state)
    
    print(f"[GUARDIAN] Tier: {tier.upper()} — Ready")
    return tier


if __name__ == "__main__":
    guardian_startup()