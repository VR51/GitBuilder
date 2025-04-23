#!/bin/bash

# GitBuilder - GitHub repository management and build automation tool
# Author: Cascade
# Prompt Engineer: VR51
# Version: 1.0.2
# Created: 2025-04-11
# Updated: 2025-04-15
# License: GNU General Public License v3.0
# Donate: https://paypal.me/vr51/
#
# Copyright (C) 2025 VR51
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail
IFS=$'\n\t'

# Required commands and their corresponding packages
declare -A REQUIRED_PACKAGES=(
    [sqlite3]="sqlite3"
    [curl]="curl"
    [jq]="jq"
    [git]="git"
    [make]="make"
    [cmake]="cmake"
    [file]="file"
)

# Configuration
DB_DIR="$HOME/.local/share/gitbuilder"
DB_FILE="$DB_DIR/repos.db"
SRC_DIR="$HOME/.local/share/gitbuilder/src"
GITHUB_API="https://api.github.com"

# Ensure directories exist
mkdir -p "$DB_DIR" "$SRC_DIR"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for required commands and offer to install missing ones
check_requirements() {
    local missing=0
    local missing_pkgs=()

    for cmd in "${!REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${YELLOW}Missing command: $cmd${NC}"
            missing_pkgs+=("${REQUIRED_PACKAGES[$cmd]}")
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        echo -e "\nThe following packages need to be installed:"
        printf '%s\n' "${missing_pkgs[@]}"
        read -rp "Would you like to install them now? (y/N): " choice
        
        if [[ $choice =~ ^[Yy]$ ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y "${missing_pkgs[@]}"
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "${missing_pkgs[@]}"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm "${missing_pkgs[@]}"
            else
                error "Unsupported package manager. Please install required packages manually."
            fi
        else
            error "Required packages must be installed to continue."
        fi
    fi
}

# Check for and install build dependencies
check_build_dependencies() {
    local repo_id="$1"
    local dependencies
    
    # Get dependencies from database
    dependencies=$(sqlite3 "$DB_FILE" "SELECT dependencies FROM build_configs WHERE repo_id = $repo_id;")
    
    if [ -z "$dependencies" ]; then
        return 0  # No dependencies specified
    fi
    
    echo -e "\n${BLUE}Checking build dependencies...${NC}"
    
    # Convert space-separated string to array
    IFS=' ' read -r -a deps_array <<< "$dependencies"
    
    local missing=0
    local missing_deps=()
    
    # Check each dependency
    for dep in "${deps_array[@]}"; do
        if ! dpkg -l | grep -q "$dep"; then
            echo -e "${YELLOW}Missing dependency: $dep${NC}"
            missing_deps+=("$dep")
            missing=1
        else
            echo -e "${GREEN}Dependency found: $dep${NC}"
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "\nThe following dependencies need to be installed:"
        printf '%s\n' "${missing_deps[@]}"
        read -rp "Would you like to install them now? (y/N): " choice
        
        if [[ $choice =~ ^[Yy]$ ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "${missing_deps[@]}"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm "${missing_deps[@]}"
            else
                error "Unsupported package manager. Please install required packages manually."
                return 1
            fi
            echo -e "${GREEN}Dependencies installed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: Missing dependencies may cause build to fail${NC}"
            read -rp "Continue anyway? (y/N): " continue_choice
            if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    else
        echo -e "${GREEN}All dependencies are installed${NC}"
    fi
    
    return 0
}

# Initialize SQLite database
init_db() {
    # Drop the old table if it exists (only during initialization)
    if [ ! -f "$DB_FILE" ]; then
        sqlite3 "$DB_FILE" "DROP TABLE IF EXISTS repositories;"
        sqlite3 "$DB_FILE" "DROP TABLE IF EXISTS build_configs;"
    fi

    # Create the repositories table
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS repositories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    last_commit TEXT,
    last_commit_check TEXT,
    last_built TEXT,
    build_success INTEGER,
    binary_path TEXT,
    build_type TEXT,
    build_file_path TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    deleted INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS build_configs (
    repo_id INTEGER,
    configure_flags TEXT,
    make_flags TEXT,
    cmake_flags TEXT,
    dependencies TEXT,
    FOREIGN KEY(repo_id) REFERENCES repositories(id)
);
EOF
    
    # Add new columns if they don't exist (for upgrading existing databases)
    sqlite3 "$DB_FILE" "PRAGMA table_info(repositories);" | grep -q "last_commit_check" || \
        sqlite3 "$DB_FILE" "ALTER TABLE repositories ADD COLUMN last_commit_check TEXT;"
    
    sqlite3 "$DB_FILE" "PRAGMA table_info(repositories);" | grep -q "build_type" || \
        sqlite3 "$DB_FILE" "ALTER TABLE repositories ADD COLUMN build_type TEXT;"
        
    sqlite3 "$DB_FILE" "PRAGMA table_info(repositories);" | grep -q "build_file_path" || \
        sqlite3 "$DB_FILE" "ALTER TABLE repositories ADD COLUMN build_file_path TEXT;"
        
    sqlite3 "$DB_FILE" "PRAGMA table_info(build_configs);" | grep -q "dependencies" || \
        sqlite3 "$DB_FILE" "ALTER TABLE build_configs ADD COLUMN dependencies TEXT;"
}

# Handle errors gracefully
error() {
    echo -e "\n${RED}Error: $1${NC}\n"
    echo "Press 'R' to return to menu..."
    read -r key
    if [[ $key =~ ^[Rr]$ ]]; then
        return 0
    fi
    return 1
}

# Trap errors and handle them gracefully
trap 'trap_error $?' ERR
trap_error() {
    if [ "$1" != "1" ]; then  # Don't show error for normal exit
        echo -e "\n${RED}An unexpected error occurred. Error code: $1${NC}"
        echo -e "Press 'R' to return to menu..."
        read -r key
        if [[ $key =~ ^[Rr]$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Display success message
success() {
    echo -e "\n${GREEN}Success: $1${NC}"
    if [ "${2:-}" = "wait" ]; then
        echo -e "\nPress any key to continue..."
        read -r -n 1
    fi
}

# Validate GitHub URL
validate_github_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github.com/[^/]+/[^/]+(.git)?$ ]]; then
        echo -e "${RED}Invalid GitHub URL format. Use: https://github.com/owner/repo${NC}"
        return 1
    fi
    return 0
}

# Get last commit date from GitHub
# Check if commit date needs to be refreshed (older than 4 hours)
needs_commit_refresh() {
    local repo_id="$1"
    
    # Get the last commit check time
    local last_check
    last_check=$(sqlite3 "$DB_FILE" "SELECT last_commit_check FROM repositories WHERE id = $repo_id;")
    
    # If never checked or empty, needs refresh
    if [ -z "$last_check" ]; then
        return 0  # True, needs refresh
    fi
    
    # Calculate time difference in seconds
    local now=$(date +%s)
    local check_time=$(date -d "$last_check" +%s 2>/dev/null || echo 0)
    local diff=$((now - check_time))
    
    # 4 hours = 14400 seconds
    if [ $diff -ge 14400 ]; then
        return 0  # True, needs refresh
    else
        return 1  # False, doesn't need refresh
    fi
}

# Update the last commit date for a repository
update_commit_date() {
    local repo_id="$1"
    local url="$2"
    
    # Check if we need to refresh
    if ! needs_commit_refresh "$repo_id"; then
        return 0
    fi
    
    # Get the last commit date
    local commit_date
    commit_date=$(get_last_commit_date "$url")
    
    # Update the database with the new commit date and check time
    if [ -n "$commit_date" ]; then
        local now=$(date -Iseconds)
        sqlite3 "$DB_FILE" "UPDATE repositories SET 
            last_commit = '$commit_date',
            last_commit_check = '$now'
            WHERE id = $repo_id;"
    fi
}

get_last_commit_date() {
    local url="$1"
    local repo_path
    
    # Extract owner and repo from URL
    repo_path=$(echo "$url" | sed -E 's#https://github.com/(.+?)(\.git)?$#\1#')
    
    # Use a more reliable method - clone depth 1 and get the commit date locally
    # This avoids GitHub API rate limits
    local temp_dir=$(mktemp -d)
    local commit_date=""
    
    if git clone --depth 1 "$url" "$temp_dir" >/dev/null 2>&1; then
        # Get the last commit date from the cloned repository
        commit_date=$(cd "$temp_dir" && git log -1 --format="%cI" 2>/dev/null)
        # Clean up the temporary directory
        rm -rf "$temp_dir"
    else
        # If git clone fails, try the GitHub API as a fallback
        if command -v jq >/dev/null 2>&1; then
            # Get last commit date using GitHub API with jq for proper JSON parsing
            local response
            response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$repo_path/commits/HEAD")
            
            # Check for rate limit errors
            if echo "$response" | grep -q "API rate limit exceeded"; then
                echo "GitHub API rate limit exceeded. Using existing data." >&2
                return 0
            fi
            
            commit_date=$(echo "$response" | jq -r '.commit.committer.date // empty')
            
            if [ -z "$commit_date" ]; then
                # Try main branch if HEAD fails
                response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo_path/commits/main")
                commit_date=$(echo "$response" | jq -r '.commit.committer.date // empty')
            fi
            
            if [ -z "$commit_date" ]; then
                # Try master branch if main fails
                response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo_path/commits/master")
                commit_date=$(echo "$response" | jq -r '.commit.committer.date // empty')
            fi
        else
            # Fallback to grep if jq is not available
            local response
            response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$repo_path/commits/HEAD")
                
            # Check for rate limit errors
            if echo "$response" | grep -q "API rate limit exceeded"; then
                echo "GitHub API rate limit exceeded. Using existing data." >&2
                return 0
            fi
            
            commit_date=$(echo "$response" | grep -o '"date": "[^"]*' | head -1 | cut -d'"' -f4)
            
            if [ -z "$commit_date" ]; then
                # Try main branch if HEAD fails
                commit_date=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo_path/commits/main" | \
                    grep -o '"date": "[^"]*' | head -1 | cut -d'"' -f4)
            fi
            
            if [ -z "$commit_date" ]; then
                # Try master branch if main fails
                commit_date=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo_path/commits/master" | \
                    grep -o '"date": "[^"]*' | head -1 | cut -d'"' -f4)
            fi
        fi
    fi
    
    echo "$commit_date"
}

# Parse gitbuildfile
parse_gitbuildfile() {
    local repo_dir="$1"
    local repo_id="$2"
    local gitbuildfile="$repo_dir/gitbuildfile"
    
    # Check if gitbuildfile exists
    if [ ! -f "$gitbuildfile" ]; then
        return 1
    fi
    
    echo -e "\n${BLUE}Found gitbuildfile. Using build information from file...${NC}"
    
    # Read gitbuildfile contents
    local repo_name=""
    local build_method=""
    local dependencies=""
    local build_file=""
    local configure_flags=""
    local make_flags=""
    local cmake_flags=""
    local binary_path=""
    
    # Parse each line in the file
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ -z $line ]] && continue
        
        # Extract key-value pairs
        if [[ $line =~ ^([A-Za-z_]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#'}"
            value="${value%'}"
            
            case "$key" in
                REPO_NAME)
                    repo_name="$value"
                    ;;
                BUILD_METHOD)
                    build_method="$value"
                    ;;
                DEPENDENCIES)
                    dependencies="$value"
                    ;;
                BUILD_FILE)
                    build_file="$value"
                    ;;
                CONFIGURE_FLAGS)
                    configure_flags="$value"
                    ;;
                MAKE_FLAGS)
                    make_flags="$value"
                    ;;
                CMAKE_FLAGS)
                    cmake_flags="$value"
                    ;;
                BINARY_PATH)
                    binary_path="$value"
                    ;;
            esac
        fi
    done < "$gitbuildfile"
    
    # Update database with gitbuildfile information
    if [ -n "$build_method" ]; then
        sqlite3 "$DB_FILE" "UPDATE repositories SET build_type = '$build_method' WHERE id = $repo_id;"
    fi
    
    if [ -n "$build_file" ]; then
        # Check if the build file path is relative or absolute
        if [[ "$build_file" != /* ]]; then
            build_file="$repo_dir/$build_file"
        fi
        sqlite3 "$DB_FILE" "UPDATE repositories SET build_file_path = '$build_file' WHERE id = $repo_id;"
    fi
    
    if [ -n "$binary_path" ]; then
        # Check if the binary path is relative or absolute
        if [[ "$binary_path" != /* ]]; then
            binary_path="$repo_dir/$binary_path"
        fi
        sqlite3 "$DB_FILE" "UPDATE repositories SET binary_path = '$binary_path' WHERE id = $repo_id;"
    fi
    
    # Update build configuration
    if [ -n "$configure_flags" ]; then
        update_build_config "$repo_id" "configure_flags" "$configure_flags"
    fi
    
    if [ -n "$make_flags" ]; then
        update_build_config "$repo_id" "make_flags" "$make_flags"
    fi
    
    if [ -n "$cmake_flags" ]; then
        update_build_config "$repo_id" "cmake_flags" "$cmake_flags"
    fi
    
    if [ -n "$dependencies" ]; then
        update_build_config "$repo_id" "dependencies" "$dependencies"
    fi
    
    echo -e "${GREEN}Successfully parsed gitbuildfile${NC}"
    return 0
}

# Find build files recursively up to depth 2
find_build_files() {
    local dir="$1"
    local depth="$2"
    local build_files=()
    
    # Create logs directory if it doesn't exist
    mkdir -p "$dir/logs"
    local log_file="$dir/logs/build_detection.log"
    
    # Log the build detection process
    echo "Searching for build files in $dir (depth $depth)" > "$log_file"
    
    # Special case for MAME - check if this is the MAME repository
    if [ -f "$dir/makefile" ] && grep -q "MAMEMESS" "$dir/makefile" 2>/dev/null; then
        echo "Found MAME makefile in root directory" >> "$log_file"
        build_files=("$dir/makefile")
        echo "${build_files[@]}"
        return 0
    fi
    
    # First, look specifically for autogen.sh in the root directory
    if [ -x "$dir/autogen.sh" ] && { [ -f "$dir/configure.ac" ] || [ -f "$dir/configure.in" ]; }; then
        echo "Found autogen.sh in root directory" >> "$log_file"
        build_files=("$dir/autogen.sh")
        echo "${build_files[@]}"
        return 0
    fi
    
    # Check for Makefile in root directory (common for many projects)
    if [ -f "$dir/Makefile" ] || [ -f "$dir/makefile" ]; then
        echo "Found Makefile in root directory" >> "$log_file"
        build_files=("$dir/Makefile")
        if [ ! -f "$dir/Makefile" ] && [ -f "$dir/makefile" ]; then
            build_files=("$dir/makefile")
        fi
        echo "${build_files[@]}"
        return 0
    fi
    
    # Search for all potential build files
    echo "Searching for build files with find..." >> "$log_file"
    while IFS= read -r -d '' file; do
        echo "Found file: $file" >> "$log_file"
        # Add file to array based on type and priority
        case "$file" in
            # 1. Autotools with autogen
            */autogen.sh)
                if [ -x "$file" ] && { [ -f "${file%/*}/configure.ac" ] || [ -f "${file%/*}/configure.in" ]; }; then
                    echo "Adding autogen.sh with priority" >> "$log_file"
                    build_files=("$file" "${build_files[@]}")
                fi
                ;;
            # 2. Autotools configure
            */configure)
                if [ -x "$file" ]; then
                    echo "Adding configure" >> "$log_file"
                    build_files+=("$file")
                fi
                ;;
            # 3. CMake
            */CMakeLists.txt)
                echo "Adding CMakeLists.txt" >> "$log_file"
                build_files+=("$file")
                ;;
            # 4. Other build systems
            */Makefile)
                # Only add Makefile if no higher-priority build system found in this directory
                local dir_has_priority=false
                for existing in "${build_files[@]}"; do
                    if [ "${existing%/*}" = "${file%/*}" ]; then
                        dir_has_priority=true
                        break
                    fi
                done
                if [ "$dir_has_priority" = false ]; then
                    echo "Adding Makefile" >> "$log_file"
                    build_files+=("$file")
                fi
                ;;
            */setup.py|*/package.json|*/meson.build|*/build.gradle|*/pom.xml)
                echo "Adding other build file: $file" >> "$log_file"
                build_files+=("$file")
                ;;
        esac
    done < <(find "$dir" -maxdepth "$depth" -type f \( \
        -name "autogen.sh" -o \
        -name "configure" -o \
        -name "CMakeLists.txt" -o \
        -name "Makefile" -o \
        -name "setup.py" -o \
        -name "package.json" -o \
        -name "meson.build" -o \
        -name "build.gradle" -o \
        -name "pom.xml" \
    \) -print0 2>> "$log_file")
    
    # If no build files found, try a deeper search for configure and CMakeLists.txt
    if [ ${#build_files[@]} -eq 0 ] && [ "$depth" -lt 3 ]; then
        echo "No build files found at depth $depth, trying depth 3" >> "$log_file"
        build_files=($(find_build_files "$dir" 3))
    fi
    
    # Print the results, ensuring we don't output empty strings
    if [ ${#build_files[@]} -gt 0 ]; then
        echo "Found ${#build_files[@]} build files: ${build_files[@]}" >> "$log_file"
        echo "${build_files[@]}"
    else
        echo "No build files found" >> "$log_file"
    fi
}

# Get build system type from file
get_build_type() {
    local file="$1"
    local filename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    case "$filename" in
        "CMakeLists.txt")
            echo "cmake|$dirname|CMake build system"
            ;;
        "configure")
            # Don't use configure if there's an autogen.sh
            if [ -x "$dirname/autogen.sh" ] && { [ -f "$dirname/configure.ac" ] || [ -f "$dirname/configure.in" ]; }; then
                return 0
            fi
            # Check if it's a custom configure script
            if grep -q '#!/bin/bash' "$file" 2>/dev/null; then
                echo "custom-configure|$dirname|Custom configure script"
            else
                echo "autotools|$dirname|Autotools build system"
            fi
            ;;
        "autogen.sh")
            # Check if configure.ac or configure.in exists
            if [ -f "$dirname/configure.ac" ] || [ -f "$dirname/configure.in" ]; then
                # Run autogen.sh first
                echo "autogen|$dirname|Autotools build system (needs autogen)"
            fi
            ;;
        "Makefile" | "makefile")
            # Special case for MAME
            if grep -q "MAMEMESS" "$file" 2>/dev/null; then
                echo "make|$dirname|MAME build system"
                return 0
            fi
            
            # Don't use Makefile if there's a higher priority build system
            if [ -f "$dirname/CMakeLists.txt" ] || 
               [ -f "$dirname/configure" ] || 
               ([ -x "$dirname/autogen.sh" ] && { [ -f "$dirname/configure.ac" ] || [ -f "$dirname/configure.in" ]; }); then
                return 0
            fi
            echo "make|$dirname|Make build system"
            ;;
        "setup.py")
            echo "python|$dirname|Python package"
            ;;
        "package.json")
            echo "node|$dirname|Node.js package"
            ;;
        "meson.build")
            echo "meson|$dirname|Meson build system"
            ;;
        "build.gradle")
            echo "gradle|$dirname|Gradle build system"
            ;;
        "pom.xml")
            echo "maven|$dirname|Maven build system"
            ;;
    esac
}

