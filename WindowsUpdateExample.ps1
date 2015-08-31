$Script:Version = 'v0.1'

function Create-SCCMSoftwareUpdateGroups
{
    [CmdletBinding()]
    
    param
    (
        [Parameter()]
        [Int[]] $ExcludeUpdate,

        [Parameter()]
        [ValidateRange(10, 2147483647)]
        [Int] $MaxUpdatesPerUpdateGroup = 499,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String] $BaseName = 'Approved Updates $($DatePosted.Year)',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String] $CurrentYearAppend = ' - $($DatePosted.ToString("MMMM"))',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String] $AboveLimitAppend = ' # Part $Index',

        [Parameter()]
        [ValidateNotNull()]
        [String] $Description = 'Created by: WindowsUpdates Script $Script:Version `r`nCreated on: $([DateTime]::Now.ToShortDateString())',

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.Management.ManagementObject[]] $Update = (Get-SCCMWmiObject -Query "Select SMS_SoftwareUpdate.* FROM SMS_SoftwareUpdate INNER JOIN SMS_CIToContent ON SMS_CIToContent.CI_ID = SMS_SoftwareUpdate.CI_ID WHERE SMS_SoftwareUpdate.IsSuperseded=0 AND SMS_SoftwareUpdate.IsExpired=0 AND (SMS_CIToContent.ContentLocales = 'Locale:0' OR SMS_CIToContent.ContentLocales = 'Locale:9')")
    )

    Process
    {
        if ($Update.__Class -ne 'SMS_SoftwareUpdate')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $Update to be a WMI object of class SMS_SoftwareUpdate'))
        }
        
        $Updates = $Update
        $SoftwareUpdateGroups = @{}

        for ($i = 0; $i -lt $Updates.Count; $i++)
        {
            $DatePosted = [System.Management.ManagementDateTimeConverter]::ToDateTime($Updates[$i].DatePosted)
            Write-Progress -Activity "Processing Update $($i + 1) / $($Updates.Count)" -Status "CI: $($Updates[$i].CI_ID); Name: $($Updates[$i].LocalizedCategoryInstanceNames); DatePosted: $DatePosted" -PercentComplete ($i / ($Updates.Count + 1) * 100) -Id 1

            if ($ExcludedUpdates -contains $Updates[$i].CI_ID)
            {
                Write-Verbose "	**Ignoring excluded update $($Updates[$i].CI_ID): $($Updates[$i].LocalizedCategoryInstanceNames): $DatePosted"
                continue
            }

            Write-Verbose "	**Evaluating update $($Updates[$i].CI_ID): $($Updates[$i].LocalizedCategoryInstanceNames): $DatePosted"
            
            $DisplayName = Invoke-Expression `"$BaseName`"
            if ($DatePosted.Year -eq [DateTime]::Now.Year)
            {
                $DisplayName += Invoke-Expression `"$CurrentYearAppend`"
            }

            if (Test-SCCMSoftwareUpdateInSoftwareUpdateGroup -DisplayName "$DisplayName%" -Update $Updates[$i].CI_ID -Operator Like)
            {
                Write-Verbose "	Update is already in correct Software Update Group, skipping"
                continue
            }

            $BaseDisplayName = $DisplayName
            $Index = 1
            # Check if software update group with name $DisplayName already exists in our hashtable
            while ($true)
            {
                Write-Verbose "Tentatively sorting update in Software Update Group '$DisplayName'"
                
                if ($SoftwareUpdateGroups.ContainsKey($DisplayName))
                {
                    $SoftwareUpdateGroup = $SoftwareUpdateGroups[$DisplayName]
                }
                else
                {
                    $SoftwareUpdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName = '$DisplayName'"
                    
                    if (-not $SoftwareUpdateGroup)
                    {
                        Write-Verbose "Software Update Group '$DisplayName' does not yet exist, creating it"
                        $SoftwareUpdateGroup = New-SCCMSoftwareUpdateGroup -DisplayName $DisplayName -Description (Invoke-Expression `"$Description`")
                    }
                    $SoftwareUpdateGroups.Add($DisplayName, $SoftwareUpdateGroup)
                }

                if ($SoftwareUpdateGroup.Updates.Count -ge $MaxUpdatesPerUpdateGroup)
                {
                    Write-Verbose "Software Update Group '$DisplayName' already contains $MaxUpdatesPerUpdateGroup or more updates, moving to next one"
                    $Index++
                    $DisplayName = $BaseDisplayName + (Invoke-Expression `"$AboveLimitAppend`")
                }
                else
                {
                    break
                }
            }

            Write-Verbose "Assigning it to Software Update Group: $DisplayName"
            $SoftwareUpdateGroup.Updates += $Updates[$i].CI_ID
        }

        Write-Progress -Activity "All Updates Processed" -Id 1 -Completed

        $i = 1
        foreach ($key in $SoftwareUpdateGroups.Keys)
        {
            Write-Progress -Activity "Committing changes to Software Update Group '$key'" -Status "$($i + 1) / $($SoftwareUpdateGroups.Keys.Count)" -PercentComplete (($i / $SoftwareUpdateGroups.Keys.Count) * 100) -Id 2
            [void] $SoftwareUpdateGroups[$key].Put()
            $i++
        }

        Write-Progress -Activity "Committing changes complete" -Id 2 -Completed
    }
}

