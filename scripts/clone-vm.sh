#!/usr/bin/env bash
# clone-vm.sh — Idempotent clone of the 'openclaw' VM for agent fleet testing
#
# Usage (run as root on fileserver):
#   bash clone-vm.sh
#
# What it does:
#   1. Checks if the clone already exists — skips steps that are already done
#   2. Clones the disk image
#   3. Creates a new VM definition (new UUID, new name, new disk)
#   4. Boots the VM and patches the IP to 10.10.0.70
#
# Idempotent: safe to run multiple times.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SOURCE_VM="openclaw"
CLONE_VM="openclaw-test"
CLONE_IP="10.10.0.70"
GATEWAY="10.10.0.1"
DNS="10.10.0.1"
INTERFACE="enp1s0"
DISK_DIR="/mnt/par-assembly/virtclaw"
CLONE_DISK="${DISK_DIR}/openclaw-test.qcow2"
NETCFG_REMOTE="/etc/network/interfaces"
SSH_KEY="${HOME}/.ssh/openclaw-fileserver"
SSH_USER="ludite"
# ─────────────────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root."
command -v virsh    >/dev/null || die "virsh not found."
command -v qemu-img >/dev/null || die "qemu-img not found."
command -v uuidgen  >/dev/null || die "uuidgen not found."
command -v xmllint  >/dev/null || die "xmllint not found (apt install libxml2-utils)."

# Detect actual source disk path from live VM XML
SOURCE_DISK=$(virsh dumpxml "$SOURCE_VM" 2>/dev/null \
  | xmllint --xpath "string(//disk[@device='disk']/source/@file)" - 2>/dev/null || true)
[[ -n "$SOURCE_DISK" ]] || die "Could not detect disk path for VM '$SOURCE_VM'. Is it defined?"
info "Detected source disk: $SOURCE_DISK"

# ── Step 1: Check if clone VM already defined ─────────────────────────────────
if virsh dominfo "$CLONE_VM" &>/dev/null; then
  ok "VM '$CLONE_VM' already defined — skipping XML steps."
  SKIP_DEFINE=true
else
  SKIP_DEFINE=false
fi

# ── Step 2: Clone the disk ────────────────────────────────────────────────────
if [[ -f "$CLONE_DISK" ]]; then
  ok "Disk '$CLONE_DISK' already exists — skipping copy."
else
  info "Cloning disk: $SOURCE_DISK → $CLONE_DISK"
  [[ -f "$SOURCE_DISK" ]] || die "Source disk not found: $SOURCE_DISK — check virsh dumpxml $SOURCE_VM"

  # Pause source VM to ensure a clean disk copy
  SOURCE_STATE=$(virsh domstate "$SOURCE_VM" 2>/dev/null || echo "unknown")
  if [[ "$SOURCE_STATE" == "running" ]]; then
    info "Suspending '$SOURCE_VM' for clean disk copy..."
    virsh suspend "$SOURCE_VM"
    SUSPENDED=true
  fi

  # Full independent copy — required because SOURCE_VM is running and holds a
  # write lock on the backing file. A linked clone would conflict with it.
  qemu-img convert -f qcow2 -O qcow2 "$SOURCE_DISK" "$CLONE_DISK"

  if [[ "${SUSPENDED:-false}" == "true" ]]; then
    virsh resume "$SOURCE_VM"
    ok "Resumed '$SOURCE_VM'."
  fi

  ok "Disk cloned."
fi

# ── Step 3: Define the clone VM ───────────────────────────────────────────────
if [[ "$SKIP_DEFINE" == "false" ]]; then
  info "Exporting XML from '$SOURCE_VM'..."
  TMPXML=$(mktemp /tmp/openclaw-clone-XXXXXX.xml)
  virsh dumpxml "$SOURCE_VM" > "$TMPXML"

  NEW_UUID=$(uuidgen)

  info "Patching XML (name, UUID, disk path)..."
  # Name
  sed -i "s|<name>${SOURCE_VM}</name>|<name>${CLONE_VM}</name>|g" "$TMPXML"
  # UUID
  sed -i "s|<uuid>.*</uuid>|<uuid>${NEW_UUID}</uuid>|g" "$TMPXML"
  # Disk path — use detected SOURCE_DISK, not a hardcoded name
  sed -i "s|${SOURCE_DISK}|${CLONE_DISK}|g" "$TMPXML"
  # Remove runtime state that shouldn't carry over
  sed -i '/<seclabel/,/\/seclabel>/d' "$TMPXML"
  # Remove hardcoded macvtap target — libvirt will assign a new one (macvtap1 etc.)
  sed -i '/<target dev=.macvtap/d' "$TMPXML"
  # Remove portid — each VM needs a unique port on the network
  sed -i 's/ portid="[^"]*"//' "$TMPXML"
  # Randomize MAC address to avoid collision
  NEW_MAC=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  sed -i "s|<mac address='[^']*'/>|<mac address='${NEW_MAC}'/>|g" "$TMPXML"

  info "Defining clone VM '$CLONE_VM'..."
  virsh define "$TMPXML"
  rm -f "$TMPXML"
  ok "VM '$CLONE_VM' defined."
