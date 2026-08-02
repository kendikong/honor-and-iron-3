param(
	[ValidateSet("Status", "Pull", "Push")]
	[string]$Mode = "Status",
	[string]$Remote = "origin",
	[string]$Branch = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Get-CurrentBranch {
	$b = (git rev-parse --abbrev-ref HEAD).Trim()
	if (-not $b -or $b -eq "HEAD") {
		throw "Detached HEAD — checkout a branch before sync."
	}
	return $b
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
	$Branch = Get-CurrentBranch
}

Write-Output "=== Local ↔ remote sync ($Mode) ==="
Write-Output "Repo: $projectRoot"
Write-Output "Branch: $Branch  Remote: $Remote"

git fetch $Remote 2>&1 | Out-Null

$status = git status --porcelain
$aheadBehind = git rev-list --left-right --count "${Remote}/${Branch}...HEAD" 2>$null
$behind = 0
$ahead = 0
if ($aheadBehind) {
	$parts = ($aheadBehind -split "\s+") | Where-Object { $_ -ne "" }
	if ($parts.Count -ge 2) {
		$behind = [int]$parts[0]
		$ahead = [int]$parts[1]
	}
}

Write-Output "Ahead of remote: $ahead"
Write-Output "Behind remote:   $behind"
if ($status) {
	Write-Output "Working tree: DIRTY ($(($status | Measure-Object).Count) paths)"
} else {
	Write-Output "Working tree: CLEAN"
}

switch ($Mode) {
	"Status" {
		if ($status) { exit 2 }
		if ($ahead -gt 0 -or $behind -gt 0) { exit 1 }
		Write-Output "IN_SYNC: yes"
		exit 0
	}
	"Pull" {
		if ($status) {
			Write-Output "[FAIL] Dirty working tree — commit or stash before pull."
			exit 2
		}
		git pull --ff-only $Remote $Branch
		if ($LASTEXITCODE -ne 0) {
			Write-Output "[FAIL] pull --ff-only failed — resolve diverged history manually."
			exit 1
		}
		Write-Output "Pull OK — local matches ${Remote}/${Branch}"
		exit 0
	}
	"Push" {
		# Allow push with only ignored/untracked junk; refuse if tracked files are modified/uncommitted.
		$trackedDirty = git status --porcelain --untracked-files=no
		if ($trackedDirty) {
			Write-Output "[FAIL] Tracked files uncommitted — commit full backup before push (Cloud must see complete game)."
			$trackedDirty | Select-Object -First 20 | ForEach-Object { Write-Output $_ }
			exit 2
		}
		if ($behind -gt 0) {
			Write-Output "[FAIL] Local behind remote by $behind — run -Mode Pull first."
			exit 1
		}
		if ($ahead -eq 0) {
			Write-Output "Nothing to push — already up to date."
			exit 0
		}
		git push $Remote $Branch
		if ($LASTEXITCODE -ne 0) {
			Write-Output "[FAIL] git push failed — check auth / remote permissions."
			exit 1
		}
		Write-Output "Push OK — ${ahead} commit(s) on ${Remote}/${Branch}"
		exit 0
	}
}
