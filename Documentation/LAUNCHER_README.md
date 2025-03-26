# Janet Launcher

This directory contains scripts to create various launchers for Janet with custom icons.

## Quick Start

To create the Janet launchers, run these scripts:

```bash
# Create the AppleScript-based launcher (may require permissions)
./create_janet_launcher.sh

# Create a terminal-based launcher shortcut
./create_shell_launcher_shortcut.sh

# Create a direct launcher (no AppleScript, no permissions required)
./create_direct_launcher.sh
```

After running these scripts, you'll find:
- `Janet Launcher.app` in the current directory (AppleScript-based)
- `Janet Direct Launcher.app` in the current directory (direct launcher)
- `Janet.app` (symbolic link to AppleScript launcher) on your Desktop
- `Janet Direct.app` (symbolic link to direct launcher) on your Desktop
- `Launch Janet (Terminal).command` on your Desktop (terminal-based)

## Launch Options

You have several options to launch Janet:

### 1. Direct Launcher (Recommended)

Double-click on `Janet Direct Launcher.app` in this directory or the `Janet Direct.app` symbolic link on your Desktop. This launcher:
- Doesn't use AppleScript
- Doesn't require any special permissions
- Has a custom icon
- Will launch Janet directly

### 2. GUI Launcher (AppleScript-based)

Double-click on `Janet Launcher.app` in this directory or the `Janet.app` symbolic link on your Desktop. This launcher:
- Uses AppleScript
- May require permissions to control System Events
- Has a custom icon
- Provides more detailed feedback

### 3. Terminal Launcher

Double-click on `Launch Janet (Terminal).command` on your Desktop. This will:
- Open a terminal window
- Launch Janet without requiring any special permissions
- Show detailed output in the terminal

### 4. Shell Script Launcher (Manual)

If you prefer to run the shell script manually:

```bash
./launch_janet.sh
```

### 5. Direct Launch

You can always run Janet directly using:

```bash
./Scripts/run_janet.sh
```

## macOS Authorization

When you first run the AppleScript-based launcher, macOS may display a security prompt asking for permission to control System Events. This is normal and required for that specific launcher to function properly.

If you encounter an "not authorized to send Apple events to System Events" error:

1. **Use the Direct Launcher**: The simplest solution is to use the `Janet Direct.app` launcher on your Desktop, which doesn't require any special permissions.

2. **Use the Terminal Launcher**: Alternatively, use the `Launch Janet (Terminal).command` shortcut on your Desktop.

3. **Try to Grant Permissions**: If you still want to use the AppleScript launcher:
   - Open System Preferences > Security & Privacy > Privacy > Automation
   - Find "Janet Launcher" in the list and check the box next to "System Events"
   - If it's not listed, try running the launcher once, then check again
   - You may need to reset the permissions database: `tccutil reset AppleEvents`

## Icon Issues

If the custom icons are not showing up:

1. **Install fileicon utility**:
   ```bash
   brew install fileicon
   ```

2. **Apply icons manually**:
   ```bash
   # Create the icon
   ./create_janet_icon.sh
   
   # Apply to launchers
   fileicon set "Janet Launcher.app" JanetIcon.icns
   fileicon set "Janet Direct Launcher.app" JanetIcon.icns
   fileicon set "$HOME/Desktop/Janet.app" JanetIcon.icns
   fileicon set "$HOME/Desktop/Janet Direct.app" JanetIcon.icns
   
   # Restart Finder
   killall Finder
   ```

3. **Rebuild launchers**:
   ```bash
   # Remove existing launchers
   rm -rf "Janet Launcher.app" "Janet Direct Launcher.app"
   rm -f "$HOME/Desktop/Janet.app" "$HOME/Desktop/Janet Direct.app"
   
   # Rebuild with improved scripts
   ./create_janet_launcher.sh
   ./create_direct_launcher.sh
   ```

4. **Clear icon cache** (if icons still don't appear):
   ```bash
   sudo rm -rfv /Library/Caches/com.apple.iconservices.store
   sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \;
   sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \;
   killall Dock
   killall Finder
   ```

## Troubleshooting

If you encounter any issues:

1. Make sure the scripts are executable:
   ```bash
   chmod +x create_janet_launcher.sh create_janet_icon.sh launch_janet.sh create_shell_launcher_shortcut.sh create_direct_launcher.sh
   ```

2. Check that the paths in the scripts match your system configuration

3. If the icon doesn't appear correctly, try:
   ```bash
   touch "Janet Launcher.app"
   touch "Janet Direct Launcher.app"
   ```
   to refresh the icon cache

4. For authorization issues, use the Direct Launcher or Terminal Launcher which don't require special permissions 