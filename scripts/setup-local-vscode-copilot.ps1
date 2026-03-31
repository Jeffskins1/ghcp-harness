[CmdletBinding()]
param(
    [string]$ProjectName = "task-ops-api",
    [string]$OutputRoot,
    [switch]$Force,
    [switch]$SkipDependencyInstall,
    [switch]$SkipGitHooksInstall,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-DirectoryIfMissing {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Path $Path
    }
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-DirectoryIfMissing -Path $parent
    }

    [System.IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n").Replace("`n", [Environment]::NewLine))
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source path not found: $Source"
    }

    New-DirectoryIfMissing -Path $Destination
    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Remove-TransientArtifacts {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return
    }

    $transientDirs = Get-ChildItem -Path (Join-Path $Root "*") -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "__pycache__" }

    foreach ($dir in $transientDirs) {
        Remove-Item -LiteralPath $dir.FullName -Recurse -Force
    }
}

function Test-CommandExists {
    param([string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

$HarnessRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $OutputRoot) {
    $OutputRoot = Split-Path -Parent $HarnessRoot
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $OutputRoot $ProjectName))

Write-Step "Preparing project path"
Write-Host "Harness root: $HarnessRoot"
Write-Host "Project root: $ProjectRoot"

if (Test-Path -LiteralPath $ProjectRoot) {
    $existingEntries = Get-ChildItem -LiteralPath $ProjectRoot -Force
    if ($existingEntries.Count -gt 0 -and -not $Force) {
        throw "Project directory already exists and is not empty: $ProjectRoot`nRe-run with -Force to continue."
    }
} else {
    $null = New-Item -ItemType Directory -Path $ProjectRoot
}

Write-Step "Checking Python version"
$pythonCmd = $null
foreach ($cmd in @("python", "python3")) {
    if (Test-CommandExists -Name $cmd) {
        $pythonCmd = $cmd
        break
    }
}

if ($null -eq $pythonCmd) {
    Write-Warning "Python was not found in PATH. Workflow scripts require Python 3.10+. Install from python.org before running workflow commands."
} else {
    $pythonVersion = & $pythonCmd --version 2>&1
    if ($pythonVersion -match "Python (\d+)\.(\d+)") {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 10)) {
            Write-Warning "Python $major.$minor found, but workflow scripts require Python 3.10+. Upgrade from python.org before running workflow commands."
        } else {
            Write-Host "Python $major.$minor OK." -ForegroundColor Green
        }
    }
}

Write-Step "Creating baseline folders"
$folders = @(
    ".github",
    ".github/hooks",
    ".github/prompts",
    ".github/skills",
    ".vscode",
    "scripts",
    "scripts/hooks",
    "scripts/hooks/git",
    "scripts/sync",
    "scripts/workflow",
    "resources",
    "resources/spec",
    "resources/templates",
    "specs",
    "specs/features",
    "src",
    "src/routes",
    "src/services",
    "src/models",
    "tests",
    "tests/integration",
    "tests/unit"
)

foreach ($folder in $folders) {
    New-DirectoryIfMissing -Path (Join-Path $ProjectRoot $folder)
}

Write-Step "Initializing git repository"
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    & git init $ProjectRoot | Out-Host
}

Write-Step "Copying harness assets"
Copy-DirectoryContents -Source (Join-Path $HarnessRoot "scripts/hooks") -Destination (Join-Path $ProjectRoot "scripts/hooks")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot "scripts/workflow") -Destination (Join-Path $ProjectRoot "scripts/workflow")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot "resources/spec") -Destination (Join-Path $ProjectRoot "resources/spec")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot "resources/templates") -Destination (Join-Path $ProjectRoot "resources/templates")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot "scripts/sync") -Destination (Join-Path $ProjectRoot "scripts/sync")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot ".github/hooks") -Destination (Join-Path $ProjectRoot ".github/hooks")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot ".github/prompts") -Destination (Join-Path $ProjectRoot ".github/prompts")
Copy-DirectoryContents -Source (Join-Path $HarnessRoot ".github/skills") -Destination (Join-Path $ProjectRoot ".github/skills")
Remove-TransientArtifacts -Root $ProjectRoot

$packageJson = @"
{
  "name": "$ProjectName",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "tsx src/server.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "build": "tsc --noEmit"
  }
}
"@

$tsconfigJson = @"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "Node",
    "rootDir": ".",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src", "tests"]
}
"@

$vitestConfig = @'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"]
  }
});
'@

$appTs = @'
import express from "express";

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  return app;
}
'@

$serverTs = @'
import { createApp } from "./app";

const app = createApp();
const port = 3000;

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
'@

$healthTest = @'
import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../../src/app";

describe("GET /health", () => {
  it("returns ok", async () => {
    const response = await request(createApp()).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ ok: true });
  });
});
'@

$vscodeSettings = @"
{
  "github.copilot.chat.agent.enabled": true,
  "github.copilot.chat.agent.runTasks": true
}
"@

$vscodeExtensions = @"
{
  "recommendations": [
    "GitHub.copilot",
    "GitHub.copilot-chat",
    "eamodio.gitlens"
  ]
}
"@

$copilotInstructions = @'
# Project: task-ops-api

## Tech Stack
- Language: TypeScript 5.x
- Framework: Express 4/5 style HTTP API
- Database: In-memory only for local harness testing
- Test framework: Vitest + Supertest
- Build tool: npm
- CI/CD: local only for now

## Architecture
- src/routes -> route handlers
- src/services -> business logic
- src/models -> request/response and domain shapes
- tests/integration -> request/response tests
- tests/unit -> service tests
- specs/ -> feature specs and architecture notes

