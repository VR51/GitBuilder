# GitBuilder - GitHub Repository Manager and Build Automation Tool

**Version 2.0.2**

GitBuilder is a powerful command-line tool for managing GitHub repositories, automating the build process, and launching binaries. It provides a comprehensive solution for developers who frequently work with multiple GitHub projects.

GitBuilder has evolved into a comprehensive tool with:

- **Smart build automation**: Auto-detects CMake, Autotools, Make, Meson, Cargo, Go, npm and more
- **Full repository management**: Add, edit, search, track dependencies
- **Build optimization**: Parallel builds, ccache, RAM disk support
- **Desktop integration**: Create launchers for built apps and GitBuilder itself
- **Portable configs**: gitbuildfile import/export with ~/ path handling
- **Intuitive navigation**: Hotkeys (H, L, G, Esc), contextual help hints
- **Consolidated help system**: 12 detailed sections accessible via G + #

It's a genuinely useful tool for anyone who builds software from GitHub repositories. Enjoy using it! 🚀

**Donate**: https://paypal.me/vr51/

## Features

### Core Features
- **Repository Management**: Add, edit, remove, and search GitHub repositories
- **Automated Building**: Detect and use the appropriate build system (CMake, Autotools, Make, Gradle, Maven, etc.)
- **Binary Management**: Find, register, and launch built binaries with an interactive file browser
- **Build Configuration**: Customize build flags for different build systems
- **Repository Updates**: Keep repositories up-to-date with the latest commits

### Build Optimization
- **Parallel Builds**: Automatic CPU core detection for faster compilation
- **Build Caching**: Integration with ccache for faster rebuilds
- **RAM Disk Support**: Dynamic RAM disk (uses up to 75% of available RAM) for significantly faster builds
- **Debug Symbol Stripping**: Option to strip debug symbols for smaller, faster binaries

### Advanced Features (New in v2.0)
- **Build Profiles**: Save and reuse build configurations across repositories
- **Build Queue**: Queue multiple repositories for sequential building with priority support
- **Build History**: Track all builds with timestamps, duration, and success/failure status
- **Build Progress**: Live elapsed time, estimated remaining time, and log activity during builds
- **Dependency Graph**: Define and track dependencies between repositories
- **Desktop Notifications**: Get notified immediately when builds complete (requires `notify-send`)
- **Theme System**: Choose from multiple color themes (default, ocean, forest, mono)
- **Search & Filter**: Quickly find repositories by name or URL
- **Backup & Restore**: Export and import your entire database
- **Help System**: Press H at any menu for instant help
- **Editor Selection**: Choose your preferred text editor for notes
- **Binary Versioning**: Backup binaries before rebuilds with automatic rotation (limit: 3)
- **Secondary Binaries**: Track and launch all binaries built by a repository
- **Desktop Launchers**: Create .desktop files with icon browsing and menu category support, auto-updated on rebuild
- **Quick Launch**: Press L to quickly launch any registered binary
- **Auto-Update**: Check for and install GitBuilder updates with one click

