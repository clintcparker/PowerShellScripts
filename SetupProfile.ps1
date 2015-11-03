function SetupProfile {

    function _Get-Profile(){
        $pathExists = Split-Path $profile | Test-Path

        if ($pathExists -ne $true)
        {
            mkdir $(Split-Path $profile)
        }

        Invoke-WebRequest "https://raw.githubusercontent.com/clintcparker/PowerShellScripts/master/Profile.ps1" -OutFile $PROFILE ; . $PROFILE
    }






    $title = "Setup New Profile"
    $message = "Are you sure you want to update your profile?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
	    "Downloads new profile & modules from GitHub"

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
	    "Exits"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result)
    {
	    0 {
		    "You selected Yes."
			_Get-Profile
	    }
	    1 {
            "You selected No. Goodbye."
        }
    }
}

SetupProfile
