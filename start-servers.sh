#!/bin/bash

# Project directory (hard-coded for Windows execution)
PROJECT_DIR="/mnt/c/Users/llew/Documents/GitHub local/sticker-dream"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Process IDs
VITE_PID=""
SERVER_PID=""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down servers...${NC}"

    # Kill process trees (parent + all children)
    if [ ! -z "$VITE_PID" ] && kill -0 $VITE_PID 2>/dev/null; then
        echo -e "${BLUE}[VITE]${NC} Stopping Vite dev server (PID: $VITE_PID)..."
        # Kill the entire process group
        pkill -P $VITE_PID 2>/dev/null
        kill -TERM $VITE_PID 2>/dev/null
    fi

    if [ ! -z "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "${GREEN}[SERVER]${NC} Stopping backend server (PID: $SERVER_PID)..."
        # Kill the entire process group
        pkill -P $SERVER_PID 2>/dev/null
        kill -TERM $SERVER_PID 2>/dev/null
    fi

    # Wait for processes to exit gracefully (max 5 seconds)
    local count=0
    while [ $count -lt 50 ]; do
        local running=0
        if [ ! -z "$VITE_PID" ] && kill -0 $VITE_PID 2>/dev/null; then
            running=1
        fi
        if [ ! -z "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
            running=1
        fi

        if [ $running -eq 0 ]; then
            break
        fi

        sleep 0.1
        count=$((count + 1))
    done

    # Force kill if still running (including children)
    if [ ! -z "$VITE_PID" ]; then
        pkill -9 -P $VITE_PID 2>/dev/null
        kill -9 $VITE_PID 2>/dev/null
    fi

    if [ ! -z "$SERVER_PID" ]; then
        pkill -9 -P $SERVER_PID 2>/dev/null
        kill -9 $SERVER_PID 2>/dev/null
    fi

    # Also kill any remaining node processes on the specific ports as a fallback
    lsof -ti:7767 | xargs -r kill -9 2>/dev/null
    lsof -ti:3000 | xargs -r kill -9 2>/dev/null

    echo -e "${YELLOW}Servers stopped. Goodbye!${NC}"
    exit 0
}

# Trap signals for cleanup
trap cleanup SIGINT SIGTERM EXIT

# Function to prefix output
prefix_output() {
    local prefix="$1"
    local color="$2"
    while IFS= read -r line; do
        echo -e "${color}${prefix}${NC} $line"
    done
}

# Change to project directory
cd "$PROJECT_DIR" || {
    echo -e "${RED}Error: Could not change to project directory: $PROJECT_DIR${NC}"
    exit 1
}

# Load NVM and use Node 22
export NVM_DIR=$HOME/.nvm
source $NVM_DIR/nvm.sh
nvm use 22

# Check if npm/pnpm is available
if command -v pnpm &> /dev/null; then
    PKG_MANAGER="pnpm"
elif command -v npm &> /dev/null; then
    PKG_MANAGER="npm"
else
    echo -e "${RED}Error: Neither npm nor pnpm found${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting servers...${NC}"
echo -e "${YELLOW}Press 'q' or ESC to stop both servers${NC}\n"

# Start Vite dev server
$PKG_MANAGER run dev 2>&1 | prefix_output "[VITE]" "$BLUE" &
VITE_PID=$!

# Start backend server
$PKG_MANAGER run server 2>&1 | prefix_output "[SERVER]" "$GREEN" &
SERVER_PID=$!

# Monitor key presses using read with timeout
while true; do
    # Check if processes are still running
    if ! kill -0 $VITE_PID 2>/dev/null && ! kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "\n${RED}Both servers have stopped${NC}"
        break
    fi

    # Read with timeout (non-blocking)
    if read -t 0.1 -n 1 key 2>/dev/null; then
        # Check for 'q' or Ctrl+C
        if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            cleanup
        fi
    fi
done

# Restore terminal and cleanup
cleanup
