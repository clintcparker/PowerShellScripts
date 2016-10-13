$moduleName = "TF-Extensions"


$tfsUrlString = "TFS_URL"

function Initialize-Workspace {
    [CmdletBinding()]
  param (
        [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='What tfs directory would you like to add?')]
      [Alias('TFS Directory')]
    [string]$TFS_Directory,
        [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='Where will it be mapped to?')]
    [string]$Local_Directory,
        [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='Workspace Name')]
    [string]$Workspace_Name
    )
        $newWS = New-Workspace -newWorkspaceName:$Workspace_Name
        tf workfold /map $TFS_Directory $Local_Directory /workspace:$newWS
        tf get $Local_Directory /remap /recursive
}


function Get-LocalCopy {
    [CmdletBinding()]
    param(
                 [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='What tfs item(s) would you like to copy?')]
    [string]$itemspec,
        [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='Where will it be mapped to?')]
    [string]$output,
        [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='What is the tfs collection URL?')]
    [string]$collection,
        [Parameter(
      Mandatory=$False,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='What version to get?')]
    [string]$version,
    [switch]$noMessage
    )
    
    if (!$noMessage)
    {
        echo "Copying $itemspec to $output..."
    }

    $tfDirArgs = $itemspec  + " /collection:$collection "
    if ($version -ne "")
    {
        $tfDirArgs =  $tfDirArgs + " /version:$version "
    }
    $items = Invoke-Expression  $("tf dir $tfDirArgs")
    foreach($item in $items)
    {
        if ($item -inotmatch "[:\(]"  -and $item -ne "")
        {
            #echo $item
            if ($item -match "\$") #directory
            {
                $directoryName = $item.Replace("$","");
                Get-LocalCopy -itemspec $($itemspec + "/" + $directoryName) -output $($output + "/" + $directoryName) -collection $collection  -version:$version  -noMessage;
            }
            else #file
            {
                $tfViewArgs = $($itemspec + "/" + $item)  + " /collection:$collection " + " /output:$($output + "/" + $item) "
                if ($version -ne "")
                {
                    $tfViewArgs =  $tfViewArgs + " /version:$version "
                }
                $tfViewCommand = $("tf view $tfViewArgs")
                $outVal = $(Invoke-Expression $tfViewCommand)
            }
        }
    }
    
    if (!$noMessage)
    {
        echo "...complete"
        dir $output
    }
}




