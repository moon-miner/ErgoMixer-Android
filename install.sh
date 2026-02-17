#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#   ErgoMixer -- Termux Installer for Android
#   https://github.com/moon-miner/ErgoMixer-Android
# ============================================================
#
# Paste into Termux to install:
#   curl -fsSL https://raw.githubusercontent.com/moon-miner/ErgoMixer-Android/refs/heads/main/install.sh | bash

set -euo pipefail

# -- Colors ---------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -- Config ---------------------------------------------------
# Update ERGOMIXER_VERSION when a new release is published
ERGOMIXER_VERSION="4.4.2"
JAVA_PKG="openjdk-21"
INSTALL_DIR="$HOME/ergoMixer"
JAR_PATH="$INSTALL_DIR/ergoMixer.jar"
LAUNCHER="$HOME/start-mixer.sh"
BOOT_SCRIPT="$HOME/.termux/boot/start-ergomixer.sh"
BASHRC="$HOME/.bashrc"
# Note: this project's GitHub releases do NOT use a 'v' prefix
JAR_URL="https://github.com/ergoMixer/ergoMixBack/releases/download/${ERGOMIXER_VERSION}/ergoMixer-${ERGOMIXER_VERSION}.jar"
MIN_JAR_BYTES=50000000

# -- Helpers --------------------------------------------------
step() { echo -e "\n${CYAN}[->]${NC} ${BOLD}$*${NC}"; }
ok()   { echo -e "${GREEN}[v]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
ask()  { echo -e "${YELLOW}[?]${NC} $*"; }
dim()  { echo -e "${DIM}    $*${NC}"; }
fail() { echo -e "\n${RED}[X] ERROR:${NC} $*\n"; exit 1; }

# -- Banner ---------------------------------------------------
clear
echo -e "${CYAN}${BOLD}"
echo " ███████╗██████╗  ██████╗  ██████╗"
echo " ██╔════╝██╔══██╗██╔════╝ ██╔═══██╗"
echo " █████╗  ██████╔╝██║  ███╗██║   ██║"
echo " ██╔══╝  ██╔══██╗██║   ██║██║   ██║"
echo " ███████╗██║  ██║╚██████╔╝╚██████╔╝"
echo " ╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝"
echo ""
echo " ██╗   ██╗██╗██╗  ██╗███████╗██████╗"
echo " ███╗ ███║██║╚██╗██╔╝██╔════╝██╔══██╗"
echo " ██╔████╔██║██║ ╚███╔╝ █████╗ ██████╔╝"
echo " ██║╚██╔╝██║██║ ██╔██╗ ██╔══╝ ██╔══██╗"
echo " ██║ ╚═╝ ██║██║██╔╝ ██╗███████╗██║  ██║"
echo " ╚═╝     ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e " ${BOLD}Android Installer via Termux${NC}  ${DIM}v${ERGOMIXER_VERSION}${NC}"
echo -e " ${DIM}--------------------------------------${NC}"
echo ""

# -- Play Store notice ----------------------------------------
warn "Termux from the Play Store may have outdated packages."
warn "If you hit issues, reinstall Termux from F-Droid: https://f-droid.org"
echo ""
ask  "Press Enter to continue (Ctrl+C to cancel)..."
read -r _

# -- Step 1: Storage permission -------------------------------
step "Requesting storage permission..."
termux-setup-storage 2>/dev/null || warn "Could not request storage permission — continuing"
sleep 2
ok "Done (accept the Android popup if it appeared)"

# -- Step 2: Update package list ------------------------------
step "Updating package list..."
DEBIAN_FRONTEND=noninteractive pkg update -y \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" 2>/dev/null \
    || warn "Could not update repos — continuing with current package list"
ok "Package list updated"

# -- Step 3: Ensure curl is available -------------------------
step "Checking for curl..."
if ! command -v curl &>/dev/null; then
    pkg install -y curl 2>/dev/null \
        || fail "Could not install curl. Check your internet connection."
fi
ok "curl is ready"

# -- Step 4: Install OpenJDK 21 ------------------------------
step "Installing ${JAVA_PKG}..."
dim "Termux repos have openjdk-21 and openjdk-25. Using 21 for stability."

if command -v java &>/dev/null; then
    EXISTING_JAVA=$(java -version 2>&1 | head -1)
    warn "Java already installed: ${EXISTING_JAVA}"
    ask  "Reinstall / upgrade ${JAVA_PKG}? (y/N):"
    read -r REINSTALL_JAVA
    if [[ "${REINSTALL_JAVA:-n}" =~ ^[Yy]$ ]]; then
        pkg install -y "${JAVA_PKG}" 2>/dev/null \
            || fail "Could not install ${JAVA_PKG}. Try manually: pkg install ${JAVA_PKG}"
    else
        ok "Keeping existing Java"
    fi
else
    pkg install -y "${JAVA_PKG}" 2>/dev/null \
        || fail "Could not install ${JAVA_PKG}. Try manually: pkg install ${JAVA_PKG}"
fi

command -v java &>/dev/null \
    || fail "java not found after install. Try: pkg install ${JAVA_PKG}"

JAVA_VER=$(java -version 2>&1 | head -1)
ok "Java ready — ${JAVA_VER}"

# -- Step 5: Create install directory -------------------------
step "Preparing install directory..."
mkdir -p "${INSTALL_DIR}"
ok "Directory: ${INSTALL_DIR}"

# -- Step 6: Download ErgoMixer JAR --------------------------
step "Downloading ErgoMixer v${ERGOMIXER_VERSION}..."
dim "${JAR_URL}"
echo ""

do_download() {
    curl -fL \
        --progress-bar \
        --retry 3 \
        --retry-delay 3 \
        --output "${JAR_PATH}" \
        "${JAR_URL}" \
        || fail "Download failed.\nURL: ${JAR_URL}\nCheck your internet connection."
}

if [ -f "${JAR_PATH}" ]; then
    warn "JAR already exists ($(du -h "${JAR_PATH}" | cut -f1))"
    ask  "Overwrite with v${ERGOMIXER_VERSION}? (y/N):"
    read -r OVERWRITE
    if [[ "${OVERWRITE:-n}" =~ ^[Yy]$ ]]; then
        do_download
    else
        ok "Keeping existing JAR"
    fi
else
    do_download
fi

ACTUAL_BYTES=$(wc -c < "${JAR_PATH}" 2>/dev/null || echo 0)
if [ "${ACTUAL_BYTES}" -lt "${MIN_JAR_BYTES}" ]; then
    rm -f "${JAR_PATH}"
    fail "File too small after download (${ACTUAL_BYTES} bytes).\nLikely a network or URL issue. Run the installer again."
fi
ok "JAR verified — $(du -h "${JAR_PATH}" | cut -f1)"

# -- Step 7: Create launcher script --------------------------
step "Creating launcher script..."

# Single-quoted heredoc: $HOME, $PORT expand at runtime
cat > "${LAUNCHER}" << 'LAUNCH_EOF'
#!/data/data/com.termux/files/usr/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

JAR="$HOME/ergoMixer/ergoMixer.jar"
PID_FILE="$HOME/ergoMixer/mixer.pid"
LOG="$HOME/ergoMixer/mixer.log"
PORT=9000
OPEN_URL="http://localhost:${PORT}/dashboard/mix/active"

if [ ! -f "$JAR" ]; then
    echo -e "${RED}[X]${NC} JAR not found at: $JAR"
    echo -e "    Run the installer again to re-download it."
    exit 1
fi

# -- Stop mode -----------------------------------------------
if [[ "${1:-}" == "stop" ]]; then
    STOPPED=0
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            rm -f "$PID_FILE"
            echo -e "${GREEN}[v]${NC} ErgoMixer stopped (PID $PID)."
            STOPPED=1
        fi
    fi
    if [ "$STOPPED" -eq 0 ]; then
        # Fallback: kill by process name
        pkill -f "ergoMixer.jar" 2>/dev/null &&             echo -e "${GREEN}[v]${NC} ErgoMixer stopped." ||             echo -e "${YELLOW}[!]${NC} ErgoMixer was not running."
        rm -f "$PID_FILE"
    fi
    exit 0
fi

clear
echo ""
echo -e "${CYAN}${BOLD}  ErgoMixer${NC}"
echo ""
echo -e "  ${BOLD}URL:${NC}    ${GREEN}${OPEN_URL}${NC}"
echo -e "  ${BOLD}Stop:${NC}   Ctrl+C  or  mixer stop"
echo -e "  ${BOLD}Logs:${NC}   tail -f ~/ergoMixer/mixer.log"
echo ""
echo -e "  ${DIM}Starting... browser opens when ready${NC}"
echo ""

# Start mixer, redirect ALL output to log file — keeps terminal clean
java \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.lang.reflect=ALL-UNNAMED \
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens java.base/java.util=ALL-UNNAMED \
    --add-opens java.base/java.util.concurrent=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.file=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.ftp=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.http=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.https=ALL-UNNAMED \
    --add-opens java.base/sun.security.ssl=ALL-UNNAMED \
    -Dhttp.port="${PORT}" \
    -Dplay.filters.hosts.allowed.0=localhost \
    -Dplay.filters.hosts.allowed.1=127.0.0.1 \
    -Dplay.http.filters="filters.CorsFilters" \
    -jar "$JAR" >> "$LOG" 2>&1 &

MIXER_PID=$!
echo $MIXER_PID > "$PID_FILE"

# Wait until server responds, then open browser
echo -ne "  Waiting for server"
READY=0
for i in $(seq 1 30); do
    sleep 2
    echo -ne "."
    if curl -sf "http://localhost:${PORT}" -o /dev/null 2>/dev/null; then
        READY=1
        break
    fi
done
echo ""

if [ "$READY" -eq 1 ]; then
    echo -e "  ${GREEN}[v]${NC} Ready! Opening browser..."
    termux-open-url "${OPEN_URL}"
else
    echo -e "  ${YELLOW}[!]${NC} Server taking long — open manually: ${OPEN_URL}"
fi

echo ""
echo -e "  ${DIM}PID: ${MIXER_PID}  |  Ctrl+C  |  mixer stop  |  kill ${MIXER_PID}${NC}"
echo ""

# Trap Ctrl+C to stop cleanly
trap 'echo -e "\n  Stopping..."; kill "$MIXER_PID" 2>/dev/null; rm -f "$PID_FILE"; echo -e "  ${GREEN}[v]${NC} Stopped."; exit 0' INT TERM

# Keep terminal alive showing status, not log spam
wait "$MIXER_PID" 2>/dev/null || true
rm -f "$PID_FILE"
echo -e "\n${YELLOW}[!]${NC} ErgoMixer stopped."
LAUNCH_EOF

chmod +x "${LAUNCHER}"
ok "Launcher: ~/start-mixer.sh"

# -- Step 8: Optional autostart via Termux:Boot --------------
step "Autostart on phone reboot (optional)"
dim "Requires Termux:Boot from F-Droid: https://f-droid.org/packages/com.termux.boot/"
echo ""
ask  "Enable autostart? (y/N):"
read -r AUTOSTART

if [[ "${AUTOSTART:-n}" =~ ^[Yy]$ ]]; then
    mkdir -p "$(dirname "${BOOT_SCRIPT}")"

    # Single-quoted: vars expand at runtime inside the boot script
    cat > "${BOOT_SCRIPT}" << 'BOOT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Runs on device boot via Termux:Boot

JAR="$HOME/ergoMixer/ergoMixer.jar"
LOG="$HOME/ergoMixer/mixer.log"
PID_FILE="$HOME/ergoMixer/mixer.pid"

sleep 20

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
fi

java \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.lang.reflect=ALL-UNNAMED \
    --add-opens java.base/java.lang.invoke=ALL-UNNAMED \
    --add-opens java.base/java.util=ALL-UNNAMED \
    --add-opens java.base/java.util.concurrent=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.file=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.ftp=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.http=ALL-UNNAMED \
    --add-opens java.base/sun.net.www.protocol.https=ALL-UNNAMED \
    --add-opens java.base/sun.security.ssl=ALL-UNNAMED \
    -Dhttp.port=9000 \
    -Dplay.filters.hosts.allowed.0=localhost \
    -Dplay.filters.hosts.allowed.1=127.0.0.1 \
    -Dplay.http.filters="filters.CorsFilters" \
    -jar "$JAR" \
    >> "$LOG" 2>&1 &

echo $! > "$PID_FILE"
BOOT_EOF

    chmod +x "${BOOT_SCRIPT}"
    ok "Autostart: ~/.termux/boot/start-ergomixer.sh"
    warn "Termux:Boot must be installed from F-Droid for this to work."
else
    ok "Autostart skipped"
fi

# -- Step 9: Shell aliases ------------------------------------
step "Adding shell aliases..."

# 'mixer'      -> start
# 'mixer stop' -> stop
if ! grep -qF "alias mixer=" "${BASHRC}" 2>/dev/null; then
    {
        echo ""
        echo "# ErgoMixer"
        echo "alias mixer='bash \$HOME/start-mixer.sh'"
        echo "alias mixer-stop='bash \$HOME/start-mixer.sh stop'"
    } >> "${BASHRC}"
    ok "Aliases added to ~/.bashrc"
else
    ok "Alias 'mixer' already exists in ~/.bashrc"
fi

# -- Done -----------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}  +==========================================+${NC}"
echo -e "${GREEN}${BOLD}  |    Installation complete!               |${NC}"
echo -e "${GREEN}${BOLD}  +==========================================+${NC}"
echo ""
echo -e "  ${BOLD}Start:${NC}  ${CYAN}mixer${NC}"
echo -e "  ${BOLD}Stop:${NC}   ${CYAN}mixer stop${NC}  ${DIM}(or Ctrl+C)${NC}"
echo ""
echo -e "  ${BOLD}URL:${NC}    ${GREEN}http://localhost:9000${NC}"
echo -e "         ${DIM}(browser opens automatically on start)${NC}"
echo ""
echo -e "  ${DIM}JAR:      ~/ergoMixer/ergoMixer.jar${NC}"
echo -e "  ${DIM}Database: ~/ergoMixer/*.db  <- back this up!${NC}"
echo ""

ask "Start ErgoMixer now? (y/N):"
read -r START_NOW
if [[ "${START_NOW:-n}" =~ ^[Yy]$ ]]; then
    echo ""
    exec bash "${LAUNCHER}"
fi

echo ""
echo -e "${DIM}  Type 'mixer' anytime to start. Goodbye!${NC}"
echo ""
