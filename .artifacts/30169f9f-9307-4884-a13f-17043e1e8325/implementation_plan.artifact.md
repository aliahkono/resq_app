# Fix Pubspec.yaml and Restore Project Structure

The project is currently experiencing issues because the `pubspec.yaml` file is missing a mandatory SDK constraint. Additionally, the project files (including the `lib` directory) appear to have been moved into the `.idea/` folder, which is not the standard location for a Dart/Flutter project.

## User Review Required

> [!WARNING]
> Most of the `.dart` files in your `lib` directory currently appear to be empty (0 bytes). I will move them to the correct location, but you may need to restore their content if this was accidental.

> [!IMPORTANT]
> I will be moving the `lib` folder and `pubspec.yaml` from `.idea/` to the project root (`C:/Users/acdiv/StudioProjects/ResQ/`). This is necessary for Dart and Flutter tools to function correctly.

## Proposed Changes

### [Component Name] Project Structure Restoration

#### [MODIFY] [pubspec.yaml](file:///C:/Users/acdiv/StudioProjects/ResQ/.idea/pubspec.yaml)
- Add mandatory `name`, `description`, `version`, and `environment` (SDK constraint) fields.
- Add basic `dependencies` (flutter).
- Keep the existing `dev_dependencies` and `flutter_launcher_icons` configuration.

#### [MOVE] `C:/Users/acdiv/StudioProjects/ResQ/.idea/pubspec.yaml` to `C:/Users/acdiv/StudioProjects/ResQ/pubspec.yaml`
#### [MOVE] `C:/Users/acdiv/StudioProjects/ResQ/.idea/lib/` to `C:/Users/acdiv/StudioProjects/ResQ/lib/`

## Verification Plan

### Automated Tests
- Run `dart pub get` from the project root to verify dependencies resolve correctly.

### Manual Verification
- Check the project structure in the IDE to ensure `lib` and `pubspec.yaml` are at the root.
- Verify that the SDK constraint error is resolved.