function Download-SCCMSoftwareUpdateGroups
{
    [CmdletBinding()]

    param
    (
        [Parameter()]
        [System.Management.ManagementObject[]] $SoftwareUpdateGroup = (Get-SCCMSoftwareUpdateGroup -ExpandLazyProperties),
        
        [Parameter()]
        [String] $DestinationPath
    )

    Process
    {
        if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
        }
        
        for ($i = 0; $i -lt $SoftwareUpdateGroup.Count; $i++)
        {
            Write-Progress -Activity "Processing Software Update Group: $($SoftwareUpdateGroup[$i].LocalizedDisplayName)" -Status "$($i + 1) / $($SoftwareUpdateGroup.Count)" -PercentComplete ($i / $SoftwareUpdateGroup.Count * 100) -Id 3
            
            for ($j = 0; $j -lt $SoftwareUpdateGroup[$i].Updates.Count; $j++)
            {
                Write-Progress -Activity "Processing Update: $($SoftwareUpdateGroup[$i].Updates[$j])" -Status "$($j + 1) / $($SoftwareUpdateGroup[$i].Updates.Count)" -PercentComplete ($j / $SoftwareUpdateGroup[$i].Updates.Count * 100) -Id 4 -ParentId 3

				while ((Get-BitsTransfer).Count -ge 60)
                {
                    Get-BitsTransfer | Where-Object {$_.JobState -eq 'Transferred'} | Complete-BitsTransfer
                    Start-Sleep -Milliseconds 500
                }
				
                [void] (Invoke-SCCMDownloadSoftwareUpdate -Update $SoftwareUpdateGroup[$i].Updates[$j] -Destination $DestinationPath -Asynchronous -Verbose)
            }
        }

        While (Get-BitsTransfer)
        {
            Get-BitsTransfer | Where-Object {$_.JobState -eq 'Transferred'} | Complete-BitsTransfer
            Start-Sleep -Milliseconds 500
        }
    }
}

function Assign-UpdatesToSoftwareUpdatePackage
{
    [CmdletBinding()]

    param
    (
        [Parameter()]
        [System.Management.ManagementObject[]] $SoftwareUpdateGroup = (Get-SCCMSoftwareUpdateGroup -ExpandLazyProperties),

        [Parameter()]
        [String] $BasePath,

        [Parameter()]
        [String] $SourcePath,

        [Parameter()]
        [String] $Description = 'Created by: WindowsUpdates Script $Script:Version `r`nCreated on: $([DateTime]::Now.ToShortDateString())'
    )

    Process
    {
        if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
        }

        for ($i = 0; $i -lt $SoftwareUpdateGroup.Count; $i++)
        {
            Write-Progress -Activity "Processing Software Update Group: $($SoftwareUpdateGroup[$i].LocalizedDisplayName)" -Status "$($i + 1) / $($SoftwareUpdateGroup.Count)" -PercentComplete ($i / $SoftwareUpdateGroup.Count * 100) -Id 5
                        
            $SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$($SoftwareUpdateGroup[$i].LocalizedDisplayName)'"
            
            if (-not $SoftwareUpdatePackage)
            {
                $SoftwareUpdatePackage = New-SCCMSoftwareUpdatePackage -Name $SoftwareUpdateGroup[$i].LocalizedDisplayName -Description (Invoke-Expression `"$Description`") -PkgSourcePath "$BasePath\$($SoftwareUpdateGroup[$i].LocalizedDisplayName)"
            }

            $result = (Add-SCCMSoftwareUpdateToSoftwareUpdatePackage -Update $SoftwareUpdateGroup[$i].Updates -SoftwareUpdatePackage $SoftwareUpdatePackage -RootFolder $SourcePath -ErrorAction Stop -Verbose).ReturnValue
            
            Write-Verbose "Completed $($SoftwareUpdateGroup[$i].LocalizedDisplayName) with error code $result"
        }
    }
}

