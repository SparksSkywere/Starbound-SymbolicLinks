#This PS script is for "Starbound" and symbolic linking folders for server modding
#Hide console
function Show-Console
{
    param ([Switch]$Show,[Switch]$Hide)
    if (-not ("Console.Window" -as [type])) { 

        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    if ($Show)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        $null = [Console.Window]::ShowWindow($consolePtr, 5)
    }
    if ($Hide)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        #0 hide
        $null = [Console.Window]::ShowWindow($consolePtr, 0)
    }
}
#End of powershell console hiding
#To show the console change "-hide" to "-show"
Show-Console -Show

# Enable Long Paths (requires reboot to take effect)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

#Get the UserDirectory
$userDir = "$env:UserProfile"
#Debug
Write-Host "Current user directory: $userDir"

# Define Debug function
function Debug {
    param (
        [string]$Message,
        [string]$Type = "Info"
    )
    $color = switch ($Type) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        default { "White" }
    }
    Write-Host $Message -ForegroundColor $color
}

#Check Steams install path via Regedit
$steamKey = Get-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam"
$installDir = $steamKey.GetValue("InstallPath")

#Locate "libraryfolders.vdf" file
$libraryFoldersPath = Join-Path -Path $installDir -ChildPath "steamapps\libraryfolders.vdf"
if (-not (Test-Path $libraryFoldersPath)) 
{
    #If file does not exist, Exit
    Write-Host "Could not find libraryfolders.vdf in $installDir" -ForegroundColor Red
    Exit
}

#Get the library folders from the ".vdf" file - filter only valid paths
$libraryFolders = Get-Content $libraryFoldersPath | Where-Object { $_ -match '"path"\s*"(.+?)"' } | ForEach-Object { ($_ -split '"path"\s*"')[1].Trim('"') }

#Verify each library path
$validLibraryFolders = @()
foreach ($folder in $libraryFolders) 
{
    if (Test-Path $folder) 
    {
        $validLibraryFolders += $folder
    } 
    else 
    {
        Write-Host "Invalid library path detected: $folder" -ForegroundColor Yellow
    }
}

#Check for Steam Client installation
$steamClientPaths = @()
foreach ($folder in $validLibraryFolders) 
{
    $possiblePath = Join-Path $folder "steamapps"
    if (Test-Path $possiblePath) 
    {
        $steamClientPaths += $possiblePath
    }
}

if (-not $steamClientPaths) 
{
    Write-Host "No valid Steam Client installations found." -ForegroundColor Red
} 
else 
{
    Write-Host "Found Steam Client installations in the following directories:`n$($steamClientPaths -join "`n")"
}

# Check for SteamCMD in valid library folders and fallback paths
$steamCMDPaths = @()

# Check library folders
foreach ($folder in $validLibraryFolders) 
{
    $possiblePath = Join-Path $folder "SteamCMD"
    if ((Test-Path $possiblePath) -and (Test-Path (Join-Path $possiblePath "steamcmd.exe"))) 
    {
        $steamCMDPaths += $possiblePath
    }
}

# Check fallback locations
$fallbackPaths = @("C:\SteamCMD", "D:\SteamCMD")
foreach ($path in $fallbackPaths) 
{
    if ((Test-Path $path) -and (Test-Path (Join-Path $path "steamcmd.exe"))) 
    {
        $steamCMDPaths += $path
    }
}

if (-not $steamCMDPaths) 
{
    Write-Host "No valid SteamCMD installation found." -ForegroundColor Red
} 
else 
{
    Write-Host "Found SteamCMD in the following directories:`n$($steamCMDPaths -join "`n")"
    foreach ($path in $steamCMDPaths) 
    {
        # Attach SteamCMD folder for workshops checking
        $validLibraryFolders += Join-Path -Path $path -ChildPath "steamapps"
    }
}

# Find Starbound installation
$starboundPath = $null
foreach ($steamPath in $steamClientPaths) {
    $possiblePath = Join-Path -Path $steamPath -ChildPath "common\Starbound\mods"
    Write-Host "Checking for Starbound in: $possiblePath"
    if (Test-Path -Path $possiblePath) {
        $starboundPath = $possiblePath
        Write-Host "Found Starbound mods folder at: $starboundPath"
        break
    }
}

if (-not (Test-Path -Path $starboundPath))
{
    Write-Host "Starbound\mods Folder not found in any Steam library" -ForegroundColor Red
    Write-Host "Checked paths:"
    foreach ($path in $steamClientPaths) {
        Write-Host "- $(Join-Path -Path $path -ChildPath 'common\Starbound\mods')"
    }
    Exit
}

# Check each library folder in Steam for "211820"
$starboundFolder = $null
foreach ($library in $validLibraryFolders)
{
    $folder = Join-Path $library 'workshop\content\211820'
    Write-Host "Checking workshop folder: $folder"
    if (Test-Path $folder) 
    {
        Write-Host "Starbound Workshop Found in '$folder'"
        $starboundFolder = $folder
        break
    }
}

