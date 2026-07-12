# [Hedon Haven (project website)](https://hedon-haven.top/)

An adult content aggregator app.

## Features:

* **Supports many providers:** Pornhub, xHamster and more (coming soon).
* **Completely free:** Full access to all features with no hidden fees or subscriptions.
* **Open Source:** Complete transparency and security with the entire application source code
  publicly available.
* **Offline viewing:** Download content for offline viewing from any provider (coming soon).
* **Easy management:** Favorites, subscriptions (coming soon) and watch history all in one place.
* **Privacy-focused:** Designed with privacy-first principles (coming soon).
* **Modern design:** A sleek and intuitive interface built with Flutter.
* **Cross-platform:** Android, iOS (coming soon), Windows, macOS and Linux.

## **[1.0 release roadmap](https://github.com/orgs/Hedon-Haven/projects/1)**

## Building

1. Download and install the [flutter sdk](https://docs.flutter.dev/get-started/install)
2. Clone the repository: `git clone --depth=1 https://github.com/Hedon-Haven/Hedon-Haven`
3. Change directory: `cd Hedon-Haven`
4. Get the dependencies: `flutter pub get`
5. Depending on your platform run:
    * Android:
        * `flutter build apk --debug` or `flutter build apk --release`
        * To build arch-specific: `flutter build apk --release --split-per-abi`
    * iOS: Not yet supported
    * Linux:
        * `flutter build linux --debug` or `flutter build linux --release`
    * Windows: Not yet supported
    * macOS: Not yet supported

## Run tests

1. Download and install the [flutter sdk](https://docs.flutter.dev/get-started/install)
2. Clone the repository: `git clone --depth=1 https://github.com/Hedon-Haven/Hedon-Haven`
3. Change directory: `cd Hedon-Haven`
4. Get the dependencies: `flutter pub get`
5. Generate mocks: `flutter pub run build_runner build`
6. Run the tests: `flutter test`
    - To test just one plugin, set the `PLUGIN` environment variable:
      `PLUGIN=com.hedon_haven.tester_internal flutter test`

## Generate icons

1. Edit `flutter_launcher_icons.yaml` and uncomment the section you want to generate icons for
2. Generate icons: `flutter pub run flutter_launcher_icons`
3. Fix file names: `./assets/launcher-icon/rename-generated-icons.sh stock` (or `fake_settings` or
   `reminders`)

## Credit

* Search bar design inspired by [InnerTune](https://github.com/z-huang/InnerTune)
* Some widget code was adapted from [Revanced Manager](https://github.com/ReVanced/revanced-manager)
* Comments section & video gridview inspired by [LibreTube](https://libretube.dev/)
