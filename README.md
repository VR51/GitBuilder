# GitBuilder - GitHub Repository Manager and Build Automation Tool

GitBuilder is a powerful command-line tool for managing GitHub repositories, automating the build process, and launching binaries. It provides a comprehensive solution for developers who frequently work with multiple GitHub projects.

## Features

- **Repository Management**: Add, edit, and remove GitHub repositories
- **Automated Building**: Detect and use the appropriate build system (CMake, Autotools, Make, etc.)
- **Binary Management**: Find, register, and launch built binaries
- **Build Configuration**: Customize build flags for different build systems
- **Repository Updates**: Keep repositories up-to-date with the latest commits
- **Build Details**: View comprehensive information about repositories and their build status
- **Smart Caching**: Efficient handling of GitHub API requests with 4-hour caching

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
4. **Download and build**: Clone and build a repository
5. **See build details**: View comprehensive information about a repository
6. **Configure build options**: Set custom build flags
7. **Launch binary**: Run a built binary
8. **Update all repositories**: Update all repositories to their latest versions
9. **Exit**: Quit the application

## Build System Support

GitBuilder automatically detects and uses the appropriate build system:

- **CMake**: For projects using CMakeLists.txt
- **Autotools**: For projects using configure scripts or autogen.sh
- **Make**: For projects using Makefiles
- **Others**: Support for Python, Node.js, Meson, Gradle, and Maven projects

## Binary Management

After building a project, GitBuilder can:
- Automatically detect built binaries
- Register them for easy access
- Launch them in either quiet (background) or verbose (terminal output) mode

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

### Viewing Build Details

1. Select "See build details" from the main menu
2. Enter the repository ID
3. View comprehensive information about the repository, including:
   - Repository details (name, URL, commit dates)
   - Build status and type
   - Binary information
   - Build configuration flags

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
- **VR51** - *Prompt Engineer*

---

*GitBuilder - Making GitHub project management easier since 2025*