if (-not $starboundFolder)
{
    #If 211820 is not found, Exit
    Write-Host "Could not find Starbound workshop folder in any Steam library" -ForegroundColor Red
    Exit
}

# Symbolic link each mod folder
$skippedLinks = 0
$newLinks = 0
$failedLinks = 0
$skippedMods = @()
$newLinkMods = @()
$failedLinkMods = @()
$unlinkedWorkshopNumbers = @()

3395592779

# The main chunk of this script to display all outputs
foreach ($folder in $validLibraryFolders)
{
    $modPath = Join-Path $folder 'workshop\content\211820'
    if (Test-Path $modPath) {
        # Get all workshop mod folders
        Get-ChildItem -Path $modPath -Directory | ForEach-Object {
            $modDir = $_.FullName
            $workshopNumber = (Split-Path $modDir -Leaf)
            
            # Look for .pak files in the mod directory
            Get-ChildItem -Path $modDir -Filter "*.pak" | ForEach-Object {
                $pakFile = $_
                # Use workshop number as the name but keep the .pak extension
                $targetName = $workshopNumber + [System.IO.Path]::GetExtension($pakFile.Name)
                $target = Join-Path $starboundPath $targetName
                $source = $pakFile.FullName
                
                # Escape special characters for PowerShell commands
                $escapedSourceForCommand = $source -replace '\[', '`[' -replace '\]', '`]'
                $escapedTargetForCommand = $target -replace '\[', '`[' -replace '\]', '`]'
                
                # Use the original path for checking existence
                if (-not (Test-Path -LiteralPath $source)) {
                    Debug "Source path not found: $escapedSourceForCommand" "Error"
                    $failedLinkMods += @{
                        'WorkshopNumber' = $workshopNumber
                        'Mod' = $targetName
                        'Reason' = "Source path not found"
                    }
                    $failedLinks++
                    return
                }
                # Check if the link already exists
                if (Test-Path $target) {
                    $skippedMods += @{
                        'WorkshopNumber' = $workshopNumber
                        'Mod' = $targetName
                        'Reason' = "Link already exists"
                    }
                    $skippedLinks++
                    return
                }
                # Create the symbolic link
                try {
                    New-Item -ItemType SymbolicLink -Path $escapedTargetForCommand -Target $escapedSourceForCommand -Force -ErrorAction Stop
                    $newLinkMods += @{
                        'WorkshopNumber' = $workshopNumber
                        'Mod' = $targetName
                    }
                    $newLinks++
                } catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -like "*access to the path*") {
                        Debug "Access denied when creating link for $escapedSourceForCommand to $escapedTargetForCommand. Error: $errorMessage" "Error"
                    } elseif ($errorMessage -like "*already exists*") {
                        $skippedMods += @{
                            'WorkshopNumber' = $workshopNumber
                            'Mod' = $targetName
                            'Reason' = "Link creation failed due to existing item"
                        }
                        Debug "Link creation failed due to existing item at $escapedTargetForCommand. Error: $errorMessage" "Warning"
                    } else {
                        Debug "Failed to create symbolic link for $escapedSourceForCommand to $escapedTargetForCommand. Error: $errorMessage" "Error"
                    }
                    $failedLinkMods += @{
                        'WorkshopNumber' = $workshopNumber
                        'Mod' = $targetName
                        'Reason' = $errorMessage
                    }
                    $failedLinks++
                }
            }
            
            # Check for unlinked workshop numbers (only if no .pak files were found)
            if (-not (Get-ChildItem -Path $modDir -Filter "*.pak")) {
                $unlinkedWorkshopNumbers += $workshopNumber
            }
        }
    }
}

# Output newly created links
if ($newLinkMods.Count -gt 0) {
    Write-Host "`nNew Links Created:"
    foreach ($mod in $newLinkMods) {
        Write-Host "$($mod.workshopNumber) - $($mod.Mod)"
    }
}

# Output skipped mods
if ($skippedMods.Count -gt 0) {
    Write-Host "`nSkipped Mods:"
    foreach ($mod in $skippedMods) {
        Write-Host "$($mod.workshopNumber) - $($mod.Mod): $($mod.Reason)"
    }
}

# Output failed links
if ($failedLinkMods.Count -gt 0) {
    Write-Host "`nFailed Links:"
    foreach ($mod in $failedLinkMods) {
        Write-Host "$($mod.workshopNumber) - $($mod.Mod): $($mod.Reason)"
    }
}

# Output unlinked workshop numbers
if ($unlinkedWorkshopNumbers.Count -gt 0) {
    Write-Host "`nUnlinked Workshop Numbers:"
    foreach ($number in $unlinkedWorkshopNumbers) {
        Write-Host "$number"
    }
}

Write-Host "Symbolic Link Creation Summary:"
Write-Host " - New Links Created: $newLinks"
Write-Host " - Skipped Existing Links: $skippedLinks"
Write-Host " - Failed Links: $failedLinks"
Write-Host " - Unlinked Workshop Numbers: $($unlinkedWorkshopNumbers.Count)"
Pause
#Made by Chris Masters