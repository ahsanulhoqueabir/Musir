# Contributing to Musir

Thanks for your interest in improving Musir! Bug reports, ideas, docs and code are all welcome.

## Ways to contribute
- **Report a bug** or **suggest a feature** using the [issue templates](https://github.com/ahsanulhoqueabir/Musir/issues/new/choose).
- Improve documentation or translations.
- Pick up an open issue (comment first so work isn't duplicated).

For anything large, please open an issue to discuss it before writing code.

## Development setup
Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.13.7`) and the Android SDK.

```bash
git clone https://github.com/ahsanulhoqueabir/Musir.git
cd Musir
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Drift code
flutter run
```

## Before you open a pull request
```bash
dart format .
flutter analyze
flutter test
```
All three should pass; CI runs them on every PR.

## Pull request workflow
1. Fork the repo and create a branch from `master` (`feat/short-name` or `fix/short-name`).
2. Keep changes focused: one topic per PR.
3. Add or update tests for behaviour changes.
4. Update the README or docs if user-facing behaviour changes.
5. Open the PR, fill in the template, and link the issue it closes.

## Commit messages
We use [Conventional Commits](https://www.conventionalcommits.org/), e.g.
`feat(player): add sleep timer`, `fix(library): skip hidden folders`, `docs: clarify install steps`.

## Code style
- Follow `analysis_options.yaml` (`flutter_lints`) and `dart format`.
- Match the existing structure and naming in `lib/`.
- Don't add network access or analytics: Musir is offline and private by design.

## Licensing
By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

Please also follow our [Code of Conduct](CODE_OF_CONDUCT.md).
