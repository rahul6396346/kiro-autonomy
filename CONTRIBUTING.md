# Contributing

Thanks for considering a contribution. This project stays useful only because the community keeps it accurate as Kiro evolves.

## How to help

### 🐛 Bug reports
Open an [issue](https://github.com/rahul6396346/kiro-autonomy/issues/new?template=bug_report.md). Include:
- Your OS and Kiro version (`Help → About`)
- The `kiro.kiro-agent` extension version (visible in the Extensions view)
- The exact contents of your `settings.json` (with secrets redacted)
- What you expected vs. what happened
- Output from `Output` panel → `Kiro Agent` if relevant

### 💡 Feature ideas / new recipes
Open an [issue](https://github.com/rahul6396346/kiro-autonomy/issues/new?template=feature_request.md) describing the workflow and what you'd want trusted.

### 📝 Documentation fixes
PRs welcome for typos, clarifications, screenshots, translations.

### 🧪 New Kiro version verification
When a new Kiro version ships, the matcher logic might change. To verify:

1. Run the commands in [docs/VERIFICATION.md](docs/VERIFICATION.md)
2. If the logic still matches what the guide describes, open a PR updating the version number in `docs/GUIDE.md`
3. If it changed, open an issue with the new code excerpt and we'll update the guide together

## Development setup

This is a documentation + scripts repo. There's no compile step.

```bash
git clone https://github.com/rahul6396346/kiro-autonomy.git
cd kiro-autonomy
```

### Running the tests

```powershell
# Windows / cross-platform via PowerShell 7
pwsh -File tests/Test-Script.ps1
```

The tests run the installer against a temp `settings.json`, verify the output, and clean up.

### Linting

Markdown:
```bash
npx markdownlint-cli '**/*.md' --ignore node_modules
```

PowerShell:
```powershell
Invoke-ScriptAnalyzer -Path scripts/ -Recurse
```

CI runs both on every PR.

## Pull request guidelines

- Keep PRs focused. One concern per PR.
- Update `CHANGELOG.md` under `[Unreleased]`.
- Match existing style. Markdown headers are `##` for major sections, `###` for subsections.
- For script changes: run `tests/Test-Script.ps1` locally and make sure it passes.
- For new recipes: add the JSON to `examples/`, add a section to `docs/RECIPES.md`, and link it from the README.

## Code of conduct

Be civil. The maintainers reserve the right to lock or remove disrespectful threads.

## License

By contributing you agree your changes are licensed under the [MIT License](LICENSE).
