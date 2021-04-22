# Github folder items: https://api.github.com/repos/damesene/git-hooks/git/trees/master

# {
#   "sha": "0286b148095dc14cef7663042ce0618490c6fc81",
#   "url": "https://api.github.com/repos/damesene/git-hooks/git/trees/0286b148095dc14cef7663042ce0618490c6fc81",
#   "tree": [
#     {
#       "path": "commit-msg",
#       "mode": "100644",
#       "type": "blob",
#       "sha": "82f652f74ebcf01d8ccc1e186984cc8fd6630fd8",
#       "size": 199,
#       "url": "https://api.github.com/repos/damesene/git-hooks/git/blobs/82f652f74ebcf01d8ccc1e186984cc8fd6630fd8"
#     }
#   ],
#   "truncated": false
# }

# VARIABLES
$gitRepository = '/damesene/git-hooks'
$gitRepositoryHooksDirectory = '/client-hooks'
$gitRepositoryHooksDirectorySha = '0286b148095dc14cef7663042ce0618490c6fc81'

# CONSTANTS
# https://raw.githubusercontent.com/damesene/git-hooks/main/client-hooks/commit-msg
$gitReadRawFilesUrl = 'https://raw.githubusercontent.com'

$gitReposApiUrl = 'https://api.github.com/repos';
$gitGetFolderMetadataUrl = "$gitReposApiUrl$gitRepository/git/trees/$gitRepositoryHooksDirectorySha"

$gitDirectory = '.git'
$gitHooksDirectory = "$gitDirectory/hooks/"
$depthFolderSearch = 3
##################

# HELPERS
function GetGitHookUrl() {
    param ($hookName)
    return "$gitReadRawFilesUrl$gitRepository/main$gitRepositoryHooksDirectory/$hookName"
}

function PrintSearchDirectories() {
    Write-Output "Recursive search [Directory: $gitDirectory] [Search depth: $depthFolderSearch] [Root: $PSScriptRoot]"
}

function GetGitDirectories() {
    . {
        $gitDirectories = Get-ChildItem -Path $PSScriptRoot -Filter $gitDirectory -Recurse -Directory -Hidden -Depth $depthFolderSearch
        if ($gitDirectories.Count -eq 0) {
            return
        }

        $targetFullDirectories = $gitDirectories | ForEach-Object { $_.Fullname -replace "\\", "/" }
    } | Out-Null

    return $targetFullDirectories
}

function GetFilesFromDirectories() {
    param ($paths, $exclude)

    [System.Collections.ArrayList]$files = @()
    . {
        foreach ( $path in $paths )
        {
            if(!(test-path $path)) {
                continue
            }
            
            $directory = (Get-ChildItem -Path $path -Exclude $exclude -File -Force -Depth 0);
            switch ($directory.count)
            {
                0 { continue }
                1 { $files.Add($directory.FullName) }
                default { $files.AddRange($directory.FullName) }
            }
        }
    } | Out-Null

    return $files;
}

function ConfirmApplyToAllDirectories() {
    param ($items, $confirMessage, $prefix)

    if ($items.count -eq 0) {
        Write-Output $prefix"No items found. Exit without action"
        HoldExit
        Exit
    }

    Write-Output $prefix"Found items ($($items.count)):"
    Write-Output $items | ForEach-Object { "$prefix * $($_)" };
    Write-Output " "
    $continue = Read-Host $confirMessage

    if ($continue -ne 'y') {
        Write-Output "Exit without action"
        Exit
    }
}

function HoldExit() {
    Read-Host 'Press enter to exit'
}
##################


Write-Output "=============================="
Write-Output "======= Copy git hooks ======="
Write-Output "------------------------------"
Write-Output "Select action:"
Write-Output " * [A]pply git hooks"
Write-Output " * [R]emove all git hooks"
Write-Output " * [C]ancel"
$action = Read-Host '[a/r/C]'

switch($action) {
    'r' {
        Write-Output "------------------------------"
        Write-Output "Removing git hooks"
        Write-Output "------------------------------"
        PrintSearchDirectories

        $gitDirectories = GetGitDirectories
        $hookDirectories = $gitDirectories | ForEach-Object { $_  -replace "$gitDirectory$", $gitHooksDirectory }

        $hookFiles = GetFilesFromDirectories $hookDirectories "*.sample"
        
        ConfirmApplyToAllDirectories $hookFiles "All files above will permamently deleted.`nDo you want to continue? [y/N]"
        $hookFiles | ForEach-Object { Remove-Item $_ }
        Write-Output "All files deleted"
    }
    'a' {
        Write-Output "------------------------------"
        Write-Output "Applying git hooks"
        Write-Output "------------------------------"

        PrintSearchDirectories
        $gitDirectories = GetGitDirectories
        ConfirmApplyToAllDirectories $gitDirectories "Apply all Git hooks to all projects? [y/N]" " "

        Write-Output " "
        Write-Output "Getting hooks metadata"

        $gitFolderItemsResponse = Invoke-WebRequest $gitGetFolderMetadataUrl | ConvertFrom-Json
        $gitHooksMetadata = $gitFolderItemsResponse.tree

        if ($gitHooksMetadata.Count -eq 0) {
            Write-Output "No git hook found from address $gitGetFolderMetadataUrl"
            return
        }

        $gitHookNames = $gitHooksMetadata | ForEach-Object { $_.path }

        Write-Output " Found $($gitHookNames.count) git hooks:"
        Write-Output $gitHookNames | ForEach-Object { "  * $($_)" }
        Write-Output " "
        Write-Output "Reading hooks data"
        [System.Collections.ArrayList]$gitHooks = @()
        foreach ( $hookName in $gitHookNames ) {
            $url = GetGitHookUrl $hookName;
            Write-Output " * $url";
            $data = Invoke-WebRequest $url;

            . {
                $gitHooks.Add(@{
                    name = $hookName
                    data = $data
                })
            } | Out-Null
        }
        Write-Output " "

        Write-Output "Applying hooks:"
        foreach ( $path in $gitDirectories )
        {
            Write-Output " * $path"
            $gitHooksPath = $path -replace "$gitDirectory$", $gitHooksDirectory

            if(!(test-path $gitHooksPath)) {
                . {
                    New-Item -ItemType "directory" -Path $gitHooksPath
                } | Out-Null
            }

            foreach ( $hook in $gitHooks) {
                $targetFilePath = "$gitHooksPath$($hook.name)"
                Write-Output "  * Writting: $targetFilePath"
                Set-Content -Path $targetFilePath -Value $hook.data
            }
        }
    }
    default { Exit }
}

HoldExit