function New-Workspace{
<#

.SYNOPSIS

Creates a new empty TFS workspace.



.DESCRIPTION

tf workspace /new /noprompt does not inherently work.

The New-Workspace a combination of tf commands behind the scenes. It first looks for an empty 
workspace to use as a template. If one is not found, it will create a new permanent template workspace,
and then use that to create the desired workspace.



.PARAMETER tfsUrl 

The URL of the TFS server. If this is not supplied, it will try to use $env:TFS_URL. 



.PARAMETER newWorkspaceName

The desired name of the new workspace. If that already exists, it will append _{n} for up to 100 tries.



.EXAMPLE

New-Workspace

.EXAMPLE

New-Workspace -newWorkspaceName:MY_NEW_WORKSPACE-dev

.EXAMPLE 

New-Workspace -tfsUrl:https://tfs.mycompany.com/tfs

.EXAMPLE 

New-Workspace -tfsUrl:https://tfs.mycompany.com/tfs -newWorkspaceName:MY_NEW_WORKSPACE-dev


.NOTES


#>

    param(
        [string]$tfsUrl,
        [string]$newWorkspaceName = "$env:COMPUTERNAME"
    )

    if($tfsUrl -eq "" -or $tfsUrl -eq $null){
        $tfsUrl = Get-EnvironmentVariable $tfsUrlString
    }

    function New-WorkspaceFromTemplate {
        param(
            [string]$newName,
            [string]$templateName
        )

        tf workspace /new /noprompt /template:$templateName $newName /collection:$tfsUrl
    }

    function Get-WorkspaceNames{
        [string[]]$wsNames = @()
        $workspaces = $(tf workspaces /format:detailed /collection:$tfsUrl | ? {$_ -match "Workspace"} | ? {$_ -notmatch "No workspace"} )
        foreach ($ws in $workspaces)
        {
            $wsName = $ws.Split(":")[1].Trim()
            #Write-Host $wsName
            $wsNames += $wsName
        }
        return $wsNames
    }

    function Create-TemplateWorkspace{
        $wsNames = Get-WorkspaceNames

        if($wsNames -eq $null){
            $defaultName = $env:COMPUTERNAME + "_template"
            tf workspace /new /noprompt $defaultName  /collection:"$tfsurl"
            tf workfold /unmap $/ /workspace:$defaultName /collection:"$tfsurl"
            return $defaultName
        }

        foreach ($wsName in $wsNames){
            $workingFolders = Get-WorkingFolders $wsName
            if($workingFolders.Count -eq 1){
                $donorWorkspace = $wsName
                break
            }
        }
        if ($donorWorkspace -eq ""){
            #no singly mapped workspaces
            $donorWorkspace = $wsNames[0]
        }
        $donorMappings = Get-WorkingFolders $donorWorkspace
        foreach ($mapping in $donorMappings){
            # $/mb/util : C:\IIS\wwwroot\util
            tf workfold /unmap $mapping.Replace($mapping.Split(":")[0]+": ","").Trim() /workspace:$donorWorkspace #/collection:$tfsUrl
        }
        #donor is now a template

        #create permanent template
        $templateName = $env:COMPUTERNAME + "_template"
        if ($wsNames -match $templateName){
            $templateName = $donorWorkspace + "_template"
        } 

        New-WorkspaceFromTemplate -newName:$templateName -templateName:$donorWorkspace
        #tf workspace /new /noprompt /template:$donorWorkspace $templateName /collection:$tfsUrl

        #restore mappings
        foreach ($mapping in $donorMappings){
            # $/mb/util : C:\IIS\wwwroot\util
            #tf workfold /map serverfolder localfolder
            #[/collection:TeamProjectCollectionUrl]
            #[/workspace:workspacename]
            #[/login:username,[password]]
            $serverFolder = $mapping.Split(":")[0].Trim();
            $localFolder = $mapping.Replace($serverFolder+": ","").Trim();
            tf workfold /map $serverFolder $localFolder /collection:$tfsUrl /workspace:$donorWorkspace
        }

        return $templateName
    }

    function Get-WorkingFolders {
        param(
            [string]$workspaceName
        )
        $workspace = tf workspaces $workspaceName /format:detailed /collection:$tfsUrl
        $workingFolders = $($workspace | ? {$_ -match ".*\$"})
        return $workingFolders
    }

    function Find-TemplateWorkspace{
        $templateName = ""
        foreach ($wsName in Get-WorkspaceNames){
            $workingFolders = Get-WorkingFolders $wsName
            if($workingFolders.Count -eq 0){
                $templateName = $wsName
                break
            }
        }
        return $templateName
    }


    function Get-TemplateWorkspace {
        $templateName = Find-TemplateWorkspace 
        if ($templateName -eq ""){
            $templateName = Create-TemplateWorkspace
        }
        return $templateName
    }


    $template = Get-TemplateWorkspace

    $usedWorkspaces = Get-WorkspaceNames

    if ($usedWorkspaces -contains $newWorkspaceName)
    {
        for($i=1; $i -le 100; $i++)
        {
            if ($usedWorkspaces -notcontains $($newWorkspaceName + "_$i"))
            {
                $newWorkspaceName = $($newWorkspaceName + "_$i")
                break
            }
        }
    }
    
    Write-Host "Creating new workspace $newWorkspaceName for $tfsUrl"

    New-WorkspaceFromTemplate -newName:$newWorkspaceName -templateName:$template
   
    Write-Host "Finished"

    return $newWorkspaceName
}

