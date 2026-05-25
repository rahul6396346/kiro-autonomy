# Kiro Autonomy Recipes

Pick the level that fits how you work. Each recipe is a complete, paste-ready `settings.json` you can adapt. Or use the installer to apply them: `Enable-KiroFullAutonomy.ps1 -Recipe <name>`.

## Decision tree

```
Are you the only one running this code on this machine?
├── No  → Recipe D (workspace override) for sensitive projects
└── Yes
    ├── Do you commit often (or work in containers/VMs)?
    │   ├── Yes → Recipe A (Maximum)
    │   └── No  → Recipe B (Aggressive bounded)
    └── Are you new to Kiro and want safety while learning?
        └── Recipe C (Conservative)
```

## Recipe A — Maximum

**Use when:** You commit before letting the agent run, or you work in a container/VM/throwaway environment. This is what most people who ask "how do I make Kiro fully autonomous" actually want.

```json
{
    "kiroAgent.agentAutonomy": "Autopilot",
    "kiroAgent.trustedTools": ["*"],
    "kiroAgent.trustedCommands": ["*"]
}
```

Pros: zero prompts, ever.
Cons: destructive commands run instantly. No undo for `rm -rf` or `DROP TABLE`.

Apply:
```powershell
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe maximum
```

## Recipe B — Aggressive (bounded)

**Use when:** You want the agent to handle 95% of dev work without prompts, but stop on unusual or destructive commands.

```json
{
    "kiroAgent.agentAutonomy": "Autopilot",
    "kiroAgent.trustedTools": ["*"],
    "kiroAgent.trustedCommands": [
        "node *", "npm *", "npx *", "pnpm *", "yarn *", "bun *",
        "python *", "py *", "pip *", "uv *", "uvx *", "poetry *",
        "go *", "cargo *", "rustc *",
        "java *", "javac *", "mvn *", "gradle *",
        "dotnet *", "make *", "cmake *",
        "git status", "git status -s", "git diff", "git diff --cached",
        "git log", "git log --oneline -20", "git show", "git branch",
        "git add *", "git commit *", "git pull", "git fetch",
        "git checkout *", "git switch *", "git stash", "git stash *",
        "dir", "dir *", "type *", "where *", "echo *", "cls",
        "Get-ChildItem *", "Get-Content *", "Select-String *",
        "ls *", "cat *", "grep *", "find *", "head *", "tail *",
        "docker *", "kubectl *", "terraform *",
        "curl *", "wget *", "ping *", "nslookup *",
        "tsc *", "eslint *", "prettier *", "vitest *", "jest *", "pytest *"
    ]
}
```

Notice what's excluded: `git push --force`, `git reset --hard`, `rm`, `del`, `Remove-Item`, `format`. The agent has to ask for those.

Apply:
```powershell
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe aggressive
```

## Recipe C — Conservative

**Use when:** You're learning Kiro, working on sensitive code, or just want maximum visibility into what the agent is doing.

```json
{
    "kiroAgent.agentAutonomy": "Supervised",
    "kiroAgent.trustedTools": [
        "read_file", "read_files", "list_directory",
        "grep_search", "file_search",
        "remote_web_search", "web_fetch"
    ],
    "kiroAgent.trustedCommands": [
        "node --version", "npm --version", "git status",
        "git diff", "dir", "type *", "Get-ChildItem"
    ]
}
```

The agent reads and explores without prompting; every write or shell op is reviewed.

Apply:
```powershell
pwsh -File scripts/Enable-KiroFullAutonomy.ps1 -Recipe conservative
```

## Recipe D — Per-workspace override

**Use when:** Your global settings trust everything, but a specific project shouldn't.

Drop into `<project>/.vscode/settings.json`:

```json
{
    "kiroAgent.agentAutonomy": "Supervised",
    "kiroAgent.trustedCommands": [],
    "kiroAgent.trustedTools": []
}
```

Workspace settings beat user settings, so this disables full-trust just for that project. See [examples/settings.workspace-override.json](../examples/settings.workspace-override.json).

## Recipe E — Stack-specific add-ons

If you only work in one stack, you can shrink Recipe B further. Pick your stack and merge with Recipe A's autonomy/tools:

### JavaScript/TypeScript
```json
"kiroAgent.trustedCommands": [
    "node *", "npm *", "npx *", "pnpm *", "yarn *", "bun *",
    "tsc *", "eslint *", "prettier *", "vitest *", "jest *",
    "git status", "git diff", "git add *", "git commit *",
    "ls *", "cat *", "dir", "type *"
]
```

### Python
```json
"kiroAgent.trustedCommands": [
    "python *", "py *", "pip *", "uv *", "uvx *", "poetry *",
    "pytest *", "ruff *", "mypy *", "black *",
    "git status", "git diff", "git add *", "git commit *",
    "ls *", "cat *", "dir", "type *"
]
```

### Rust
```json
"kiroAgent.trustedCommands": [
    "cargo *", "rustc *", "rustup *", "rustfmt *", "clippy-driver *",
    "git status", "git diff", "git add *", "git commit *",
    "ls *", "cat *", "dir", "type *"
]
```

### Go
```json
"kiroAgent.trustedCommands": [
    "go *", "gofmt *", "golangci-lint *",
    "git status", "git diff", "git add *", "git commit *",
    "ls *", "cat *", "dir", "type *"
]
```

### .NET
```json
"kiroAgent.trustedCommands": [
    "dotnet *", "msbuild *",
    "git status", "git diff", "git add *", "git commit *",
    "dir", "type *", "Get-ChildItem *"
]
```

### Java
```json
"kiroAgent.trustedCommands": [
    "java *", "javac *", "mvn *", "gradle *", "gradlew *",
    "git status", "git diff", "git add *", "git commit *",
    "ls *", "cat *", "dir", "type *"
]
```

### DevOps
```json
"kiroAgent.trustedCommands": [
    "docker *", "docker-compose *",
    "kubectl *", "helm *",
    "terraform *", "ansible *",
    "aws *", "gcloud *", "az *",
    "git status", "git diff", "git add *", "git commit *"
]
```

## Combining recipes

You can mix any stack add-on with Recipe B's git/file/shell baseline. The script appends to your existing trust list, so applying multiple recipes additively works — though for clarity prefer constructing one explicit list.
