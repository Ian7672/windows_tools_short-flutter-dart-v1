# Windows Toolkit

Desktop utility (Flutter + Fluent UI) that wraps a curated set of Windows
maintenance scripts so you can manage Xbox Gaming Services, Windows Update and
cleanup chores from a single dashboard.

> 🏆 Credits  
> - **@Ian7672** – original Gaming Services/Windows Update firewall & service scripts  
> - **@Ian7672** – Flutter desktop integration, tooling UX, localization work

## Feature Highlights

- **Updater controls** – disable Windows Update, Google Updater, Xbox Gaming Services
  or create your own firewall/service policies straight from the UI.
- **Cleaner suite** – Startup Manager, junk/cache cleanup, WinSxS component cleanup,
  Windows Update leftovers, temporary install folders and more.
- **Other & future tools** – dashboard card reserved for experiments sourced from
  `assets/tools_manifest.json`.
- **Logs & backups** – every run/restore is logged with backup paths so you can
  track what changed.
- **Settings** – multi-language support, dark/light themes, confirmation toggles,
  quick links to tools/backups/log folders.

## Screenshot
<p align="center"> <img src="https://github.com/user-attachments/assets/76bc7233-0ff3-43ed-8363-a92fc76c46e3" alt="Windows Toolkit — Screenshot 136" width="49%" /> <img src="https://github.com/user-attachments/assets/1fbb517b-4eb1-4956-9ec6-4b9591421673" alt="Windows Toolkit — Screenshot 137" width="49%" /> </p> <p align="center"> <img src="https://github.com/user-attachments/assets/850c74b8-3082-4e79-a679-c42947cb6734" alt="Windows Toolkit — Screenshot 138" width="49%" /> <img src="https://github.com/user-attachments/assets/0bc117af-b100-46fb-88d0-b5a1d730b6e5" alt="Windows Toolkit — Screenshot 139" width="49%" /> </p> <p align="center"> <img src="https://github.com/user-attachments/assets/35ad8222-d5f9-4386-9afa-f11d52ba9aee" alt="Windows Toolkit — Screenshot 135" width="75%" /> </p>


## Project Structure

- `assets/tools_manifest.json` – declarative manifest that defines categories,
  built-in tools and their service/registry/firewall actions plus localized
  titles/descriptions.
- `lib/core` – localization, models, services (firewall resolver, junk cleaner,
  manifest repository, etc.).
- `lib/features` – page-level widgets (dashboard, updater, cleaner, logs, settings,
  about).
- `windows/` – Windows runner scaffold produced by `flutter create`.

## Getting Started

1. [Install Flutter](https://docs.flutter.dev/get-started/install) with the
   Windows desktop toolchain (Visual Studio w/ Desktop dev workload).
2. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
3. Run the desktop app in debug:
   ```powershell
   flutter run -d windows
   ```
4. Build a distributable:
   ```powershell
   flutter build windows
   ```

## Customising Tools

1. Edit `assets/tools_manifest.json`.
2. Add/update a `tool` entry (`serviceActions`, `registryActions`,
   `firewallActions`, `localizedTitles`, `localizedDescriptions`, …).
3. Hot-reload/`flutter pub run build_runner` as needed, then choose **Reload
   manifest** in the Updater page to pick up the new configuration.

## Localization

Strings live in `lib/core/localization/app_localizations.dart`. Add entries
under the relevant language map (`en`, `id`, `zh`, etc.) and expose strongly
typed getters when needed. The dashboard, Updater panel and cleaner suite are
already wired to read per-language metadata from the manifest.

## License / Attribution

Please retain credit to **@Ian7672** when redistributing the scripts or compiled
tooling. Respect the original intent: keeping Gaming Services and Windows Update
under user control. The Flutter wrapper (this repository) follows the same
spirit—feel free to fork, but keep attribution intact.