function Get-TfsCodeClosure {
    <#
        .SYNOPSIS
        Report the relative degree of closure of a codebase.
        
        .DESCRIPTION
        Are you concerned that your codebase is a festering one? Want 
        proof? Then run this function at the solution root and watch as 
        it reports the number of check-ins per C# code file. This 
        function only works against TFS source control (and the working 
        directory must be mapped in a Workspace for the TFS PowerShell 
        snap-in to work). The idea is that files with numerous check-ins 
        are being modified in-place. Whereas, the Open-Closed Principle 
        states that 
        
            "entities should be open for extension, but 
             closed for modification"
            
        What we want to see is a budding codebase! New files, meaning new 
        classes and methods, are preferable.
    
        .EXAMPLE
        C:\PS> Get-TfsCodeClosure | Format-Table -AutoSize
        
        .EXAMPLE
        C:\PS> Get-TfsCodeClosure | Export-CSV closure.csv
    #>

    Import-TfsLibraries

    $filter = [Microsoft.TeamFoundation.VersionControl.Client.ChangeType] 'Add,Edit,Rename'

    Get-TfsItemHistory -Include *.cs -Recurse -IncludeItems `
        | Select-Object -Expand 'Changes' `
        | Where-Object { ($_.ChangeType -band $filter) -ne 0 } `
        | Select-TfsItem `
        | Group-Object Path `
        | Select-Object Count, Name `
        | Sort-Object Count -Descending 
}

function Get-TfsCodeOwnership {
    <#
        .SYNOPSIS
        What pieces of code are owned by someone, and how you can detect 
        it? Owned means that they are the only one that can touch that 
        code. Whatever it is by policy or simply because they are the 
        only one with the skills / ability to do so.
        
        .DESCRIPTION
        This would be a good way to indicate a risky location, some place 
        that only very few people can touch and modify.
        
            * Find all files changed within the last year
            * Remove all files whose changes are over a period of less than 
              two weeks (that usually indicate a completed feature).
            * Remove all the files that are modified by more than 2 people.
            * Show the result and the associated names.
            
        .EXAMPLE
        C:\PS> Get-TfsCodeOwnership
        
        Report the ownership for any C# files (.cs) that exist in this 
        directory.
    #>
    
    Import-TfsLibraries

    $filter     = [Microsoft.TeamFoundation.VersionControl.Client.ChangeType] 'Add,Edit,Rename'
    $threshold  = (Get-Date).AddYears(-1)
    $twoWeeks   = [timespan]::FromDays(14)
    
    $changesets = Get-TfsItemHistory *.cs -Recurse -IncludeItems `
        | ?{ $_.CreationDate -gt $threshold }
    
    $files = $changesets `
        | Select-Object -Expand 'Changes' `
        | ?{ ($_.ChangeType -band $filter) -ne 0 } `
        | Select-TfsItem `
        | Group-Object Path

    $files | %{
        $context = $_ `
            | Select-Object -Expand Group `
            | Select-Object -Expand Versions `
            | Select-Object ChangesetId `
            | % -begin { $ctx = @() } -process { $ctx += $changesets | ?{ $_.ChangesetId -eq $id.ChangesetId } } -end { $ctx }
        
        # Consider all files whose changes span over 2 weeks
        $dates  = $context | Select-Object -Expand CreationDate | Sort-Object
        $period = [datetime]($dates[0]) - [datetime]($dates[-1])
        if(-not($period -gt $twoWeeks)) {
            return
        }
        
        # Add all files with 1 or 2 authors
        $authors = $context | Group-Object Committer
        if($authors.Length -gt 2) {
            return
        }
        
        $_ | Select-Object `
            @{ Name = 'Item';    Expression = { $_.Name } }, `
            @{ Name = 'Authors'; Expression = { $authors | Select-Object -Expand Name } }
    }
}

function Import-TfsLibraries {
    $snapin   = 'Microsoft.TeamFoundation.PowerShell'
    $assembly = 'Microsoft.TeamFoundation.VersionControl.Client'

    if(-not(Get-PSSnapin $snapin -Registered)) {
        Add-PSSnapin $snapin | Out-Null
    }
    
    [System.Reflection.Assembly]::LoadWithPartialName($assembly) | Out-Null   
}

