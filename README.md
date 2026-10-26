# Joker for Windows

**Download: https://xdroppar.github.io/joker-pc/**

This repo builds and publishes the Windows installer.

- `installer/joker.iss` is the setup wizard (Inno Setup 6). It installs per user, needs no admin rights, and adds Start Menu and desktop shortcuts plus an uninstall entry.
- `launcher/JokerLauncher.cs` is what the shortcuts open. It checks for a newer release, offers to update, then starts the game.
- `art/make-art.py` makes the icon and the wizard images from the game's icon and an in-game frame.
- `docs/` is the download page, served by GitHub Pages.
- `publish.ps1 <build folder>` builds the launcher and setup and publishes them as the latest release.
