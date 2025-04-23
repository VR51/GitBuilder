# GitBuilder - GitHub Repository Manager and Build Automation Tool

GitBuilder is a powerful command-line tool for managing GitHub repositories, automating the build process, and launching binaries. It provides a comprehensive solution for developers who frequently work with multiple GitHub projects.

## Features

- **Repository Management**: Add, edit, and remove GitHub repositories
- **Automated Building**: Detect and use the appropriate build system (CMake, Autotools, Make, Gradle, Maven, etc.)
- **Binary Management**: Find, register, and launch built binaries with an interactive file browser
- **Build Configuration**: Customize build flags for different build systems
- **Repository Updates**: Keep repositories up-to-date with the latest commits
- **Build Details**: View and edit comprehensive information about repositories and their build status
- **Smart Caching**: Efficient handling of GitHub API requests with 4-hour caching
- **Existing Clone Support**: Option to use existing repository clones instead of downloading fresh copies
- **Interactive File Browser**: Browse directories and select executable files with an intuitive interface
- **Dependency Management**: Specify and automatically install software dependencies for each repository
- **Custom Build File Support**: Specify custom build file paths for repositories
- **gitbuildfile Support**: Override auto-detection with a custom build configuration file

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

The script will check for these dependencies and prompt you to install any that are missing.

## Usage

Simply run the script:

```bash
./gitbuilder
```

### Main Menu Options

1. **Add repository**: Add a new GitHub repository to manage
2. **Edit repository**: Modify an existing repository's details
3. **Remove repository**: Delete a repository from the database
4. **Download and build**: Clone and build a repository (with option to use existing clones)
5. **See/edit build details**: View and edit comprehensive information about a repository, including build configuration, dependencies, and build file paths
6. **Launch binary**: Run a built binary
7. **Update all repositories**: Update all repositories to their latest versions
8. **Exit**: Quit the application

## gitbuildfile Support

GitBuilder now supports a custom build configuration file called `gitbuildfile`. If this file is found in the root of a repository, it will override the auto-detection process and use the specified build configuration.

The `gitbuildfile` can contain the following parameters:

```
# Repository information
REPO_NAME="example-repo"

# Build method (cmake, autotools, make, etc.)
BUILD_METHOD="cmake"

# Space-separated list of dependencies
DEPENDENCIES="libsdl2-dev libssl-dev"

# Path to the build file (relative to repo root or absolute)
BUILD_FILE="src/CMakeLists.txt"

# Build flags
CONFIGURE_FLAGS="--enable-feature1 --disable-feature2"
MAKE_FLAGS="-j4"
CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"

# Path to the compiled binary (relative to repo root or absolute)
BINARY_PATH="build/bin/example"
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
- Register them for easy access using an interactive file browser
- Browse directories and select executable files with a user-friendly interface
- Launch binaries in either quiet (background) or verbose (terminal output) mode

## Configuration

GitBuilder stores all data in `~/.local/share/gitbuilder/`:
- Database: `repos.db`
- Source code: `src/`
- Build logs: Within each project directory

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

If you find this tool useful, please consider donating:
- PayPal: https://paypal.me/vr51/

## Authors

- **Cascade** - *Initial work*
- **VR51** - *Prompt Engineer*, *Maintainer*, *Developer*, *Project Supervisor*

---

*GitBuilder - Making GitHub project management easier since 2025*