# Update all repositories' commit information
update_all_repos() {
    echo -e "\n${BLUE}Updating repository information...${NC}"
    local total updated=0
    total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM repositories WHERE deleted = 0;")
    
    while IFS='|' read -r id name url; do
        if [ -n "$id" ]; then
            echo -e "\nChecking ${YELLOW}$name${NC}..."
            local commit_date
            commit_date=$(get_last_commit_date "$url")
            if [ "$commit_date" != "Unknown" ]; then
                sqlite3 "$DB_FILE" "UPDATE repositories SET last_commit = '$commit_date' WHERE id = $id;"
                ((updated++))
            fi
        fi
    done < <(sqlite3 "$DB_FILE" "SELECT id, name, url FROM repositories WHERE deleted = 0;")
    
    echo -e "\n${GREEN}Updated $updated of $total repositories${NC}"
    echo -e "Press any key to continue..."
    read -r -n 1
}

# Get build configuration for a repository
get_build_config() {
    local repo_id="$1"
    
    # Get build configuration from database
    local config
    config=$(sqlite3 "$DB_FILE" "SELECT configure_flags, make_flags, cmake_flags, dependencies FROM build_configs WHERE repo_id = $repo_id;")
    
    # If no config exists, create an empty one
    if [ -z "$config" ]; then
        sqlite3 "$DB_FILE" "INSERT INTO build_configs (repo_id, configure_flags, make_flags, cmake_flags, dependencies) VALUES ($repo_id, '', '', '', '');"
        echo "||||"
    else
        echo "$config"
    fi
}