function Remove-SupersededAndExpiredUpdates
{
	[CmdletBinding()]

	param
	(
		[Parameter()]
		[System.Management.ManagementObject[]] $SoftwareUpdateGroup = (Get-SCCMSoftwareUpdateGroup -ExpandLazyProperties),

		[Parameter()]
		[System.Management.ManagementObject[]] $SoftwareUpdatePackage = (Get-SCCMSoftwareUpdatePackage),

		[Parameter()]
		[System.Management.ManagementObject[]] $SoftwareUpdateDeployment = (Get-SCCMSoftwareUpdateDeployment),

		[Parameter()]
		[System.Management.ManagementObject[]] $SoftwareUpdate = (Get-SCCMSoftwareUpdate -Filter "IsExpired = 1 or IsSuperseded = 1")
	)

	Begin
	{
		if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
        }

		if ($SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdatePackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
        }

		if ($SoftwareUpdateDeployment.__Class -ne 'SMS_UpdatesAssignment')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdateDeployment to be a WMI object of class SMS_UpdatesAssignment'))
        }

		if ($SoftwareUpdate.__Class -ne 'SMS_SoftwareUpdate')
        {
            $PSCmdlet.ThrowTerminatingError((New-ErrorRecord 'Expected $SoftwareUpdate to be a WMI object of class SMS_SoftwareUpdate'))
        }
	}

	Process
	{
		# Remove updates from SoftwareUpdateGroup(s)
		foreach ($singleSoftwareUpdateGroup in $SoftwareUpdateGroup)
		{
			$singleSoftwareUpdateGroup = Remove-SCCMSoftwareUpdateFromSoftwareUpdateGroup -Update $SoftwareUpdate.CI_ID -SoftwareUpdateGroup $singleSoftwareUpdateGroup

			if ($singleSoftwareUpdateGroup.Updates.Count -eq 0)
			{
				Remove-SCCMSoftwareUpdateGroup -SoftwareUpdateGroup $singleSoftwareUpdateGroup
			}
		}
		
		# Remove updates from SoftwareUpdatePackage(s)
		foreach ($singleSoftwareUpdatePackage in $SoftwareUpdatePackage)
		{
			Remove-SCCMSoftwareupdateFromSoftwareUpdatePackage -Update $SoftwareUpdate.CI_ID -SoftwareUpdatePackage $singleSoftwareUpdatePackage

			if (@(Get-SCCMWmiObject -Class SMS_PackageToContent -Filter "PackageId = '$($singleSoftwareUpdatePackage.PackageId)'").Count -eq 0)
			{
				Remove-SCCMSoftwareUpdatePackage -Name $singleSoftwareUpdatePackage.Name
			}

            # Update distribution Point
		}

        # Remove updates from SoftwareUpdateDeployment(s)
		foreach ($singleSoftwareUpdateDeployment in $SoftwareUpdateDeployment)
        {
            if ($singleSoftwareUpdateDeployment.AssignmentName -eq 'TEST')
            {
                $singleSoftwareUpdateDeployment.AssignedCIs.Count
            }
            
            $singleSoftwareUpdateDeployment = Remove-SCCMSoftwareUpdateFromSoftwareUpdateDeployment -Update $SoftwareUpdate.CI_ID -SoftwareUpdateDeployment $singleSoftwareUpdateDeployment

            if ($singleSoftwareUpdateDeployment.Count -eq 0)
            {
                Remove-SCCMSoftwareUpdateDeployment -Name $singleSoftwareUpdateDeployment
            }
        }
		
	}
}
