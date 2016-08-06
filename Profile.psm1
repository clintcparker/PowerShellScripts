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
    $Pathfull = Get-EnvironmentVariable -Name "PATH"
    $Path = $Pathfull.ToLower().Split(";")
    $Directory = $Directory.ToLower()

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

    $pathStr = [String]::Join(';', $Path)
    Set-EnvironmentVariable "PATH" $pathStr -Global
  }
}

function Set-EnvironmentVariable {
    param(
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='What variable would you like to add?')]
        [string]$Name,
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='What value would you like to add?')]
        [string]$Val,
        
        [Parameter(
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='Add to the global environment?')]
        [switch]$Global
    )
    [System.Environment]::SetEnvironmentVariable($Name,$Val,"Process")
    [System.Environment]::SetEnvironmentVariable($Name,$Val,"User")
    if ($Global)
    {
        [System.Environment]::SetEnvironmentVariable($Name,$Val,"Machine")
    }
}

function Get-EnvironmentVariable {
    param(
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='What variable would you like to add?')]
        [string]$Name,
        
        [Parameter(
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='Add to the global environment?')]
        [switch]$Global
    )
    $val = [System.Environment]::GetEnvironmentVariable($Name,"Process")
    if ($val -eq $null )
    {
        $val = [System.Environment]::GetEnvironmentVariable($Name,"User")
        if ($val -eq $null )
        {
            $val = [System.Environment]::GetEnvironmentVariable($Name,"Machine")
        } 
    } 
    return $val
}

function Remove-EnvironmentVariable {
    param(
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='What variable would you like to add?')]
        [string]$Name,
        [Parameter(
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='Add to the global environment?')]
        [switch]$Global
    )
    [System.Environment]::SetEnvironmentVariable($Name,$null,"Process")
    [System.Environment]::SetEnvironmentVariable($Name,$null,"User")
    if ($Global)
    {
        [System.Environment]::SetEnvironmentVariable($Name,$null,"Machine")
    }
}


function Import-ProfileModules {
    $profileModPath = "$Profile_Path\Modules"
    if (-Not(Test-Path $profileModPath)){
        mkdir $profileModPath
    }
    ls "$Profile_Path\Modules\*.psm1" -Recurse | Import-Module -Force -Global
}

function Get-Memory{
  <#
    .SYNOPSIS
      Gets memory consumption for an application
    .DESCRIPTION
      Get's total memory consumption for all processes with the supplied name.
    .EXAMPLE
      Get-Memory chrome
    .PARAMETER Name
      The name of the process.
  #>
    [CmdletBinding()]
    param(
        [Parameter(
          Mandatory=$True,
          ValueFromPipeline=$True,
          ValueFromPipelineByPropertyName=$True,
          HelpMessage='What process would you like to inspect?')]
        [string]$Name
    )


    
    $procs = $(Get-Process | ? {$_.ProcessName -eq $Name})
    if ($procs -ne $null){
        $GBMemory = $($procs | Measure-Object -Sum PM).Sum / 1gb
    }
    return "$GBMemory GB"
}