# Update build configuration for a repository
update_build_config() {
    local repo_id="$1"
    local field="$2"
    local value="$3"
    
    # Escape single quotes in the value
    value=$(echo "$value" | sed "s/'/''/g")
    
    # Check if the build config exists
    local exists
    exists=$(sqlite3 "$DB_FILE" "SELECT 1 FROM build_configs WHERE repo_id = $repo_id;")
    
    if [ -z "$exists" ]; then
        # Create a new build config entry
        case "$field" in
            configure_flags)
                sqlite3 "$DB_FILE" "INSERT INTO build_configs (repo_id, configure_flags, make_flags, cmake_flags, dependencies) 
                    VALUES ($repo_id, '$value', '', '', '');"
                ;;
            make_flags)
                sqlite3 "$DB_FILE" "INSERT INTO build_configs (repo_id, configure_flags, make_flags, cmake_flags, dependencies) 
                    VALUES ($repo_id, '', '$value', '', '');"
                ;;
            cmake_flags)
                sqlite3 "$DB_FILE" "INSERT INTO build_configs (repo_id, configure_flags, make_flags, cmake_flags, dependencies) 
                    VALUES ($repo_id, '', '', '$value', '');"
                ;;
            dependencies)
                sqlite3 "$DB_FILE" "INSERT INTO build_configs (repo_id, configure_flags, make_flags, cmake_flags, dependencies) 
                    VALUES ($repo_id, '', '', '', '$value');"
                ;;
        esac
    else
        # Update the existing build config
        sqlite3 "$DB_FILE" "UPDATE build_configs SET $field = '$value' WHERE repo_id = $repo_id;"
    fi
}

# Set build configuration
# Show available build flags for different build systems
show_available_flags() {
    echo -e "\n${BLUE}Available Build Flags${NC}"
    echo -e "${YELLOW}Common Configure Flags:${NC}"
    echo "  --prefix=PREFIX       Install architecture-independent files in PREFIX"
    echo "  --enable-debug        Enable debug symbols and assertions"
    echo "  --disable-shared      Disable shared libraries"
    echo "  --with-X              Enable support for X"
    echo "  --without-X           Disable support for X"
    
    echo -e "\n${YELLOW}Common Make Flags:${NC}"
    echo "  -j N                  Use N parallel jobs"
    echo "  CFLAGS=\"...\"          Set C compiler flags"
    echo "  LDFLAGS=\"...\"         Set linker flags"
    echo "  V=1                   Verbose output"
    
    echo -e "\n${YELLOW}Common CMake Flags:${NC}"
    echo "  -DCMAKE_BUILD_TYPE=Debug|Release|RelWithDebInfo"
    echo "  -DCMAKE_INSTALL_PREFIX=PREFIX"
    echo "  -DBUILD_SHARED_LIBS=ON|OFF"
    echo "  -DCMAKE_C_FLAGS=\"...\""
    
    echo -e "\n${YELLOW}Project-Specific Flags:${NC}"
    echo "  ZEsarUX:              --enable-sdl --enable-ssl"
    echo "  Atari800:             --target=sdl --enable-opengl"
    
    echo -e "\nPress any key to continue..."
    read -r -n 1
}

# Edit build configuration for a repository
edit_build_config() {
    local repo_id="$1"
    local repo_name="$2"
    
    echo -e "\n${BLUE}Build Configuration for $repo_name${NC}"
    echo "Leave blank to keep existing values"
    
    local current_config
    IFS='|' read -r conf_flags make_flags cmake_flags <<< "$(get_build_config "$repo_id")"
    
    read -rp "Configure flags [$conf_flags]: " new_conf_flags
    read -rp "Make flags [$make_flags]: " new_make_flags
    read -rp "CMake flags [$cmake_flags]: " new_cmake_flags
    
    # Use existing values if new ones are empty
    conf_flags="${new_conf_flags:-$conf_flags}"
    make_flags="${new_make_flags:-$make_flags}"
    cmake_flags="${new_cmake_flags:-$cmake_flags}"
    
    sqlite3 "$DB_FILE" "UPDATE build_configs SET 
        configure_flags = '$conf_flags',
        make_flags = '$make_flags',
        cmake_flags = '$cmake_flags'
        WHERE repo_id = $repo_id;"
    
    success "Build configuration updated" wait
}

# Main build configuration menu
set_build_config() {
    local repo_id="$1"
    
    # Get repository name
    local repo_name
    repo_name=$(sqlite3 "$DB_FILE" "SELECT name FROM repositories WHERE id = $repo_id;")
    
    if [ -z "$repo_name" ]; then
        error "Repository ID $repo_id not found"
        return 1
    fi
    
    while true; do
        clear
        echo -e "\n${BLUE}Build Configuration Menu for $repo_name${NC}"
        echo "1) Add/Edit build flags"
        echo "2) See available build flags"
        echo "3) Return to main menu"
        
        read -rp "Select an option: " choice
        case $choice in
            1) edit_build_config "$repo_id" "$repo_name" ;;
            2) show_available_flags ;;
            3) return 0 ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