## Conventions
- Write tests before implementation
- Use conventional commits
- Never edit hook files unless intentionally testing the harness
- Keep route handlers thin
- Put business rules in services

## Exact Test Commands
- Full suite: `npm test`
- Unit: `npm test`

## Agent Constraints
### Rules
- Always read the active spec before implementation
- Do not change package.json dependencies without asking first
- Do not modify .github/hooks/ or scripts/hooks/ unless the task is harness-related
- The harness enforces task-level TDD: write the failing test first, let the failing test run record Red, then implement until a passing test run records Green
- Implementation-file edits before Red may be intercepted
- Tests must pass before a task is considered done
- Tasks marked `Evaluator review: YES` also require a recorded evaluator result with verdict `pass` or `pass_with_risks`

### Persistent Lessons
# Append lessons here over time
'@

$archMd = @'
# Architecture

## System Overview
This repo is a small Express API used to test a spec-driven agentic harness locally in VS Code.

## Layer Map
- Routes: HTTP request/response handling
- Services: task business rules
- Models: task shapes and validation contracts
- Tests: unit and integration coverage

## Key Boundaries
- Routes should not hold business logic
- Services should be testable without HTTP
- Tests should map to spec scenarios

## Technology Decisions
- TypeScript
- Express
- Vitest
- Supertest
- In-memory storage only for initial harness testing
'@

$featureSpec = @'
# Feature: Task creation and completion

## Intent
Allow a user to create tasks and mark them complete so the harness can be exercised across happy path, validation, and state-transition behavior.

## Acceptance Criteria
- User can create a task with a title
- Created task appears in task listing
- User can mark an existing task complete
- Creating a task without a title returns a validation error
- Marking a missing task complete returns 404

## Test Scenarios
- Happy path: create task successfully
- Happy path: list includes created task
- Happy path: mark task complete
- Validation failure: missing title rejected
- Failure path: complete unknown task returns 404

## Out Of Scope
- Database persistence
- Authentication
- Task deletion
- Task editing

## Implementation Plan

### Task 1 - Model/Service: add in-memory task service
Files: src/services/task-service.ts, tests/unit/task-service.test.ts
Done when: unit tests pass for create, list, complete, and missing-task failure
Depends on: none
Evaluator review: NO

### Task 2 - API: add task routes
Files: src/routes/tasks.ts, src/app.ts, tests/integration/tasks.test.ts
Done when: integration tests pass for create/list/complete and validation failures
Depends on: Task 1
Evaluator review: YES
'@

Write-Step "Writing scaffold files"
Write-TextFile -Path (Join-Path $ProjectRoot "package.json") -Content $packageJson
Write-TextFile -Path (Join-Path $ProjectRoot "tsconfig.json") -Content $tsconfigJson
Write-TextFile -Path (Join-Path $ProjectRoot "vitest.config.ts") -Content $vitestConfig
Write-TextFile -Path (Join-Path $ProjectRoot "src/app.ts") -Content $appTs
Write-TextFile -Path (Join-Path $ProjectRoot "src/server.ts") -Content $serverTs
Write-TextFile -Path (Join-Path $ProjectRoot "tests/integration/health.test.ts") -Content $healthTest
Write-TextFile -Path (Join-Path $ProjectRoot ".vscode/settings.json") -Content $vscodeSettings
Write-TextFile -Path (Join-Path $ProjectRoot ".vscode/extensions.json") -Content $vscodeExtensions
Write-TextFile -Path (Join-Path $ProjectRoot ".github/copilot-instructions.md") -Content ($copilotInstructions -replace "task-ops-api", $ProjectName)
Write-TextFile -Path (Join-Path $ProjectRoot "specs/arch.md") -Content $archMd
Write-TextFile -Path (Join-Path $ProjectRoot "specs/features/task-creation-and-completion.spec.md") -Content $featureSpec

if (-not $SkipDependencyInstall) {
    if (-not (Test-CommandExists -Name "npm")) {
        throw "npm was not found in PATH. Re-run with -SkipDependencyInstall or install Node.js/npm first."
    }

    Write-Step "Installing npm dependencies"
    Push-Location $ProjectRoot
    try {
        & npm install express | Out-Host
        & npm install -D typescript tsx vitest supertest @types/express @types/node @types/supertest | Out-Host
    }
    finally {
        Pop-Location
    }
} else {
    Write-Step "Skipping npm dependency installation"
}

if (-not $SkipGitHooksInstall) {
    if (Test-CommandExists -Name "bash") {
        Write-Step "Installing local git hooks"
        Push-Location $ProjectRoot
        try {
            & bash "scripts/hooks/git/install.sh" | Out-Host
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Warning "bash was not found in PATH. Skipping git hook installation."
    }
} else {
    Write-Step "Skipping git hook installation"
}

if (-not $SkipValidation) {
    if ($SkipDependencyInstall) {
        Write-Warning "Validation skipped because dependencies were not installed."
    } elseif (Test-CommandExists -Name "npm") {
        Write-Step "Running npm test"
        Push-Location $ProjectRoot
        try {
            & npm test | Out-Host
        }
        finally {
            Pop-Location
        }
    }
} else {
    Write-Step "Skipping validation"
}

Write-Step "Setup complete"
Write-Host "Project ready at: $ProjectRoot" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. code $ProjectRoot"
Write-Host "  2. In VS Code, open Copilot Chat and switch to Agent Mode."
Write-Host "  3. In Copilot Chat, use a skill prompt from .github/prompts/ to start your first feature."
