$moduleName = "Profile"

function Add-Path {
  <#
    .SYNOPSIS
      Adds a Directory to the Current Path
    .DESCRIPTION
      Add a directory to the current path.  This is useful for 
      temporary changes to the path or, when run from your 
      profile, for adjusting the path within your powershell 
      prompt.
    .EXAMPLE
      Add-Path -Directory "C:\Program Files\Notepad++"
    .PARAMETER Directory
      The name of the directory to add to the current path.
  #>

  [CmdletBinding()]
  param (
    [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='What directory would you like to add?')]
    [Alias('dir')]
    [string[]]$Directory
  )

  PROCESS {
    $Path = $env:PATH.Split(';')

    foreach ($dir in $Directory) {
      if ($Path -contains $dir) {
        Write-Verbose "$dir is already present in PATH"
      } else {
        if (-not (Test-Path $dir)) {
          Write-Verbose "$dir does not exist in the filesystem"
        } else {
          $Path += $dir
        }
      }
    }

    
    [System.Environment]::SetEnvironmentVariable("PATH", [String]::Join(';', $Path), "Machine")
    $env:PATH = [String]::Join(';', $Path)
  }
}

function Add-Variable {
<#
    .SYNOPSIS
      Adds a Variable to the environment
    .DESCRIPTION

    .EXAMPLE
      Add-Variable -Name:"asdf" -Value:$true
  #>
[CmdletBinding()]
    param (
        [Parameter(
          Mandatory=$True,
          ValueFromPipeline=$True,
          ValueFromPipelineByPropertyName=$True,
          HelpMessage='What variable would you like to add?')]
        [string[]]$Name,
        [Parameter(
          Mandatory=$True,
          ValueFromPipeline=$True,
          ValueFromPipelineByPropertyName=$True,
          HelpMessage='What value would you like to add?')]
        [string[]]$Value,
        [Parameter(
          HelpMessage='Add this to the User environment? Default is Machine.')]
        [switch]$User
    )

    $environment = "Machine"
    if ($User){
        $environment = "User"
    }
    [System.Environment]::SetEnvironmentVariable($Name, $Value, $environment)
    
    [System.Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