### Import/Export
- [**gitbuildfile Support**](https://github.com/VR51/GitBuilder/blob/main/README.md#gitbuildfile-support): Save and import build configurations
- **Database Backup**: Full database backup and restore functionality

### Keyboard Shortcuts
- **Esc**: Return to previous screen (or exit from main menu)
- **H**: Show full help documentation (works as hotkey from any menu)
- **L**: Quick launch a binary (main menu and build details)
- **G**: Go to specific help section (enter section number 1-12)

### Help System
- Consolidated help documentation in the `HELP` file
- Press **H** from any menu to view full help with `less`
- Press **G** to jump to a specific help section by number
- Menu headings show help key hints (e.g., "Help: G + 2")
- 12 detailed help sections covering all features

### File Browser
- Interactive file browser for selecting binaries, icons, and build files
- Shows current directory path prominently
- Navigate with number keys, go to parent with 0
- **Esc** or **q** to cancel and return

### Command Line Interface
- `-h, --help`: Show help message
- `-v, --version`: Show version information
- `-l, --list`: List all repositories
- `-b, --build ID`: Build a specific repository
- `-u, --update`: Update all repository commit dates
- `--backup FILE`: Backup database to file
- `--restore FILE`: Restore database from file
- `--check-update`: Check for GitBuilder updates

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/vr51/gitbuilder.git
   ```

2. Make the script executable:
   ```bash
   chmod +x gitbuilder
   ```

3. Optionally, move it to a directory in your PATH:
   ```bash
   sudo cp gitbuilder /usr/local/bin/
   ```

## Dependencies

GitBuilder requires the following dependencies:
- sqlite3
- curl
- jq
- git
- make
- cmake
- file
- ccache (for build caching)

The script will check for these dependencies and prompt you to install any that are missing.

## Usage

Simply run the script:

```bash
./gitbuilder
```

### Main Menu Options

The main menu is organized into categories:

**Repository Management**
1. **Add a repository**: Add a new GitHub repository
2. **Edit a repository**: Modify repository details
3. **Remove a repository**: Delete a repository
4. **Search existing repositories**: Find repositories by name or URL

**Build Operations**
5. **Build an existing repository**: Clone and build a repository
6. **See build queue**: Manage queued builds with priority
7. **Build profiles**: Create and manage reusable build configurations
8. **Build history**: View past builds with timestamps and duration

**Repository Details**
9. **See/edit build details**: View and edit comprehensive build information
10. **Launch a binary**: Run a built binary
11. **Dependencies**: Manage repository dependencies
12. **Repository notes**: View and edit notes

**Import/Export**
13. **Save gitbuildfile**: Export repository settings
14. **Save all gitbuildfiles**: Export all repository settings at once
15. **Import gitbuildfile**: Import build configuration

**System**
16. **Refresh Git repository information**: Update all repositories
17. **Settings**: Configure themes, notifications, backups, and more
18. **Install GitBuilder desktop launcher**: Create a launcher for GitBuilder (only shown if not installed)

## gitbuildfile Support

GitBuilder supports a custom build configuration file called `gitbuildfile`. If this file is found in the root of a repository, you will be prompted whether to use the build configuration from the file or skip it and use existing/auto-detected settings.

### Gitbuildfiles Directory

GitBuilder maintains a `gitbuildfiles` directory alongside the script for storing and importing build configurations. When you save a gitbuildfile (menu option 8), a copy is automatically saved to this directory.

Files in this directory may be named gitbuildfile or gitbuildfile.<repo_name> e.g. gitbuildfile.zesarux.

### Importing Gitbuildfiles

Use menu option 9 to import a gitbuildfile:
- Browse and select from saved gitbuildfiles
- View parsed configuration before importing
- Update existing repositories or add new ones
- Repository URL is included for seamless imports

### gitbuildfile Format

The `gitbuildfile` can contain the following parameters:

```
# Repository information
REPO_NAME="example-repo"
REPO_URL="https://github.com/user/example-repo.git"

# Build method (cmake, autotools, make, etc.)
BUILD_METHOD="cmake"

# Space-separated list of dependencies
DEPENDENCIES="libsdl2-dev libssl-dev"

# Path to the build file (use ~/ for home directory)
BUILD_FILE="src/CMakeLists.txt"

# Build flags
CONFIGURE_FLAGS="--enable-feature1 --disable-feature2"
MAKE_FLAGS="-j4"
CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"

# Path to the compiled binary (use ~/ for home directory)
BINARY_PATH="~/.local/share/gitbuilder/src/example-repo/build/bin/example"

# Desktop launcher settings
LAUNCHER_ICON="~/.local/share/gitbuilder/src/example-repo/icon.png"
LAUNCHER_CATEGORY="Development"

# Repository notes (displayed after build)
NOTES="Special build instructions or notes"
```

All parameters are optional. If a parameter is not specified, GitBuilder will use the auto-detected value or the value stored in the database.

## Build System Support

GitBuilder automatically detects and uses the appropriate build system:

- **CMake**: For projects using CMakeLists.txt
- **Autotools**: For projects using configure scripts or autogen.sh
- **Make**: For projects using Makefiles
- **Gradle**: For Java/Android projects using build.gradle
- **Maven**: For Java projects using pom.xml
- **Python**: For Python projects with setup.py
- **Node.js**: For JavaScript projects with package.json
- **Meson**: For projects using meson.build

## Binary Management

After building a project, GitBuilder can:
- Automatically detect built binaries
- Store all discovered binaries for later access (secondary binaries)
- Register them for easy access using an interactive file browser
- Browse directories and select executable files with a user-friendly interface
- Launch binaries in either quiet (background) or verbose (terminal output) mode
- Launch secondary binaries from the build details menu
- **Prompt to create a desktop launcher** after successful build and binary registration (only if one doesn't exist)
- **Auto-update desktop launchers** when binary path changes on rebuild
- Backup existing binaries before rebuilding (with automatic rotation, limit: 3)

## Build Optimization

### Parallel Builds

GitBuilder automatically detects the number of CPU cores and uses parallel compilation:
- Make: `-j<cores>`
- Gradle: `--parallel --max-workers=<cores>`
- Maven: `-T <cores>`
- Ninja/Meson: `-j <cores>`

Override with the `GITBUILDER_JOBS` environment variable.

### RAM Disk Support

For faster builds, GitBuilder can use a RAM disk:
- Dynamically allocates up to 75% of available RAM (no hard cap)
- tmpfs only uses memory as files are written, not pre-allocated
- Automatically checks available RAM (minimum 2GB required)
- Mounts a tmpfs filesystem for build operations
- Copies source to RAM disk before building
- Copies results back after successful build
- Automatically unmounts on completion or exit
- Sudo is requested with clear explanation when needed

Enable per-repository in "See/edit build details" (option 17) or when adding a new repository.

### Debug Symbol Stripping

Enable debug stripping for smaller, faster binaries:
- Sets `CFLAGS="-O2 -DNDEBUG"`
- Uses `CMAKE_BUILD_TYPE=Release` for CMake projects
- Uses `--buildtype=release` for Meson projects

Enable per-repository in "See/edit build details" (option 16) or when adding a new repository.

## Configuration

GitBuilder stores all data in `~/.local/share/gitbuilder/`:
- **Database**: `repos.db` - Main SQLite database
- **Config**: `config` - User preferences (theme, notifications, etc.)
- **Source code**: `src/` - Cloned repositories
- **Build logs**: Within each project directory
- **Build history**: `history/` - Historical build records
- **Build profiles**: `profiles/` - Saved build configurations
- **Backups**: `backups/` - Database backups
- **RAM disk mount point**: `ramdisk/build/`

Script-relative directories:
- **Gitbuildfiles**: `gitbuildfiles/` - Saved build configurations
- **Plugins**: `plugins/` - Custom build system plugins (future use)

### Settings Menu

Access via main menu option 16:
- **Theme**: Choose from default, ocean, forest, or mono
- **Notifications**: Enable/disable desktop notifications
- **Auto-update check**: Configure update check interval
- **Backup/Restore**: Manage database backups
- **Editor**: Change preferred text editor (via Repository Notes menu)

## Examples

### Adding and Building a Repository

1. Select "Add repository" from the main menu
2. Enter the repository name (e.g., "ZEsarUX")
3. Enter the GitHub URL (e.g., "https://github.com/chernandezba/zesarux.git")
4. Select "Download and build" from the main menu
5. Enter the repository ID to build

### Notes on Binary Management

GitBuilder can now detect and install software libraries required by individual projects. You can specify dependencies for each repository in the build details menu.

Binaries are installed locally in the `~/.local/share/gitbuilder/src/` directory. This means you do not usually need to use sudo to launch them.

### Viewing and Editing Build Details

1. Select "See/edit build details" from the main menu
2. Enter the repository ID
3. View and edit comprehensive information about the repository, including:
   - Repository details (name, URL, commit dates)
   - Build status and type
   - Binary information and path (with interactive file browser)
   - Custom build file path (with interactive file browser)
   - Build configuration flags for different build systems (Configure, Make, CMake)
   - Software dependencies required for building
   - **Build Optimization settings**:
     - Strip debug symbols (option 16)
     - Use RAM disk (option 17)
4. Use the interactive menu to edit repository details and build configurations

### Launching a Binary

1. Select "Launch binary" from the main menu
2. Enter the repository ID
3. Choose launch mode (quiet or verbose)
4. The binary will be executed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU General Public License v3.0 - see the header in the script file for details.

## Donate

If you find this tool useful, please donate:
- PayPal: https://paypal.me/vr51/

## Authors

- **VR51** - *Prompt Engineer* *Maintainer* *Developer* *Project Supervisor*
- **Cascade** - *The code work*

---

*GitBuilder - Making GitHub source code build management easier since 2025*
