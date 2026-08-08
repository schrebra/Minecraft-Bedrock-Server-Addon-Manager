
# Bedrock Dedicated Server Addon Manager

A modern, GUI-based tool designed to simplify the installation and management of add-ons for Minecraft Bedrock Dedicated Servers (BDS). Stop manually extracting `.mcaddon` files, digging through folders, and hand-editing JSON files. Just drag, drop, and play.

<table>
  <tr>
    <td align="center">
      <a href="Screenshots/2026-08-04_200835.png">
        <img src="Screenshots/2026-08-04_200835.png" alt="Minecraft Bedrock Manager Screenshot 1" width="100%" />
      </a>
    </td>
    <td align="center">
      <a href="Screenshots/2026-08-01_154250.png">
        <img src="Screenshots/2026-08-01_154250.png" alt="Minecraft Bedrock Manager Screenshot 2" width="100%" />
      </a>
    </td>
  </tr>
</table>

## 📖 Table of Contents
- [Why does this exist?](#-why-does-this-exist)
- [Who should use this?](#-who-should-use-this)
- [✨ Features](#-features)
- [🚀 Getting Started](#-getting-started)
- [⚙️ How It Works](#️-how-it-works)
- [📋 Requirements](#-requirements)

## 🤔 Why does this exist?

Installing add-ons on a Bedrock Dedicated Server is notoriously tedious. A standard `.mcaddon` file is just a ZIP archive containing `.mcpack` files, which are *also* ZIP archives. To install them manually, you have to:
1. Extract the `.mcaddon`.
2. Extract the nested `.mcpack` files.
3. Figure out which folder is the Behavior Pack and which is the Resource Pack.
4. Move them to the correct `behavior_packs` or `resource_packs` directories on your server.
5. Manually calculate the UUID and version of the packs.
6. Edit `world_behavior_packs.json` and `world_resource_packs.json` in your world folder to register the packs.

If you run a server with multiple add-ons, this process is time-consuming and prone to breaking your world files. **Bedrock Dedicated Server Addon Manager** was built to automate this entire process into a single drag-and-drop action.

## 🎯 Who should use this?

- **Server Admins & Owners:** Anyone running a Minecraft Bedrock Dedicated Server who wants to quickly test or deploy new add-ons without FTPing files and editing JSONs manually.
- **Map Makers & Creators:** Quickly install dependency packs onto a test server to see how they interact with your world.
- **Players transitioning to Dedicated Servers:** If you are used to the simple one-click install of the Minecraft Marketplace/Realms and want a similar experience for your standalone server.

## ✨ Features

- **Drag & Drop Interface:** Drop one or multiple `.mcaddon` or `.mcpack` files directly into the app. 
- **Recursive Smart Extraction:** Automatically drills down through nested archives (e.g., an `.mcaddon` containing `.mcpack` files containing `.zip` files) and extracts them safely.
- **Long Path Bypass:** Natively uses Windows `\\?\` long-path syntax to completely bypass the 260-character path limit, preventing silent extraction failures on deeply nested packs.
- **Automatic JSON Registration:** Automatically reads the pack `manifest.json`, detects if it's a Behavior or Resource pack, and safely registers the UUID and version into your world's `world_behavior_packs.json` or `world_resource_packs.json`.
- **Manifest Sanitizer:** Strips Minecraft formatting codes (like `§7`, `§b`, `§r`) from the `manifest.json` during installation. This prevents weird "alien text" from appearing in your dedicated server console.
- **Add-on Manager:** View all currently active packs in your world. Select and remove add-ons with a single click (safely deletes the folder and unregisters it from the JSON).
- **Modern, Flat UI:** 
  - Clean pastel design with a dark-mode terminal log.
  - Custom-drawn, artifact-free buttons and panels.
  - Drop zone acts as a visual progress bar, filling up green as your addon installs.
- **Overwrite Protection:** Toggle the "Overwrite existing" checkbox to safely replace packs that share the same UUID, or automatically append a UUID suffix to prevent folder collisions.

## 🚀 Getting Started

1. Ensure you have the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) installed on your Windows machine.
2. Save the provided PowerShell bootstrapper script to your computer as `Install-BDSAM.ps1`.
3. Right-click the script and select **Run with PowerShell**.
4. The script will automatically:
   - Create a C# project in `C:\Bedrock\BedrockDedicatedServerAddonManager`.
   - Generate all necessary code files.
   - Build the application in Release mode.
   - Launch the GUI automatically.

## ⚙️ How It Works

1. **Set Server Path:** On first launch, set your Bedrock Server directory (the folder containing `bedrock_server.exe`). The tool validates this path and remembers it for next time.
2. **Drag & Drop:** Drag an `.mcaddon` from your downloads onto the left panel.
3. **Sit Back:** The app extracts the files to a short temp path (`C:\Bedrock\Temp\...`), parses the manifests, copies the clean folders to your server's `behavior_packs` or `resource_packs` directories, and updates your world JSON files.
4. **Restart Server:** Restart your Bedrock server to apply the changes.

## 📋 Requirements

- **OS:** Windows (10/11) or Windows Server.
- **Framework:** .NET 8 Desktop Runtime.
- **Software:** An existing Minecraft Bedrock Dedicated Server installation.
