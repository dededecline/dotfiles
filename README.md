# Dededecline's Dotfiles

A comprehensive macOS dotfiles repository managed with [chezmoi](https://chezmoi.io). Features include automated system configuration, package management, and personalized settings.

## Table of Contents

- [Repository Structure](#repository-structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Repository Structure

```
├── README.md             # This file
├── LICENSE               # MIT License
├── bootstrap.sh          # One-click setup script
├── .chezmoiversion       # Required chezmoi version (2.62.5)
├── .chezmoiroot          # Chezmoi root directory (home)
├── .gitignore            # Git ignore patterns
├── assets/               # Static assets
│   └── wallpapers/       # Wallpaper directory     
└── home/                 # Dotfiles source directory
    ├── dot_config/       # Configuration files (~/.config)
    │   └── cutler/       # System settings configuration
    └── .chezmoiscripts/  # Chezmoi automation scripts
        └── darwin/       # macOS-specific scripts
```

## Features

🖥️ **System Configuration**

📦 **Package Management**

🎨 **User Interface Customization**

🖱️ **Input & Navigation Management**

🌐 **Network Configuration**

📁 **File Management**
## Prerequisites

- **macOS**: Any supported version on Apple Silicon hardware
- **Internet Connection**: Required for downloading packages
- **Admin Access**: Needed for system-level configurations

## Setup Instructions

### Quick Setup (Recommended)

1. **Clone and Bootstrap**:
   ```bash
   mkdir -p ~/.local/share/ && cd "$_"
   curl -L https://github.com/dededecline/dotfiles/archive/refs/heads/main.zip -o repo.zip
   unzip -q repo.zip && mv dotfiles-main chezmoi && cd "$_"
   ./bootstrap.sh
   ```

### Manual Setup

1. **Install Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```

2. **Install Homebrew**:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Install Rosetta 2** (for Apple Silicon Macs):
   ```bash
   softwareupdate --install-rosetta --agree-to-license
   ```

4. **Install chezmoi**:
   ```bash
   brew install chezmoi
   ```

5. **Initialize dotfiles**:
   ```bash
   chezmoi init --apply https://github.com/dededecline/dotfiles.git
   ```

## Usage Guide

### Managing Your Dotfiles

#### Apply Changes
```bash
chezmoi apply
```

#### Check What Would Change
```bash
chezmoi diff
```

#### Update from Repository
```bash
chezmoi update
```

#### Edit Configuration Files
```bash
# Edit in the source directory
chezmoi edit ~/.config/cutler/config.toml

# Apply changes
chezmoi apply
```

### Adding New Configurations

#### Add a New Dotfile
```bash
# Add an existing file to chezmoi
chezmoi add ~/.zshrc

# Edit the template
chezmoi edit ~/.zshrc
```

#### Modify Package Lists

Edit `home/.chezmoiscripts/darwin/run_onchange_before_install-packages.sh.tmpl`:

- **Homebrew Taps**: Add to `$taps` list
- **Formulae**: Add to `$brews` list  
- **Casks**: Add to `$casks` list
- **Mac App Store**: Add to `$mas` dictionary with [app ID](https://simplemdm.com/blog/how-to-find-the-bundle-id-for-an-application/)

### System Settings

The `cutler` configuration (`home/dot_config/cutler/config.toml`) manages:

- **System Preferences**: Dock, Finder, trackpad, keyboard
- **Security Settings**: Touch ID, quarantine, permissions
- **UI Customization**: Menu bar, screenshots, dark mode
- **Network Configuration**: DNS servers, hostname
- All other macOS settings that can be declaratively managed

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you have admin privileges and run with `sudo` when needed
2. **Homebrew Not Found**: Check if Homebrew is properly installed and in PATH
3. **App Store Login**: You may need to sign in to the Mac App Store for `mas` installations
4. **chezmoi Conflicts**: Use `chezmoi diff` to see what would change before applying

### Getting Help

- Check the [chezmoi documentation](https://chezmoi.io)
- Review [cutler examples](https://github.com/hitblast/cutler/tree/main/examples)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This dotfiles configuration is optimized for macOS and uses chezmoi for cross-machine synchronization. Always review the configuration before applying to ensure it matches your preferences. 