else
  info "VM already defined — skipping define step."
fi

# ── Step 3b: If clone disk was a linked clone (old run), recreate it ─────────
# Detect if existing disk has a backing file (linked clone) and replace it
if [[ -f "$CLONE_DISK" ]]; then
  BACKING=$(qemu-img info "$CLONE_DISK" 2>/dev/null | grep "backing file:" | awk '{print $3}' || true)
  if [[ -n "$BACKING" ]]; then
    warn "Existing clone disk is a linked clone (backing: $BACKING) — replacing with full copy."
    rm -f "$CLONE_DISK"
    SOURCE_STATE=$(virsh domstate "$SOURCE_VM" 2>/dev/null || echo "unknown")
    if [[ "$SOURCE_STATE" == "running" ]]; then
      info "Suspending '$SOURCE_VM' for clean disk copy..."
      virsh suspend "$SOURCE_VM"
      SUSPENDED=true
    fi
    qemu-img convert -f qcow2 -O qcow2 "$SOURCE_DISK" "$CLONE_DISK"
    if [[ "${SUSPENDED:-false}" == "true" ]]; then
      virsh resume "$SOURCE_VM"
      ok "Resumed '$SOURCE_VM'."
    fi
    ok "Disk replaced with full independent copy."
  fi
fi

# ── Step 4: Start the clone VM ────────────────────────────────────────────────
CLONE_STATE=$(virsh domstate "$CLONE_VM" 2>/dev/null || echo "unknown")
if [[ "$CLONE_STATE" == "running" ]]; then
  ok "VM '$CLONE_VM' already running."
else
  info "Starting '$CLONE_VM'..."
  virsh start "$CLONE_VM"
  info "Waiting 20s for VM to boot..."
  sleep 20
  ok "VM started."
fi

# ── Step 5: Patch the IP inside the VM ───────────────────────────────────────
# Get current IP of the clone (it'll boot with the old IP initially)
# We use virsh console or ssh into the OLD IP then immediately change it.

CURRENT_IP="10.10.0.195"  # source VM IP — clone starts with this

info "Connecting to VM at $CURRENT_IP to set static IP $CLONE_IP..."

SSH_CMD="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${SSH_USER}@${CURRENT_IP}"

# Wait for SSH to be available (up to 60s)
for i in $(seq 1 12); do
  if $SSH_CMD "echo ok" &>/dev/null; then
    break
  fi
  info "Waiting for SSH... attempt $i/12"
  sleep 5
done

$SSH_CMD "echo ok" &>/dev/null || die "Could not SSH into $CURRENT_IP — VM may not be ready. Try re-running the script."

# Check if IP is already patched
LIVE_IP=$($SSH_CMD "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "")
if [[ "$LIVE_IP" == "$CLONE_IP" ]]; then
  ok "IP already set to $CLONE_IP — skipping network patch."
else
  info "Patching /etc/network/interfaces to $CLONE_IP..."
  $SSH_CMD "sudo tee ${NETCFG_REMOTE} > /dev/null << 'EOF'
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ${INTERFACE}
iface ${INTERFACE} inet static
 address ${CLONE_IP}
 netmask 255.255.255.0
 gateway ${GATEWAY}
 dns-nameservers ${DNS}
 dns-search servers.repko.ca repko.ca
EOF"

  info "Applying new network config (VM will briefly disconnect)..."
  $SSH_CMD "sudo ifdown ${INTERFACE} && sudo ifup ${INTERFACE}" || true
  sleep 3

  # Verify we can reach it on the new IP
  if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${SSH_USER}@${CLONE_IP}" "echo ok" &>/dev/null; then
    ok "VM is now reachable at $CLONE_IP."
  else
    warn "VM may need a reboot to fully apply new IP. Try: virsh reboot $CLONE_VM"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
echo "  Clone complete!"
echo "  VM name : $CLONE_VM"
echo "  IP      : $CLONE_IP"
echo "  Disk    : $CLONE_DISK"
echo ""
echo "  Next steps:"
echo "  1. SSH in:  ssh root@$CLONE_IP"
echo "  2. Clone fleet: git clone git@github.com:SilentAxis/openclaw-agent-coordinator /opt/OpenclawAgent"
echo "  3. Configure: cp /opt/OpenclawAgent/.env.example /opt/OpenclawAgent/.env && nano /opt/OpenclawAgent/.env"
echo "  4. Setup: bash /opt/OpenclawAgent/setup.sh"
echo "  5. Test:  bash /opt/OpenclawAgent/tests/run-integration-tests.sh"
echo "════════════════════════════════════════════════════"