find_binary() {
    local dir="$1"
    local name="$2"
    local binaries=()
    
    # First check common build output directories
    local build_dirs=(
        "$dir"
        "$dir/build"
        "$dir/bin"
        "$dir/src"
        "$dir/target/release"
        "$dir/target/debug"
        "$dir/dist"
    )
    
    # Special case for MAME - check if the mame binary exists in the root directory
    if [ -x "$dir/mame" ] && [ -f "$dir/mame" ]; then
        binaries+=("$dir/mame")
    fi
    
    # Check each build directory for binaries
    for build_dir in "${build_dirs[@]}"; do
        if [ -d "$build_dir" ]; then
            # Look for binaries with the same name as the repository
            if [ -x "$build_dir/$name" ] && [ -f "$build_dir/$name" ]; then
                binaries+=("$build_dir/$name")
            fi
            
            # Look for binaries in the build directory
            while IFS= read -r -d '' file; do
                if [ -x "$file" ] && [ -f "$file" ]; then
                    local mime_type
                    mime_type=$(file -b --mime-type "$file")
                    if [[ "$mime_type" == "application/x-executable" || "$mime_type" == "application/x-pie-executable" ]]; then
                        binaries+=("$file")
                    fi
                fi
            done < <(find "$build_dir" -maxdepth 1 -type f -print0 2>/dev/null)
        fi
    done
    
    # If no binaries found in common directories, search the entire directory
    if [ ${#binaries[@]} -eq 0 ]; then
        while IFS= read -r -d '' file; do
            if [ -x "$file" ] && [ -f "$file" ]; then
                local mime_type
                mime_type=$(file -b --mime-type "$file")
                if [[ "$mime_type" == "application/x-executable" || "$mime_type" == "application/x-pie-executable" ]]; then
                    binaries+=("$file")
                fi
            fi
        done < <(find "$dir" -type f -executable -print0 2>/dev/null)
    fi
    
    # Return binaries one per line instead of space-separated
    for binary in "${binaries[@]}"; do
        echo "$binary"
    done
}

# Handle build result
browse_for_binary() {
    # Direct file browser implementation with temporary file output
    local start_dir="$1"
    
    # Ensure the directory exists
    if [ ! -d "$start_dir" ]; then
        mkdir -p "$start_dir"
        echo "Created directory: $start_dir"
    fi
    
    # Remove any existing temporary file
    rm -f "/tmp/gitbuilder_selected_binary"
    
    local current_dir=$(realpath "$start_dir")
    
    while true; do
        # Clear screen and show header
        clear
        echo "=========================================="
        echo "FILE BROWSER - Select a binary"
        echo "Current directory: $current_dir"
        echo "=========================================="
        
        # Show parent directory option
        echo "0) .. (Go to parent directory)"
        
        # Initialize arrays for menu items
        declare -a items_path
        declare -a items_type
        local count=1
        
        # First list directories
        echo 
        echo "DIRECTORIES:"
        for d in "$current_dir"/*/; do
            if [ -d "$d" ]; then
                local name=$(basename "$d")
                echo "$count) [DIR] $name/"
                items_path[$count]="$d"
                items_type[$count]="dir"
                count=$((count+1))
            fi
        done
        
        # Then list executable files
        echo 
        echo "EXECUTABLE FILES:"
        for f in "$current_dir"/*; do
            if [ -f "$f" ] && [ -x "$f" ]; then
                local name=$(basename "$f")
                echo "$count) [BIN] $name"
                items_path[$count]="$f"
                items_type[$count]="bin"
                count=$((count+1))
            fi
        done
        
        # Show navigation options
        echo 
        echo "q) Quit browser"
        echo 
        
        # Get user selection
        echo -n "Select option (0-$((count-1)), q to quit): "
        read choice
        
        # Process the selection
        if [ "$choice" = "q" ]; then
            # User wants to quit
            return 1
        elif [ "$choice" = "0" ]; then
            # Go to parent directory
            if [ "$current_dir" != "/" ]; then
                current_dir=$(dirname "$current_dir")
            fi
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$count" ]; then
            # Valid selection
            if [ "${items_type[$choice]}" = "dir" ]; then
                # Navigate to selected directory
                current_dir="${items_path[$choice]}"
            elif [ "${items_type[$choice]}" = "bin" ]; then
                # Save selected binary path to temporary file
                echo "${items_path[$choice]}" > "/tmp/gitbuilder_selected_binary"
                return 0
            fi
        else
            # Invalid selection
            echo "Invalid selection. Press any key to continue..."
            read -n 1
        fi
    done
}

# Handle build result
handle_build_result() {
    local repo_id="$1"
    local build_dir="$2"
    local success="$3"
    local log_file="$4"
    local name
    name=$(sqlite3 "$DB_FILE" "SELECT name FROM repositories WHERE id = $repo_id;")
    
    if [ "$success" -eq 0 ]; then
        echo -e "\n${GREEN}Build completed successfully!${NC}"
        
        # Look for potential binary files
        echo -e "\n${BLUE}Looking for binary files...${NC}"
        local binaries=()
        # Capture each line of output as a separate array element
        mapfile -t binaries < <(find_binary "$build_dir" "$name")
        
        if [ ${#binaries[@]} -gt 0 ]; then
            echo -e "\n${BLUE}Found potential binary files:${NC}"
            local i=1
            for binary in "${binaries[@]}"; do
                echo "$i) $binary"
                ((i++))
            done
            
            echo "b) Browse for binary"
            read -rp "Select binary to register (1-${#binaries[@]}, or 'b' to browse): " choice
            
            local selected_binary
            if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#binaries[@]}" ]; then
                selected_binary="${binaries[$choice-1]}"
            elif [[ $choice == "b" ]]; then
                # Call the browse_for_binary function and capture its output and return code
                selected_binary=$(browse_for_binary "$build_dir")
                local browse_status=$?
                if [ $browse_status -ne 0 ]; then
                    echo -e "${YELLOW}Binary selection cancelled${NC}"
                    return 1
                fi
                
                # Verify the selected binary exists and is executable
                if [ ! -x "$selected_binary" ]; then
                    echo -e "${RED}Error: Selected binary is not executable${NC}"
                    return 1
                fi
            else
                return 1
            fi
            
            echo -e "${GREEN}Selected binary: $selected_binary${NC}"
            
            # Save binary path to database
            sqlite3 "$DB_FILE" "UPDATE repositories SET 
                binary_path = '$selected_binary'
                WHERE id = $repo_id;"
            
            read -rp "Would you like to launch the binary now? (y/N): " run_choice
            if [[ $run_choice =~ ^[Yy]$ ]]; then
                launch_binary "$repo_id"
            fi
        else
            echo -e "\n${YELLOW}No binaries found automatically.${NC}"
            read -rp "Would you like to browse for the binary? (Y/n): " browse_choice
            if [[ ! $browse_choice =~ ^[Nn]$ ]]; then
                local selected_binary
                # Call the browse_for_binary function and capture its output and return code
                selected_binary=$(browse_for_binary "$build_dir")
                local browse_status=$?
                if [ $browse_status -eq 0 ] && [ -x "$selected_binary" ]; then
                    echo -e "${GREEN}Selected binary: $selected_binary${NC}"
                    
                    # Save binary path to database
                    sqlite3 "$DB_FILE" "UPDATE repositories SET 
                        binary_path = '$selected_binary'
                        WHERE id = $repo_id;"
                    
                    read -rp "Would you like to launch the binary now? (y/N): " run_choice
                    if [[ $run_choice =~ ^[Yy]$ ]]; then
                        launch_binary "$repo_id"
                    fi
                fi
            fi
        fi
    else
        echo -e "\n${RED}Build failed!${NC}"
        read -rp "Would you like to see the build log? (y/N): " choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            less "$log_file"
        fi
    fi
    
    # Update build status in database
    sqlite3 "$DB_FILE" "UPDATE repositories SET 
        build_success = $success,
        last_built = datetime('now')
        WHERE id = $repo_id;"
}

# Execute build command with timeout and progress
execute_build() {
    local type="$1"
    local dir="$2"
    local repo_id="$3"
    shift 3
    local args=("$@")
    local log_file
    local build_dir="$dir"
    
    # Create logs directory if it doesn't exist
    local log_dir="$dir/logs"
    mkdir -p "$log_dir"
    
    # Create a unique log file for this build
    log_file="$log_dir/build_$(date +%Y%m%d_%H%M%S).log"
    
    # Get build configuration
    local configure_flags make_flags cmake_flags
    IFS='|' read -r configure_flags make_flags cmake_flags < <(get_build_config "$repo_id")
    
    # Get repository name
    local name
    name=$(sqlite3 "$DB_FILE" "SELECT name FROM repositories WHERE id = $repo_id;")
    
    echo -e "\n${BLUE}Building with $type...${NC}"
    echo "Build output will be saved to: $log_file"
    
    # Special handling for Atari800
    if [ "$name" = "Atari800" ]; then
        echo -e "${BLUE}Detected Atari800 - using special build process...${NC}"
        
        # Create a subshell to maintain directory state
        (
            cd "$dir" || exit 1
            
            # Run the build process
            {
                echo "Running autogen.sh..." >> "$log_file"
                ./autogen.sh >> "$log_file" 2>&1 || exit 1
                
                echo "Running configure..." >> "$log_file"
                ./configure ${args[@]:-} $configure_flags >> "$log_file" 2>&1 || exit 1
                
                echo "Running make..." >> "$log_file"
                make $make_flags
            } > "$log_file" 2>&1
        ) &
    else
        # Create a subshell to maintain directory state
        (
            case "$type" in
                "cmake")
                    # Create build directory if it doesn't exist
                    build_dir="$dir/build"
                    mkdir -p "$build_dir"
                    cd "$build_dir" || exit 1
                    
                    # Run cmake with progress
                    {
                        cmake ${args[@]:-} $cmake_flags .. && \
                        make $make_flags
                    } > "$log_file" 2>&1
                    ;;
                    
                "autogen")
                    cd "$dir" || exit 1
                    
                    # Run autogen.sh, configure, and make
                    {
                        echo "Running autogen.sh..." >> "$log_file"
                        ./autogen.sh >> "$log_file" 2>&1 || exit 1
                        
                        echo "Running configure..." >> "$log_file"
                        ./configure ${args[@]:-} $configure_flags >> "$log_file" 2>&1 || exit 1
                        
                        echo "Running make..." >> "$log_file"
                        make $make_flags
                    } > "$log_file" 2>&1
                    ;;
                    
                "autotools" | "custom-configure")
                    cd "$dir" || exit 1
                    
                    # Run configure and make
                    {
                        echo "Running configure..." >> "$log_file"
                        ./configure ${args[@]:-} $configure_flags >> "$log_file" 2>&1 || exit 1
                        
                        echo "Running make..." >> "$log_file"
                        make $make_flags
                    } > "$log_file" 2>&1
                    ;;
                    
                "make")
                    cd "$dir" || exit 1
                    
                    # Special handling for MAME
                    if [ -f "makefile" ] && grep -q "MAMEMESS" "makefile" 2>/dev/null; then
                        echo "Building MAME..." >> "$log_file"
                        # MAME typically needs specific targets
                        make $make_flags > "$log_file" 2>&1
                    else
                        # Regular make build
                        make $make_flags > "$log_file" 2>&1
                    fi
                    ;;
                    
                "gradle")
                    cd "$dir" || exit 1
                    {
                        echo "Running gradle build..." >> "$log_file"
                        # Check if gradlew exists and is executable
                        if [ -x "./gradlew" ]; then
                            echo "Using Gradle wrapper..." >> "$log_file"
                            ./gradlew build
                        elif command -v gradle >/dev/null 2>&1; then
                            echo "Using system Gradle..." >> "$log_file"
                            gradle build
                        else
                            echo "Error: Neither Gradle wrapper nor system Gradle found" >> "$log_file"
                            exit 1
                        fi
                    } > "$log_file" 2>&1
                    ;;
                    
                "maven")
                    cd "$dir" || exit 1
                    {
                        echo "Running maven build..." >> "$log_file"
                        mvn clean install
                    } > "$log_file" 2>&1
                    ;;
                    
                "python")
                    cd "$dir" || exit 1
                    {
                        echo "Building Python package..." >> "$log_file"
                        python setup.py build
                    } > "$log_file" 2>&1
                    ;;
                    
                "node")
                    cd "$dir" || exit 1
                    {
                        echo "Building Node.js package..." >> "$log_file"
                        npm install && npm run build
                    } > "$log_file" 2>&1
                    ;;
                    
                "meson")
                    cd "$dir" || exit 1
                    {
                        echo "Running meson build..." >> "$log_file"
                        meson build && cd build && ninja
                    } > "$log_file" 2>&1
                    ;;
                    
                *)
                    error "Unknown build type: $type"
                    exit 1
                    ;;
            esac
        ) &
    fi
    
    # Get the background process ID
    local pid=$!
    
    # Show progress while building
    local dots=""
    while kill -0 $pid 2>/dev/null; do
        echo -ne "\r${YELLOW}Building${dots}${NC}   "
        dots="$dots."
        [ ${#dots} -gt 3 ] && dots=""
        sleep 1
    done
    echo -ne "\r"
    
    # Check if build succeeded
    wait $pid
    local status=$?
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}Build completed successfully!${NC}"
        handle_build_result "$repo_id" "$dir" 0 "$log_file"
        return 0
    else
        echo -e "${RED}Build failed!${NC}"
        handle_build_result "$repo_id" "$dir" 1 "$log_file"
        return 1
    fi
}

# Detect build system and build package
build_package() {
    local dir="$1"
    local repo_id="$2"
    local build_files=()
    
    # Check if a custom build file path is specified in the database
    local custom_build_file
    custom_build_file=$(sqlite3 "$DB_FILE" "SELECT build_file_path FROM repositories WHERE id = $repo_id;")
    
    if [ -n "$custom_build_file" ] && [ -f "$custom_build_file" ]; then
        echo -e "${BLUE}Using custom build file: $custom_build_file${NC}"
        build_files=("$custom_build_file")
    else
        # If no custom build file, use auto-detection
        build_files=($(find_build_files "$dir" 2))
    fi
    
    if [ ${#build_files[@]} -eq 0 ]; then
        error "No recognized build system found in $dir (searched 2 levels deep)"
        return 1
    fi
    
    if [ ${#build_files[@]} -eq 1 ]; then
        local build_info
        IFS='|' read -r type dir desc <<< "$(get_build_type "${build_files[0]}")"
        echo -e "${GREEN}Detected $desc${NC}"
        execute_build "$type" "$dir" "$repo_id"
    else
        echo -e "\n${BLUE}Multiple build systems detected:${NC}"
        local options=()
        local i=1
        
        for file in "${build_files[@]}"; do
            local type dir desc
            IFS='|' read -r type dir desc <<< "$(get_build_type "$file")"
            if [ -n "$type" ]; then
                echo "$i) $desc (in $dir)"
                options+=("$type|$dir")
                ((i++))
            fi
        done
        
        if [ ${#options[@]} -eq 0 ]; then
            error "No valid build systems found"
            return 1
        elif [ ${#options[@]} -eq 1 ]; then
            echo -e "${GREEN}Using only valid build system found${NC}"
            local selected=(${options[0]//|/ })
            execute_build "${selected[0]}" "${selected[1]}" "$repo_id"
        else
            read -rp "Select build system to use (1-${#options[@]}): " choice
            if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
                local selected=(${options[$choice-1]//|/ })
                execute_build "${selected[0]}" "${selected[1]}" "$repo_id"
            else
                error "Invalid selection"
                return 1
            fi
        fi
    fi
}

# Add new repository
add_repo() {
    local name url
    while true; do
        read -rp "Enter repository name (or 'c' to cancel): " name
        if [ "$name" = "c" ]; then
            return 0
        fi
        if [ -z "$name" ]; then
            echo -e "${RED}Name cannot be empty${NC}"
            continue
        fi
        # Check if an active repository with this name exists
        if [ "$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM repositories WHERE name = '$name';")" -gt 0 ]; then
            echo -e "${RED}A repository with this name already exists${NC}"
            continue
        fi
        break
    done
    
    while true; do
        read -rp "Enter GitHub repository URL (or 'c' to cancel): " url
        if [ "$url" = "c" ]; then
            return 0
        fi
        if ! validate_github_url "$url"; then
            continue
        fi
        break
    done
    
    echo -e "\n${BLUE}Fetching repository information...${NC}"
    local commit_date
    commit_date=$(get_last_commit_date "$url")
    
    # Check if we need to rebuild indexes first
    local max_id expected_max_id
    max_id=$(sqlite3 "$DB_FILE" "SELECT MAX(id) FROM repositories;")
    expected_max_id=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM repositories;")
    
    # If there are gaps in the ID sequence, rebuild indexes
    if [ "$max_id" != "$expected_max_id" ]; then
        rebuild_db_indexes
    fi
    
    # Add the new repository
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO repositories (name, url, last_commit)
VALUES ('$name', '$url', '$commit_date');
EOF
    success "Repository '$name' added successfully" wait
}

# Edit repository
edit_repo() {
    local id name url
    read -rp "Enter repository ID to edit: " id
    read -rp "Enter new name (or press enter to skip): " name
    read -rp "Enter new URL (or press enter to skip): " url
    
    local query="UPDATE repositories SET"
    local updates=()
    
    if [ -n "$name" ]; then
        updates+=("name = '$name'")
    fi
    if [ -n "$url" ]; then
        validate_github_url "$url"
        local commit_date
        commit_date=$(get_last_commit_date "$url")
        updates+=("url = '$url'")
        updates+=("last_commit = '$commit_date'")
    fi
    
    if [ ${#updates[@]} -eq 0 ]; then
        error "No changes specified"
        return 1
    fi
    
    # Join updates with commas
    local update_str
    update_str=$(IFS=,; echo "${updates[*]}")
    
    sqlite3 "$DB_FILE" "UPDATE repositories SET $update_str WHERE id = $id AND deleted = 0;"
    success "Repository updated successfully"
}

# Resequence repository IDs
resequence_ids() {
    sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE temp_repos AS 
    SELECT NULL as id, name, url, last_commit, last_built, created_at, deleted 
    FROM repositories 
    ORDER BY id;
    
    DROP TABLE repositories;
    
    CREATE TABLE repositories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        last_commit TEXT,
        last_built TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        deleted INTEGER DEFAULT 0
    );
    
    INSERT INTO repositories (name, url, last_commit, last_built, created_at, deleted)
    SELECT name, url, last_commit, last_built, created_at, deleted FROM temp_repos;
    
    DROP TABLE temp_repos;
EOF
}

# Cleanup repository files
cleanup_repo_files() {
    local name="$1"
    local repo_dir="$SRC_DIR/$name"
    
    if [ -d "$repo_dir" ]; then
        echo -e "\n${YELLOW}Found local repository files at: $repo_dir${NC}"
        read -rp "Would you like to remove these files? (y/N): " choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            rm -rf "$repo_dir"
            echo -e "${GREEN}Local repository files removed${NC}"
        fi
    fi
}

# Remove repository
# Rebuild database indexes to ensure sequential IDs
rebuild_db_indexes() {
    echo "Rebuilding database indexes..."
    
    # Create a temporary table with the current data
    sqlite3 "$DB_FILE" <<EOF
    BEGIN TRANSACTION;
    CREATE TEMPORARY TABLE repos_backup AS SELECT * FROM repositories WHERE deleted = 0;
    DELETE FROM repositories;
    DELETE FROM sqlite_sequence WHERE name='repositories';
    INSERT INTO repositories (name, url, last_commit, last_built, build_success, binary_path, created_at, deleted)
    SELECT name, url, last_commit, last_built, build_success, binary_path, created_at, deleted FROM repos_backup;
    DROP TABLE repos_backup;
    COMMIT;
EOF
    
    success "Database indexes rebuilt successfully"
}

remove_repo() {
    local id name
    read -rp "Enter repository ID to remove: " id
    
    # Get repository name before deletion
    name=$(sqlite3 "$DB_FILE" "SELECT name FROM repositories WHERE id = $id AND deleted = 0;")
    
    if [ -z "$name" ]; then
        error "Repository ID $id not found"
        return 1
    fi
    
    # Hard delete from database
    sqlite3 "$DB_FILE" "DELETE FROM repositories WHERE id = $id;"
    
    # Cleanup local files
    cleanup_repo_files "$name"
    
    # Rebuild indexes to ensure sequential IDs
    rebuild_db_indexes
    
    success "Repository '$name' removed successfully"
}

# Download and build repository
download_build() {
    local id="$1"
    local repo_info
    repo_info=$(sqlite3 "$DB_FILE" "SELECT name, url FROM repositories WHERE id = $id AND deleted = 0;")
    local name url
    name=$(echo "$repo_info" | cut -d'|' -f1)
    url=$(echo "$repo_info" | cut -d'|' -f2)
    
    if [ -z "$name" ]; then
        error "Repository ID $id not found"
        return 1
    fi
    
    # Ensure source directory exists and is accessible
    mkdir -p "$SRC_DIR"
    cd "$SRC_DIR" || {
        error "Failed to access source directory: $SRC_DIR"
        return 1
    }
    
    local repo_dir="$SRC_DIR/$name"
    
    if [ -d "$repo_dir" ]; then
        echo -e "\n${BLUE}Repository already exists locally.${NC}"
        echo "1) Use existing repository and update it"
        echo "2) Delete existing repository and clone fresh"
        echo "3) Cancel"
        
        read -rp "Select an option: " choice
        case $choice in
            1)
                echo "Updating repository..."
                cd "$repo_dir" || {
                    error "Failed to access repository directory: $repo_dir"
                    return 1
                }
                if ! git pull; then
                    error "Failed to update repository"
                    return 1
                fi
                ;;
            2)
                echo "Deleting existing repository..."
                rm -rf "$repo_dir"
                echo "Cloning repository..."
                if ! git clone "$url" "$name"; then
                    error "Failed to clone repository"
                    return 1
                fi
                ;;
            3)
                echo "Operation cancelled"
                return 0
                ;;
            *)
                error "Invalid option"
                return 1
                ;;
        esac
    else
        echo "Cloning repository..."
        if ! git clone "$url" "$name"; then
            error "Failed to clone repository"
            return 1
        fi
    fi
    
    # Check for gitbuildfile and parse it if found
    if ! parse_gitbuildfile "$repo_dir" "$id"; then
        echo -e "${YELLOW}No gitbuildfile found. Using auto-detection...${NC}"
    fi
    
    # Check for dependencies before building
    if ! check_build_dependencies "$id"; then
        error "Failed to resolve dependencies"
        return 1
    fi
    
    echo "Building package..."
    build_package "$repo_dir" "$id"
    
    local current_time
    current_time=$(date -Iseconds)
    sqlite3 "$DB_FILE" "UPDATE repositories SET last_built = '$current_time' WHERE id = $id;"
    
    success "Package built successfully"
}

# Display repositories table
# Legacy function - now just calls update_commit_date
update_last_commit_date() {
    local id="$1"
    local url="$2"
    
    update_commit_date "$id" "$url"
}

# Record build type in database
record_build_type() {
    local repo_id="$1"
    local build_type="$2"
    
    sqlite3 "$DB_FILE" "UPDATE repositories SET build_type = '$build_type' WHERE id = $repo_id;"
}

# Show detailed information about a repository
show_build_details() {
    local repo_id="$1"
    
    # Validate repo_id is a number
    if ! [[ "$repo_id" =~ ^[0-9]+$ ]]; then
        error "Invalid repository ID: $repo_id"
        return 1
    fi
    
    while true; do
        # Clear the screen
        printf "\033c"
        
        # Get repository details
        local repo_info
        repo_info=$(sqlite3 "$DB_FILE" "SELECT name, url, last_commit, last_commit_check, last_built, 
            build_success, binary_path, build_type, build_file_path, created_at FROM repositories WHERE id = $repo_id;")
        
        if [ -z "$repo_info" ]; then
            error "Repository ID $repo_id not found"
            return 1
        fi
        
        # Parse repository info
        local name url last_commit last_commit_check last_built build_success binary_path build_type build_file_path created_at
        IFS='|' read -r name url last_commit last_commit_check last_built build_success binary_path build_type build_file_path created_at <<< "$repo_info"
        
        # Get build configuration
        local configure_flags make_flags cmake_flags dependencies
        IFS='|' read -r configure_flags make_flags cmake_flags dependencies <<< "$(get_build_config "$repo_id")"
        
        # Format build success status
        local build_status="Unknown"
        if [ "$build_success" = "0" ]; then
            build_status="${GREEN}Success${NC}"
        elif [ "$build_success" = "1" ]; then
            build_status="${RED}Failed${NC}"
        fi
        
        # Format binary status
        local binary_status="${RED}Not found${NC}"
        if [ -n "$binary_path" ] && [ -x "$binary_path" ]; then
            binary_status="${GREEN}Available${NC}"
        fi
        
        # Format dates nicely
        local formatted_commit_date=""
        if [ -n "$last_commit" ]; then
            formatted_commit_date=$(date -d "$last_commit" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$last_commit")
        fi
        
        local formatted_commit_check=""
        if [ -n "$last_commit_check" ]; then
            formatted_commit_check=$(date -d "$last_commit_check" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$last_commit_check")
        fi
        
        local formatted_built_date=""
        if [ -n "$last_built" ]; then
            formatted_built_date=$(date -d "$last_built" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$last_built")
        fi
        
        local formatted_created_date=""
        if [ -n "$created_at" ]; then
            formatted_created_date=$(date -d "$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_at")
        fi
        
        # Display repository details as a menu
        echo -e "\n${BLUE}Repository Details - Select an option to edit${NC}"
        echo -e "1) ${YELLOW}Name:${NC}              $name"
        echo -e "2) ${YELLOW}URL:${NC}               $url"
        echo -e "3) ${YELLOW}Added on:${NC}          $formatted_created_date (not editable)"
        echo -e "4) ${YELLOW}Last commit:${NC}       $formatted_commit_date (not editable)"
        echo -e "5) ${YELLOW}Commit checked:${NC}    $formatted_commit_check (not editable)"
        echo -e "6) ${YELLOW}Last built:${NC}        $formatted_built_date (not editable)"
        echo -e "7) ${YELLOW}Build status:${NC}      $build_status (not editable)"
        echo -e "8) ${YELLOW}Build type:${NC}        $build_type (not editable)"
        echo -e "9) ${YELLOW}Binary status:${NC}     $binary_status (not editable)"
        echo -e "10) ${YELLOW}Binary path:${NC}       $binary_path"
        echo -e "11) ${YELLOW}Build file path:${NC}   $build_file_path"
        
        echo -e "\n${BLUE}Build Configuration${NC}"
        echo -e "12) ${YELLOW}Configure flags:${NC}   $configure_flags"
        echo -e "13) ${YELLOW}Make flags:${NC}        $make_flags"
        echo -e "14) ${YELLOW}CMake flags:${NC}       $cmake_flags"
        echo -e "15) ${YELLOW}Dependencies:${NC}      $dependencies"
        
        echo -e "\n${BLUE}Actions${NC}"
        echo -e "16) Rebuild repository"
        echo -e "17) Launch binary"
        echo -e "0) Return to main menu"
        
        # Get user choice
        echo
        read -rp "Select an option (0-17): " choice
        
        case "$choice" in
            0) return 0 ;;
            1) # Edit name
                read -rp "Enter new repository name: " new_name
                if [ -n "$new_name" ]; then
                    sqlite3 "$DB_FILE" "UPDATE repositories SET name = '$new_name' WHERE id = $repo_id;"
                    echo -e "${GREEN}Repository name updated${NC}"
                    sleep 1
                fi
                ;;
            2) # Edit URL
                read -rp "Enter new repository URL: " new_url
                if [ -n "$new_url" ]; then
                    sqlite3 "$DB_FILE" "UPDATE repositories SET url = '$new_url' WHERE id = $repo_id;"
                    echo -e "${GREEN}Repository URL updated${NC}"
                    sleep 1
                fi
                ;;
            10) # Edit binary path
                echo -e "${BLUE}Current binary path: $binary_path${NC}"
                echo "1) Browse for binary"
                echo "2) Enter path manually"
                read -rp "Select an option: " binary_choice
                
                case "$binary_choice" in
                    1) # Browse for binary
                        local src_dir="$SRC_DIR/$name"
                        
                        # Debug: Check if directory exists
                        if [ ! -d "$src_dir" ]; then
                            echo -e "${RED}Error: Source directory $src_dir does not exist${NC}"
                            echo -e "${YELLOW}Creating directory...${NC}"
                            mkdir -p "$src_dir"
                            sleep 2
                        fi
                        
                        # Run the file browser directly
                        echo -e "${BLUE}Starting file browser...${NC}"
                        
                        # Call browse_for_binary directly (not capturing output)
                        browse_for_binary "$src_dir"
                        
                        # If we get here, the user either selected a binary or quit
                        # Check if a binary path was saved to a temporary file
                        if [ -f "/tmp/gitbuilder_selected_binary" ]; then
                            local selected_binary=$(cat "/tmp/gitbuilder_selected_binary")
                            rm -f "/tmp/gitbuilder_selected_binary"
                            
                            if [ -n "$selected_binary" ] && [ -x "$selected_binary" ]; then
                                # Update the database with the selected binary path
                                sqlite3 "$DB_FILE" "UPDATE repositories SET binary_path = '$selected_binary' WHERE id = $repo_id;"
                                echo -e "${GREEN}Binary path updated: $selected_binary${NC}"
                                sleep 2
                            else
                                echo -e "${RED}Error: Selected file is not executable${NC}"
                                sleep 2
                            fi
                        else
                            echo -e "${YELLOW}No binary selected${NC}"
                            sleep 1
                        fi
                        ;;
                    2) # Enter path manually
                        read -rp "Enter new binary path: " new_path
                        if [ -n "$new_path" ] && [ -x "$new_path" ]; then
                            sqlite3 "$DB_FILE" "UPDATE repositories SET binary_path = '$new_path' WHERE id = $repo_id;"
                            echo -e "${GREEN}Binary path updated${NC}"
                            sleep 1
                        elif [ -n "$new_path" ]; then
                            echo -e "${RED}Error: File does not exist or is not executable${NC}"
                            sleep 2
                        fi
                        ;;
                    *) 
                        echo -e "${RED}Invalid option${NC}"
                        sleep 1
                        ;;
                esac
                ;;
            11) # Edit build file path
                echo -e "${BLUE}Current build file path: $build_file_path${NC}"
                echo "1) Browse for build file"
                echo "2) Enter path manually"
                read -rp "Select an option: " build_file_choice
                
                case "$build_file_choice" in
                    1) # Browse for build file
                        local src_dir="$SRC_DIR/$name"
                        
                        # Check if directory exists
                        if [ ! -d "$src_dir" ]; then
                            echo -e "${RED}Error: Source directory $src_dir does not exist${NC}"
                            echo -e "${YELLOW}Creating directory...${NC}"
                            mkdir -p "$src_dir"
                            sleep 2
                        fi
                        
                        # Run the file browser directly
                        echo -e "${BLUE}Starting file browser...${NC}"
                        
                        # Call browse_for_binary directly (not capturing output)
                        browse_for_binary "$src_dir"
                        
                        # If we get here, the user either selected a file or quit
                        # Check if a file path was saved to a temporary file
                        if [ -f "/tmp/gitbuilder_selected_binary" ]; then
                            local selected_file=$(cat "/tmp/gitbuilder_selected_binary")
                            rm -f "/tmp/gitbuilder_selected_binary"
                            
                            if [ -n "$selected_file" ] && [ -f "$selected_file" ]; then
                                # Update the database with the selected file path
                                sqlite3 "$DB_FILE" "UPDATE repositories SET build_file_path = '$selected_file' WHERE id = $repo_id;"
                                echo -e "${GREEN}Build file path updated: $selected_file${NC}"
                                sleep 2
                            else
                                echo -e "${RED}Error: Selected file does not exist${NC}"
                                sleep 2
                            fi
                        else
                            echo -e "${YELLOW}No file selected${NC}"
                            sleep 1
                        fi
                        ;;
                    2) # Enter path manually
                        read -rp "Enter new build file path: " new_path
                        if [ -n "$new_path" ] && [ -f "$new_path" ]; then
                            sqlite3 "$DB_FILE" "UPDATE repositories SET build_file_path = '$new_path' WHERE id = $repo_id;"
                            echo -e "${GREEN}Build file path updated${NC}"
                            sleep 1
                        elif [ -n "$new_path" ]; then
                            echo -e "${RED}Error: File does not exist${NC}"
                            sleep 2
                        fi
                        ;;
                    *) 
                        echo -e "${RED}Invalid option${NC}"
                        sleep 1
                        ;;
                esac
                ;;
            12) # Edit configure flags
                read -rp "Enter new configure flags: " new_flags
                if [ -n "$new_flags" ] || [ -z "$new_flags" ]; then
                    update_build_config "$repo_id" "configure_flags" "$new_flags"
                    echo -e "${GREEN}Configure flags updated${NC}"
                    sleep 1
                fi
                ;;
            13) # Edit make flags
                read -rp "Enter new make flags: " new_flags
                if [ -n "$new_flags" ] || [ -z "$new_flags" ]; then
                    update_build_config "$repo_id" "make_flags" "$new_flags"
                    echo -e "${GREEN}Make flags updated${NC}"
                    sleep 1
                fi
                ;;
            14) # Edit CMake flags
                read -rp "Enter new CMake flags: " new_flags
                if [ -n "$new_flags" ] || [ -z "$new_flags" ]; then
                    update_build_config "$repo_id" "cmake_flags" "$new_flags"
                    echo -e "${GREEN}CMake flags updated${NC}"
                    sleep 1
                fi
                ;;
            15) # Edit dependencies
                read -rp "Enter software dependencies (space-separated): " new_deps
                if [ -n "$new_deps" ] || [ -z "$new_deps" ]; then
                    update_build_config "$repo_id" "dependencies" "$new_deps"
                    echo -e "${GREEN}Dependencies updated${NC}"
                    sleep 1
                fi
                ;;
            16) # Rebuild repository
                printf "\033c"
                echo -e "${BLUE}Rebuilding repository $name...${NC}"
                download_build "$repo_id" "rebuild"
                echo -e "\n${GREEN}Rebuild complete${NC}"
                sleep 2
                ;;
            17) # Launch binary
                printf "\033c"
                launch_binary "$repo_id"
                echo -e "\n${GREEN}Press any key to continue...${NC}"
                read -r -n 1
                ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

show_repos() {
    # First, update commit dates for repositories with missing or old commit dates
    echo -e "${BLUE}Updating repository information...${NC}"
    while IFS='|' read -r id name url last_commit; do
        # If last_commit is empty or older than 1 day, update it
        if [ -z "$last_commit" ] || [ "$(date -d "$last_commit" +%s 2>/dev/null || echo 0)" -lt "$(date -d "1 day ago" +%s)" ]; then
            update_last_commit_date "$id" "$url"
        fi
    done < <(sqlite3 "$DB_FILE" "SELECT id, name, url, last_commit FROM repositories WHERE deleted = 0;")
    
    echo -e "${BLUE}Available Repositories:${NC}"
    echo "┌────┬────────────────┬──────────────────────────┬─────────────────────┬─────────────────────┬────────┐"
    echo "│ ID │ Name           │ URL                      │ Last Commit         │ Last Built          │ Binary │"
    echo "├────┼────────────────┼──────────────────────────┼─────────────────────┼─────────────────────┼────────┤"
    
    # Now display the repositories with updated commit dates
    while IFS='|' read -r id name url last_commit last_built binary_path; do
        local binary_status="No"
        if [ -n "$binary_path" ] && [ -x "$binary_path" ]; then
            binary_status="Yes"
        fi
        
        # Format the last commit date nicely
        local formatted_commit_date=""
        if [ -n "$last_commit" ]; then
            formatted_commit_date=$(date -d "$last_commit" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$last_commit")
        fi
        
        printf "│ %-2s │ %-14s │ %-24s │ %-19s │ %-19s │ %-6s │\n" \
            "$id" "${name:0:14}" "${url:0:24}" \
            "${formatted_commit_date:0:19}" "${last_built:0:19}" "$binary_status"
    done < <(sqlite3 "$DB_FILE" "SELECT id, name, url, last_commit, last_built, binary_path FROM repositories WHERE deleted = 0;")
    
    echo "└────┴────────────────┴──────────────────────────┴─────────────────────┴─────────────────────┴────────┘"
}

# Launch binary
launch_binary() {
    local repo_id="$1"
    
    # Get repository info from database
    local binary_path name
    IFS='|' read -r binary_path name <<< $(sqlite3 "$DB_FILE" "SELECT binary_path, name FROM repositories WHERE id = $repo_id;")
    
    # Check if we got valid data
    if [ -z "$name" ]; then
        error "Could not find repository data"
        return 1
    fi
    
    # Construct source directory path
    local src_dir="$SRC_DIR/$name"
    
    # If no binary is registered, try to find one
    if [ -z "$binary_path" ] || [ ! -x "$binary_path" ]; then
        echo -e "${YELLOW}No binary registered or binary not found. Searching for binaries...${NC}"
        
        # Look for binaries
        echo -e "\n${BLUE}Looking for binary files...${NC}"
        local binaries=()
        # Capture each line of output as a separate array element
        mapfile -t binaries < <(find_binary "$src_dir" "$name")
        
        if [ ${#binaries[@]} -gt 0 ]; then
            echo -e "\n${BLUE}Found potential binary files:${NC}"
            local i=1
            for binary in "${binaries[@]}"; do
                echo "$i) $binary"
                ((i++))
            done
            
            echo "b) Browse for binary"
            local choice
            read -rp "Select binary to register (1-${#binaries[@]}, or 'b' to browse): " choice
            
            if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#binaries[@]}" ]; then
                binary_path="${binaries[$((choice-1))]}"
            elif [[ $choice == "b" ]]; then
                # Clear the screen before calling the browser to avoid display issues
                printf "\033c"
                # Call the browse_for_binary function and capture its output and return code
                binary_path=$(browse_for_binary "$src_dir")
                local browse_status=$?
                # Clear the screen again after returning from the browser
                printf "\033c"
                if [ $browse_status -ne 0 ]; then
                    echo -e "${YELLOW}Binary selection cancelled${NC}"
                    return 1
                fi
                
                # Verify the selected binary exists and is executable
                if [ ! -x "$binary_path" ]; then
                    echo -e "${RED}Error: Selected binary is not executable${NC}"
                    return 1
                fi
            else
                return 1
            fi
            
            # Save the selected binary path
            sqlite3 "$DB_FILE" "UPDATE repositories SET binary_path = '$binary_path' WHERE id = $repo_id;"
            echo -e "${GREEN}Binary registered: $binary_path${NC}"
        else
            echo -e "${YELLOW}No binaries found automatically.${NC}"
            local browse_choice
            read -rp "Would you like to browse for the binary? (Y/n): " browse_choice
            if [[ ! $browse_choice =~ ^[Nn]$ ]]; then
                # Clear the screen before calling the browser to avoid display issues
                printf "\033c"
                # Call the browse_for_binary function and capture its output and return code
                binary_path=$(browse_for_binary "$src_dir")
                local browse_status=$?
                # Clear the screen again after returning from the browser
                printf "\033c"
                if [ $browse_status -ne 0 ]; then
                    echo -e "${YELLOW}Binary selection cancelled${NC}"
                    return 1
                fi
                
                # Verify the selected binary exists and is executable
                if [ ! -x "$binary_path" ]; then
                    echo -e "${RED}Error: Selected binary is not executable${NC}"
                    return 1
                fi
                
                # Save the selected binary path
                sqlite3 "$DB_FILE" "UPDATE repositories SET binary_path = '$binary_path' WHERE id = $repo_id;"
                echo -e "${GREEN}Binary registered: $binary_path${NC}"
            else
                return 1
            fi
        fi
    fi
    
    # Ask for launch mode
    echo -e "\n${GREEN}Launch Options:${NC}"
    echo "1) Quiet (run in background)"
    echo "2) Verbose (show output)"
    
    local launch_mode
    read -rp "Select launch mode (1-2): " launch_mode
    
    case $launch_mode in
        1)
            echo -e "\n${BLUE}Launching binary in background: $binary_path${NC}"
            nohup "$binary_path" > /dev/null 2>&1 &
            echo -e "${GREEN}Binary launched! You can continue using gitbuilder.${NC}"
            ;;
        2)
            echo -e "\n${BLUE}Launching binary with output: $binary_path${NC}"
            "$binary_path"
            ;;
        *)
            error "Invalid launch mode"
            return 1
            ;;
    esac
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "\n${YELLOW}GitHub Package Manager${NC}"
        echo "1) Add repository"
        echo "2) Edit repository"
        echo "3) Remove repository"
        echo "4) Download and build"
        echo "5) See/edit build details"
        echo "6) Launch binary"
        echo "7) Update all repositories"
        echo "8) Exit"
        
        show_repos
        
        read -rp "Select an option: " choice
        case $choice in
            1) add_repo || continue ;;
            2)
                read -rp "Enter repository ID to edit: " id
                edit_repo "$id" || continue
                ;;
            3) remove_repo || continue ;;
            4)
                read -rp "Enter repository ID to build: " id
                download_build "$id" || continue
                ;;
            5)
                read -rp "Enter repository ID to view details: " id
                # Validate that ID is provided and is a number
                if [[ -z "$id" ]] || ! [[ "$id" =~ ^[0-9]+$ ]]; then
                    error "Invalid repository ID: $id"
                    read -n 1 -s -r -p "Press any key to continue..."
                    continue
                fi
                show_build_details "$id" || continue
                ;;
            6)
                read -rp "Enter repository ID to launch: " id
                if launch_binary "$id"; then
                    echo -e "\nPress any key to continue..."
                    read -r -n 1
                fi
                ;;
            7)
                update_all_repos || continue
                ;;
            8) exit 0 ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main execution
check_requirements
init_db
main_menu
