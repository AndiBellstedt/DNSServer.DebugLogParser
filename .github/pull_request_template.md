## Description
<!-- Briefly describe what this PR changes and why -->


## Type of Change

- [ ] New PowerShell function or cmdlet
- [ ] Function or cmdlet update
- [ ] Module packaging or manifest change
- [ ] Test addition or fix
- [ ] Documentation update
- [ ] CI/CD workflow addition or update
- [ ] Bug fix
- [ ] Breaking change
- [ ] Other (please describe):

## Scope

- [ ] `DNSServer.DebugLogParser/functions/`
- [ ] `DNSServer.DebugLogParser/internal/functions/`
- [ ] `DNSServer.DebugLogParser/internal/scripts/`
- [ ] `tests/functions/`
- [ ] `tests/general/`
- [ ] `DNSServer.DebugLogParser/DNSServer.DebugLogParser.psd1`
- [ ] `DNSServer.DebugLogParser/DNSServer.DebugLogParser.psm1`
- [ ] `build/`
- [ ] `.github/workflows/`
- [ ] `README.md` or `docs/`
- [ ] `DNSServer.DebugLogParser/changelog.md`

## Verification

- [ ] All public functions are listed in `FunctionsToExport` in the module manifest
- [ ] `AliasesToExport` remains accurate when aliases are added or changed
- [ ] Tests were added or updated for changed behavior
- [ ] `.\tests\pester.ps1` was run and passed locally
- [ ] `.\build\validate.ps1` was run in each supported PowerShell edition where available
- [ ] User-facing behavior changes are documented in `DNSServer.DebugLogParser/changelog.md` and relevant documentation
- [ ] No new generated or build artifacts (for example `TestResults/` or `publish/`) were committed

## Notes for Reviewers
<!-- Include any special notes, design decisions, or areas requiring attention -->


## Pre-Merge Checklist

- [ ] Changes are limited to the intended module or documentation area
- [ ] No sensitive information or secrets committed
- [ ] Commit message is clear and descriptive
- [ ] If this PR changes published behavior, user-facing documentation was updated accordingly
