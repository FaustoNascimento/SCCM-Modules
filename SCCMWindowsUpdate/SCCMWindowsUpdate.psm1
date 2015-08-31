function Get-SCCMSoftwareUpdate
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$Filter,
		
		[Parameter()]
		[String[]]$Property,
		
		[Parameter()]
		[Switch]$ExpandLazyProperties
	)
	
	End
	{
		Get-SCCMWmiObject -Class SMS_SoftwareUpdate @PSBoundParameters
	}
}

function New-SCCMSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[String]$DisplayName,
		
		[Parameter()]
		[String]$Description,
		
		[Parameter()]
		[Int]$LocaleID = 1033,
		
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update
	)
	
	Process
	{
		if ($Update)
		{
			$Updates += $Update
		}
	}
	End
	{
		[void]$PSBoundParameters.Remove('Update')
		$LocalizedProperties = New-SCCMLocalizedProperties @PSBoundParameters
		
		$SoftwareUpdateGroup = New-SCCMWmiInstance -Class SMS_AuthorizationList
		$SoftwareUpdateGroup.LocalizedInformation = $LocalizedProperties
		$SoftwareUpdateGroup.Updates = $Updates
		
		[WMI] ($SoftwareUpdateGroup.Put()).Path
	}
}

function Get-SCCMSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$Filter,
		
		[Parameter()]
		[String[]]$Property,
		
		[Parameter()]
		[Switch]$ExpandLazyProperties
	)
	
	End
	{
		Get-SCCMWmiObject -Class SMS_AuthorizationList @PSBoundParameters
	}
}

function Set-SCCMSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'SoftwareUpdateGroup')]
		[System.Management.ManagementObject]$SoftwareUpdateGroup,
		
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'DisplayName')]
		[Alias('Name')]
		[String]$DisplayName,
		
		[Parameter(ParameterSetName = 'DisplayName')]
		[Parameter(ParameterSetName = 'SoftwareUpdateGroup')]
		[Alias('NewName')]
		[String]$NewDisplayName,
		
		[Parameter(ParameterSetName = 'DisplayName')]
		[Parameter(ParameterSetName = 'SoftwareUpdateGroup')]
		[String]$Description,
		
		[Parameter(ParameterSetName = 'DisplayName')]
		[Parameter(ParameterSetName = 'SoftwareUpdateGroup')]
		[String]$LocaleID
	)
	
	Process
	{
		if ($DisplayName)
		{
			$SoftwareUpdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName = '$DisplayName'"
			if (-not $SoftwareUpdateGroup)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find Software Update Group with name '$DisplayName'"))
				return
			}
		}
		else
		{
			if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
				return
			}
		}
		
		if ($PSBoundParameters.ContainsKey('NewDisplayName') -or $PSBoundParameters.ContainsKey('Description') -or $PSBoundParameters.ContainsKey('LocaleID'))
		{
			if (-not $LocaleID)
			{
				$LocaleID = $SoftwareUpdateGroup.LocalizedPropertyLocaleId
			}
			
			if (-not $NewDisplayName)
			{
				$NewDisplayName = $DisplayName
			}
			
			if (-not $Description)
			{
				$Description = $SoftwareUpdateGroup.LocalizedDescription
			}
			
			$LocalizedProperties = New-SCCMLocalizedProperties -DisplayName $NewDisplayName -Description $Description -LocaleID $LocaleID
			$SoftwareUpdateGroup.LocalizedInformation = $LocalizedProperties
			
			[void]$SoftwareUpdateGroup.Put()
		}
		
		[WMI] $SoftwareUpdateGroup.__Path
	}
}

function Remove-SCCMSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'SoftwareUpdateGroup')]
		[System.Management.ManagementObject]$SoftwareUpdateGroup,
		
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'DisplayName')]
		[String]$DisplayName
	)
	
	Process
	{
		if ($DisplayName)
		{
			$SoftwareupdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName = '$DisplayName'"
			
			if (-not $SoftwareUpdateGroup)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find Software Update Group with name '$DisplayName'"))
				return
			}
		}
		else
		{
			if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
				return
			}
		}
		
		$SoftwareUpdateGroup.Delete()
	}
}

function Add-SCCMSoftwareUpdateToSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[String]$DisplayName,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[System.Management.ManagementObject]
		$SoftwareUpdateGroup,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update
	)
	Process
	{
		if ($DisplayName -and $LoadedSoftwareUpdateGroup.LocalizedDisplayName -ne $DisplayName)
		{
			if ($LoadedSoftwareUpdateGroup)
			{
				[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
			}
			
			$LoadedSoftwareUpdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName = '$DisplayName'" -ExpandLazyProperties
			
			if (-not $LoadedSoftwareUpdateGroup)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find Software Update Group with name '$DisplayName'"))
				return
			}
		}
		elseif ($SoftwareUpdateGroup -and ($LoadedSoftwareUpdateGroup.LocalizedDisplayName -ne $SoftwareUpdateGroup.LocalizedDisplayName -or -not $LoadedSoftwareUpdateGroup))
		{
			if ($LoadedSoftwareUpdateGroup)
			{
				[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
			}
			
			if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
				return
			}
			
			$LoadedSoftwareUpdateGroup = $SoftwareUpdateGroup
		}
		
		$LoadedSoftwareUpdateGroup.Updates += $Update
	}
	End
	{
		[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
	}
}

function Remove-SCCMSoftwareUpdateFromSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[ValidateNotNullOrEmpty()]
		[Alias('Name')]
		[String]$DisplayName,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[System.Management.ManagementObject]
		$SoftwareUpdateGroup,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update
	)
	
	Process
	{
		if ($DisplayName -and $LoadedSoftwareUpdateGroup.LocalizedDisplayName -ne $DisplayName)
		{
			if ($LoadedSoftwareUpdateGroup)
			{
				$LoadedSoftwareUpdateGroup.Updates = $UpdatesInSoftwareUpdateGroup.ToArray()
				[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
			}
			
			$LoadedSoftwareUpdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName = '$DisplayName'" -ExpandLazyProperties
			
			if (-not $LoadedSoftwareUpdateGroup)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find Software Update Group with name '$DisplayName'"))
				return
			}
		}
		elseif ($SoftwareUpdateGroup -and ($LoadedSoftwareUpdateGroup.LocalizedDisplayName -ne $SoftwareUpdateGroup.LocalizedDisplayName -or -not $LoadedSoftwareUpdateGroup))
		{
			if ($LoadedSoftwareUpdateGroup)
			{
				$LoadedSoftwareUpdateGroup.Updates = $UpdatesInSoftwareUpdateGroup.ToArray()
				[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
			}
			
			if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
				return
			}
			
			$LoadedSoftwareUpdateGroup = $SoftwareUpdateGroup
		}
		
		$UpdatesInSoftwareUpdateGroup = [System.Collections.ArrayList]$LoadedSoftwareUpdateGroup.Updates
		for ($i = 0; $i -lt $Update.Count; $i++)
		{
			$UpdatesInSoftwareUpdateGroup.Remove([UInt32]$Update[$i])
		}
	}
	
	End
	{
		$LoadedSoftwareUpdateGroup.Updates = $UpdatesInSoftwareUpdateGroup.ToArray()
		[WMI] ($LoadedSoftwareUpdateGroup.Put()).Path
	}
}

function Test-SCCMSoftwareUpdateInSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[System.Management.ManagementObject]$SoftwareUpdateGroup,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[Alias('Name')]
		[String]$DisplayName,
		
		[Parameter(ParameterSetName = 'DisplayName')]
		[ValidateSet('Equals', 'NotEquals', 'Like')]
		[String]$Operator = 'Equals',
	
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DisplayName')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateGroup')]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update
	)
	
	Process
	{
		if ($DisplayName -and -not $LoadedSoftwareUpdateGroup.LocalizedDisplayName -match $DisplayName.Replace('%', ''))
		{
			switch ($Operator)
			{
				'Equals'	{ $Oper = '=' }
				'NotEquals'	{ $Oper = '!=' }
				'Like'		{ $Oper = 'like' } # Unneeded, but kept for visibility
			}
			
			$LoadedSoftwareUpdateGroup = Get-SCCMSoftwareUpdateGroup -Filter "LocalizedDisplayName $Oper '$DisplayName'" -ExpandLazyProperties
			
			if (-not $LoadedSoftwareUpdateGroup)
			{
				return $false
			}
		}
		
		if ($SoftwareUpdateGroup -and $LoadedSoftwareUpdateGroup.LocalizedDisplayName -ne $SoftwareUpdateGroup.LocalizedDisplayName)
		{
			if ($SoftwareUpdateGroup.__Class -ne 'SMS_AuthorizationList')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateGroup to be a WMI object of class SMS_AuthorizationList'))
				return
			}
			
			$LoadedSoftwareUpdateGroup = $SoftwareUpdateGroup
		}
		
		for ($i = 0; $i -lt $Update.Count; $i++)
		{
			if ($LoadedSoftwareUpdateGroup.Updates.Count -eq 0 -or -not $LoadedSoftwareUpdateGroup.Updates.Contains($Update[$i]))
			{
				return $false
			}
		}
		
		return $true
	}
}

function Get-SCCMSoftwareUpdateSoftwareUpdateGroup
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline, Mandatory, ValueFromPipelineByPropertyName)]
		[Alias('Updates', 'CI_ID')]
		[Uint32[]]$Update
	)
	
	Begin
	{
		$SoftwareUpdateGroups = Get-SCCMSoftwareUpdateGroup -ExpandLazyProperties
	}
	
	Process
	{
		# HashSet's are incredibly fast and prevent duplicate items from being added without need for verification
		$SoftwareUpdateGroupContainer = New-Object 'System.Collections.Generic.HashSet[Object]]'
		foreach ($SoftwareUpdateGroup in $SoftwareUpdateGroups)
		{
			for ($i = 0; $i -lt $Update.Count; $i++)
			{
				if ($SoftwareUpdateGroup.Updates.Contains($Update[$i]))
				{
					[void]$SoftwareUpdateGroupContainer.Add($SoftwareUpdateGroup)
				}
			}
		}
		
		# Convert it to array since it's a much more common type in PowerShell.
		[Array]$SoftwareUpdateGroupContainer
	}
}

function Get-SCCMSoftwareUpdateCIContentFiles
{
	[CmdletBinding(DefaultParameterSetName = 'Filter')]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Update')]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update,
		
		[Parameter(ParameterSetName = 'Update')]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9'),
		
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Filter')]
		[String]$Filter,
		
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Filter')]
		[Switch]$ExpandLazyProperties,
		
		[Parameter(ParameterSetName = 'Filter')]
		[String[]]$Property
	)
	
	Process
	{
		if ($Update)
		{
			$UpdatesQuery = New-WmiQueryFormatting -Object $Update -LeftOperand SMS_CIToContent.CI_ID
			$LocalesQuery = New-WmiQueryFormatting -Object $ContentLocales -LeftOperand SMS_CIToContent.ContentLocales
			
			[Void]$PSBoundParameters.Remove('Update')
			[Void]$PSBoundParameters.Remove('ContentLocales')
			
			if ($ContentLocales)
			{
				return (Get-SCCMWmiObject -Query "SELECT SMS_CIContentFiles.* FROM SMS_CIContentFiles INNER JOIN SMS_CIToContent ON SMS_CIToContent.ContentID = SMS_CIContentFiles.ContentID WHERE ($UpdatesQuery) AND ($LocalesQuery)" @PSBoundParameters)
			}
			else
			{
				return (Get-SCCMWmiObject -Query "SELECT SMS_CIContentFiles.* FROM SMS_CIContentFiles INNER JOIN SMS_CIToContent ON SMS_CIToContent.ContentID = SMS_CIContentFiles.ContentID WHERE $UpdatesQuery" @PSBoundParameters)
			}
		}
		
		Get-SCCMWmiObject -Class SMS_CIContentFiles @PSBoundParameters
	}
}

function Get-SCCMSoftwareUpdateCIToContent
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Update')]
		[Alias('CI_ID', 'Updates')]
		[UInt32[]]$Update,
		
		[Parameter(ParameterSetName = 'Update')]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9'),
		
		[Parameter(ParameterSetName = 'Filter')]
		[String]$Filter,
		
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Filter')]
		[Switch]$ExpandLazyProperties,
		
		[Parameter(ParameterSetName = 'Filter')]
		[String[]]$Property
	)
	
	Process
	{
		if ($Update)
		{
			$QueryUpdate = New-WmiQueryFormatting -Object $Update -LeftOperand CI_ID
			$QueryLocales = New-WmiQueryFormatting -Object $ContentLocales -LeftOperand ContentLocales
			
			[Void]$PSBoundParameters.Remove('Update')
			[Void]$PSBoundParameters.Remove('ContentLocales')
			
			if ($QueryLocales)
			{
				return Get-SCCMWmiObject -Query "SELECT * FROM SMS_CIToContent WHERE ($QueryUpdate) AND ($QueryLocales)" @PSBoundParameters
			}
			else
			{
				return Get-SCCMWmiObject -Query "SELECT * FROM SMS_CIToContent WHERE $QueryUpdate" @PSBoundParameters
			}
		}
		
		Get-SCCMWmiObject -Class SMS_CIToContent @PSBoundParameters
	}
}

function Test-FileHash
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[String]$Path,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[String]$Hash,
	
		[Parameter()]
		[ValidateSet('MACTripleDES', 'MD5', 'RIPEMD160', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
		[String]$Algorithm = 'SHA1'
	)
	
	Process
	{
		$fileHash = (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
		
		if ($fileHash -eq $Hash)
		{
			return $true
		}
		
		$false
	}
}

function Test-SCCMSoftwareUpdateHash
{
    [CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update,
		
		[Parameter(Mandatory)]
		[String]$RootFolder,
		
		[Parameter()]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9')
    )

    Process
    {
        [void]$PSBoundParameters.Remove('RootFolder')

        $CIContentFiles = Get-SCCMSoftwareUpdateCIContentFiles @PSBoundParameters
        
        foreach ($CIContentFile in $CIContentFiles)
        {
            if (Test-Path "$RootFolder\$($CIContentFile.ContentID)\$($CIContentFile.FileName)")
            {
                $ValidHash = Test-FileHash -Path "$RootFolder\$($CIContentFile.ContentID)\$($CIContentFile.FileName)" -Hash $CIContentFile.FileHash.SubString(5)
            }
            else
            {
                $ValidHash = $false
            }

            $result = @{}
            $result.FileName = "$RootFolder\$($CIContentFile.ContentID)\$($CIContentFile.FileName)"
            $result.ValidHash = $ValidHash

            New-Object -TypeName PSObject -Property $Result
        }

    }
}

function Invoke-SCCMDownloadSoftwareUpdate
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
		[Alias('Updates', 'CI_ID')]
		[UInt32[]]$Update,
		
		[Parameter(Mandatory)]
		[String]$Destination,
		
		[Parameter()]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9'),
		
		[Parameter()]
		[Switch]$Asynchronous,
		
		[Parameter()]
		[ValidateSet('Foreground', 'High', 'Normal', 'Low')]
		[String]$Priority = 'Normal'
	)
	
	Process
	{
		[void]$PSBoundParameters.Remove('Destination')
		[void]$PSBoundParameters.Remove('Asynchronous')
		
		$CIContentFiles = Get-SCCMSoftwareUpdateCIContentFiles @PSBoundParameters
		
		$filesToDownload = @()
		$destinationPaths = @()
		
		foreach ($CIContentFile in $CIContentFiles)
		{
			Write-Verbose "Processing Content $($CIContentFile.ContentID)"
			
			$DestinationPath = "$Destination\$($CIContentFile.ContentID)"
			
			if (-not (Test-Path -Path $DestinationPath -PathType Container))
			{
				Write-Verbose "	'$DestinationPath' does no exist, creating it"
				New-Item -Path $DestinationPath -ItemType Directory
			}
			elseif (Test-Path -Path "$DestinationPath\$($CIContentFile.FileName)" -PathType Leaf)
			{
				Write-Verbose "	'$DestinationPath\$($CIContentFile.FileName)' already exists, will not re-download"
				continue
			}
			
			$filesToDownload += $CIContentFile
			$destinationPaths += "$DestinationPath\$($CIContentFile.FileName)"
		}
		
        if ($filesToDownload)
		{
            if ($Asynchronous)
		    {
			    Write-Verbose "Starting download of $($filesToDownload.Count) files asynchronously with priority $Priority"
			    Start-BitsTransfer -Source $filesToDownload.SourceURL -Destination $destinationPaths -Asynchronous -Priority $Priority
		    }
		    else
		    {
			    Write-Verbose "Starting download of $($filesToDownload.Count) files synchronously with priority $Priority"
			    Start-BitsTransfer -Source $filesToDownload.SourceURL -Destination $destinationPaths -Priority $Priority
		    }
        }
	}
}

function Get-SCCMSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$Filter,
		
		[Parameter()]
		[Switch]$ExpandLazyProperties,
		
		[Parameter()]
		[String[]]$Property
	)
	
	End
	{
		Get-SCCMWmiObject -Class SMS_SoftwareUpdatesPackage @PSBoundParameters
	}
}

function New-SCCMSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[String]$Name,
		
		[Parameter()]
		[String]$Description,
		
		[Parameter(Mandatory)]
		[String]$PkgSourcePath,
		
		[Parameter()]
		[String]$SourceSite = $Script:SiteCode,
		
		[Parameter()]
		[String]$PkgSourceFlag = 2
	)
	
	End
	{
		$SoftwareUpdatesPackage = New-SCCMWmiInstance -Class SMS_SoftwareUpdatesPackage
		
		$SoftwareUpdatesPackage.Name = $Name
		$SoftwareUpdatesPackage.Description = $Description
		$SoftwareUpdatesPackage.PkgSourcePath = $PkgSourcePath
		$SoftwareUpdatesPackage.SourceSite = $SourceSite
		$SoftwareUpdatesPackage.PkgSourceFlag = $PkgSourceFlag
		
		[WMI] ($SoftwareUpdatesPackage.Put()).Path
	}
}

function Remove-SCCMSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage
	)
	
	Process
	{
		if ($Name)
		{
			$SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$Name'"
			
			if (-not $SoftwareUpdatePackage)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Package with name $Name"))
				return
			}
		}
		elseif ($SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdatesPackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
			return
		}
		
		Remove-SCCMSoftwareUpdatePackageFromDistributionPoint -SoftwareUpdatePackage $SoftwareUpdatePackage -AllDistributionPoints
		
		$SoftwareUpdatePackage.Delete()
	}
}

function Remove-SCCMPackageFromDistributionPoint
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DistributionPoint')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'AllDistributionPoints')]
		[String]$PackageID,
		
		[Parameter(Mandatory, ParameterSetName = 'DistributionPoint')]
		[String[]]$DistributionPoint,
		
		[Parameter(ParameterSetName = 'AllDistributionPoints')]
		[Switch]$AllDistributionPoints
	)
	
	Begin
	{
		if ($DistributionPoint)
		{
			$DistributionPointQuery = New-WmiQueryFormatting -Object $DistributionPoint -LeftOperand NALPath -CompareOperator like -PercentSign AtStartAndEnd
		}
	}
	
	Process
	{
		if ($DistributionPointQuery)
		{
			$DistributionPointPackages = Get-SCCMWmiObject -Class SMS_DistributionPoint -Filter "PackageID = '$PackageID' AND ($DistributionPointQuery)"
		}
		else
		{
			$DistributionPointPackages = Get-SCCMWmiObject -Class SMS_DistributionPoint -Filter "PackageID = '$PackageID'"
		}
		
        if ($DistributionPointPackages)
		{
            $DistributionPointPackages.Delete()
        }
	}
}

function Add-SCCMSoftwareUpdateToSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[Alias('CI_ID', 'Updates')]
		[UInt32[]]$Update,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9'),
		
		[Parameter(Mandatory, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackage')]
		[String]$RootFolder,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[Switch]$UpdateDistributionPoints
	)
	
	Process
	{
		if (-not $Content -or -not (Compare-Object $Update $LoadedUpdate))
		{
			$Content = Get-SCCMSoftwareUpdateCIToContent -Update $Update -ContentLocales $ContentLocales
			$LoadedUpdate = $Update
		}
		
		[void]$PSBoundParameters.Remove('Update')
		[void]$PSBoundParameters.Remove('ContentLocales')
		Add-SCCMCIContentFileToSoftwareUpdatePackage -Content $Content @PSBoundParameters
	}
}

function Add-SCCMCIContentFileToSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject[]]
		$Content,
		
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject]
		$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackage')]
		[String]$RootFolder,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[Switch]$UpdateDistributionPoints
	)
	
	Process
	{
		if ($Content.__Class -ne 'SMS_CIToContent')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $Content to be a WMI object of class SMS_CIToContent'))
			return
		}
		
		if ($SoftwareUpdatePackage -and $SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdatesPackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
			return
		}
		
		if ($Name -and $SoftwareUpdatePackage.Name -ne $Name)
		{
			$SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$Name'"
			
			if (-not $SoftwareUpdatePackage)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Software Update Package with name $Name not found"))
				return
			}
		}
		
        $sourceFolders = @()
		for ($i = 0; $i -lt $Content.Count; $i++)
		{
			$sourceFolders += "$RootFolder\$($Content[$i].ContentID)"
		}

        $SoftwareUpdatePackage.AddUpdateContent($Content.ContentID, $sourceFolders, $UpdateDistributionPoints)
	}
}

function Remove-SCCMSoftwareupdateFromSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[Alias('CI_ID', 'Updates')]
		[UInt32[]]$Update,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[String[]]$ContentLocales = @('Locale:0', 'Locale:9'),
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[Switch]$UpdateDistributionPoints,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[Switch]$DeleteSourceFiles = $true
	)
	
	Process
	{
		if (-not $Content -or -not (Compare-Object $Update $LoadedUpdate))
		{
			$Content = Get-SCCMSoftwareUpdateCIToContent -Update $Update -ContentLocales $ContentLocales
			$LoadedUpdate = $Update
		}

		[void]$PSBoundParameters.Remove('Update')
		[void]$PSBoundParameters.Remove('ContentLocales')
		Remove-SCCMCIContentFileFromSoftwareUpdatePackage -Content $Content @PSBoundParameters
	}
}

function Remove-SCCMCIContentFileFromSoftwareUpdatePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject[]]$Content,
		
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'SoftwareUpdatePackage')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackage')]
		[Switch]$UpdateDistributionPoints
	)
	
	Process
	{
		if ($Content.__Class -ne 'SMS_CIToContent')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $Content to be a WMI object of class SMS_CIToContent'))
			return
		}
		
		if ($SoftwareUpdatePackage -and $SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdatesPackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
			return
		}
		
		if ($Name -and $SoftwareUpdatePackage.Name -ne $Name)
		{
			$SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$Name'"
			
			if (-not $SoftwareUpdatePackage)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Software Update Package with name $Name not found"))
				return
			}
		}
		

        # Work around for when there are too many items in $Content, this was previously running out of memory with 1000 contents, so limiting it to 300
        $ValidContent = @()
        $tempContent = @()
        for ($i = 0; $i -lt $Content.Count; $i++)
        {
            $tempContent += $Content[$i]

            # When it gets to 300, process it and clear the array
            if ($tempContent.Count -eq 300)
            {
                $ContentQuery = New-WmiQueryFormatting -Object $tempContent.ContentID -LeftOperand ContentID
                $ValidContent += $ValidContent = Get-SCCMWmiObject -Query "SELECT ContentID FROM SMS_PackageToContent WHERE PackageID = '$($SoftwareUpdatePackage.PackageID)' and ($contentQuery)"
                $tempContent.Clear()
            }
        }		

        # If we have an array with less than 300 items, process it outside the for loop
        if ($tempContent.Count -gt 0)
        {
            $ContentQuery = New-WmiQueryFormatting -Object $tempContent.ContentID -LeftOperand ContentID
		    $ValidContent += Get-SCCMWmiObject -Query "SELECT ContentID FROM SMS_PackageToContent WHERE PackageID = '$($SoftwareUpdatePackage.PackageID)' and ($contentQuery)"
        }		

        if ($ValidContent)
        {
		$SoftwareUpdatePackage.RemoveContent($ValidContent.ContentID, $UpdateDistributionPoints)
		}
	}
}

function Add-SCCMSoftwareUpdatePackageToDistributionPoint
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'NameDistributionPoint')]
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'NameAllDistributionPoints')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ParameterSetName = 'NameDistributionPoint')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[ValidateNotNullOrEmpty()]
		[String[]]$DistributionPoint,
		
		[Parameter(Mandatory, ParameterSetName = 'NameAllDistributionPoints')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[switch]$AllDistributionPoints,
		
		[Parameter(ParameterSetName = 'NameDistributionPoint')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[Parameter(ParameterSetName = 'NameAllDistributionPoints')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[Switch]$ExcludeManagementPointDP,
		
		[Parameter(ParameterSetName = 'NameDistributionPoint')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[Parameter(ParameterSetName = 'NameAllDistributionPoints')]
		[Parameter(ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[String]$SiteCode = $Script:SiteCode
	)
	
	Begin
	{
		if ($DistributionPoint)
		{
			$DistributionPointQuery = New-WmiQueryFormatting -Object $DistributionPoint -LeftOperand NetworkOSPath -CompareOperator like -PercentSign AtStartAndEnd
			$Filter = "RoleName = 'SMS Distribution Point' AND ($DistributionPointQuery)"
		}
		else
		{
			$Filter = "RoleName = 'SMS Distribution Point'"
		}
		
		$NALPaths = (Get-SCCMWmiObject -Class SMS_SCI_SysResUse -Filter $Filter).NALPath
		
		if (-not $NALPaths)
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Unable to find the specified distribution point.'))
			return
		}
	}
	
	Process
	{
		if ($Name)
		{
			$SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$Name'"
			
			if (-not $SoftwareUpdatePackage)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Package with name $Name"))
				return
			}
		}
		elseif ($SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdatesPackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
			return
		}
		
		foreach ($NALPath in $NALPaths)
		{
			$SoftwareUpdatePackage.AddDistributionPoints($SiteCode, $NALPath)
		}
	}
}

function Remove-SCCMSoftwareUpdatePackageFromDistributionPoint
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'NameDistributionPoint')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'NameAllDistributionPoints')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[System.Management.ManagementObject]$SoftwareUpdatePackage,
		
		[Parameter(Mandatory, ParameterSetName = 'NameDistributionPoint')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackageDistributionPoint')]
		[ValidateNotNullOrEmpty()]
		[String[]]$DistributionPoint,
		
		[Parameter(Mandatory, ParameterSetName = 'NameAllDistributionPoints')]
		[Parameter(Mandatory, ParameterSetName = 'SoftwareUpdatePackageAllDistributionPoints')]
		[switch]$AllDistributionPoints
	)
	
	Process
	{
		if ($Name)
		{
			$SoftwareUpdatePackage = Get-SCCMSoftwareUpdatePackage -Filter "Name = '$Name'"
			
			if (-not $SoftwareUpdatePackage)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Package with name $Name"))
				return
			}
		}
		elseif ($SoftwareUpdatePackage.__Class -ne 'SMS_SoftwareUpdatesPackage')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdatesPackage to be a WMI object of class SMS_SoftwareUpdatesPackage'))
			return
		}
		
		[void]$PSBoundParameters.Remove('Name')
        [void]$PSBoundParameters.Remove('SoftwareUpdatePackage')
		Remove-SCCMPackageFromDistributionPoint -PackageID $SoftwareUpdatePackage.PackageID @PSBoundParameters
	}
}

function Get-SCCMCollection
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$Filter,
		
		[Parameter()]
		[Switch]$ExpandLazyProperties,
		
		[Parameter()]
		[String[]]$Property
	)
	
	End
	{
		Get-SCCMWmiObject -Class SMS_Collection @PSBoundParameters
	}
}

function Get-SCCMSoftwareUpdateDeployment
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$Filter,
		
		[Parameter()]
		[Switch]$ExpandLazyProperties,
		
		[Parameter()]
		[String[]]$Property
	)
	
	Process
	{
		Get-SCCMWmiObject -Class SMS_UpdatesAssignment @PSBoundParameters
	}
}

function New-SCCMSoftwareUpdateDeployment
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('DeploymentName')]
		[String]$AssignmentName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Name', 'CollectionName')]
		[String]$TargetCollectionName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[Alias('CI_ID', 'Updates')]
		[ValidateNotNullOrEmpty()]
		[Int[]]$AssignedCIs,
		
		[Parameter()]
		[ValidateSet('Apply', 'Detect')]
		[String]$AssignmentAction = 'Apply',
		
		[Parameter()]
		[Alias('Description')]
		[String]$AssignmentDescription,
		
		[Parameter()]
		[ValidateSet('Install', 'Uninstall')]
		[String]$DesiredConfigType = 'Install',
		
		[Parameter()]
		[Alias('DisableMomAlertsDuringInstall')]
		[Switch]$DisableMomAlerts,
		
		# DPLocality parameters
		[Parameter()]
		[Switch]$AllowLocalDistributionPoint = $true,
		
		[Parameter()]
		[ValidateSet('NoInstall', 'RemoteDistributionPoint')]
		[String]$OnSlowOrUnreliableNetwork = 'NoInstall',
		
		[Parameter()]
		[ValidateSet('NoInstall', 'RemoteDistributionPoint')]
		[String]$OnNoContentPreferredDistributionPoint = 'RemoteDistributionPoint',
		
		[Parameter()]
		[Switch]$AllowDownloadFromMicrosoftUpdate,
		
		[Parameter()]
		[Switch]$AllowUseMeteredNetwork,
		# End DPLocality Parameters
		
		[Parameter()]
		[Switch]$Enabled = $true,
		
		[Parameter()]
		[Alias('Deadline', 'DeadlineDate')]
		[DateTime]$EnforcementDeadline,
		
		[Parameter()]
		[ValidateNotNull()]
		[Int]$LocaleId = 1033,
		
		[Parameter()]
		[Alias('AllowInstallOutsideMaintenanceWindows')]
		[Switch]$OverrideServiceWindows,
		
		[Parameter()]
		[Switch]$RaiseMomAlertsOnFailure,
		
		[Parameter()]
		[Switch]$RandomizationEnabled,
		
		[Parameter()]
		[Alias('AllowRestartOutsideMaintanceWindows')]
		[Switch]$RebootOutsideOfServiceWindows,
		
		[Parameter()]
		[Alias('Available', 'AvailableDate')]
		[ValidateNotNull()]
		[DateTime]$StartTime = [DateTime]::Now,
		
		[Parameter()]
		[Alias('VerbosityLevel')]
		[ValidateSet('AllMessages', 'OnlyErrorMessages', 'OnlySuccessAndErrorMessages', 'Disabled')]
		[String]$StateMessageVerbosity = 'OnlySuccessAndErrorMessages',
		
		# SuppressReboot parameter
		[Parameter()]
		[Switch]$AllowWorkstationRestart,
		
		[Parameter()]
		[Switch]$AllowServerRestart,
		# End SuppressReboot parameter
		
		[Parameter()]
		[Switch]$UseBranchCache,
		
		[Parameter()]
		[Switch]$UseGMTTimes,
		
		[Parameter()]
		[ValidateSet('DisplayAll', 'DisplaySoftwareCenterOnly', 'HideAll')]
		[Switch]$UserNotification = 'DisplaySoftwareCenterOnly',
		
		[Parameter()]
		[Switch]$WoLEnabled
	)
	
	Process
	{
		$Collection = Get-SCCMCollection -Filter "Name = '$TargetCollectionName'"
		
		if (-not $Collection)
		{
			$PSCmdlet.WriteError((New-ErrorRecord "Unable to find collection with name $TargetCollectionName"))
			return
		}
		
		# Weed out non-existant CIs to prevent WMI errors later...
		$Filter = New-WmiQueryFormatting -Object $AssignedCIs -LeftOperand CI_ID
		
		$AssignedCIs = (Get-SCCMSoftwareUpdate -Filter $Filter).CI_ID
		
		if (-not $AssignedCIs)
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Unable to match any value provided in $AssignCIs to existing CIs'))
			return
		}
		
		# Ended validation, let's start creating the object and populating it's properties
		$Deployment = ([WMIClass] "\\$Script:ManagementPoint\Root\SMS\Site_$($Script:SiteCode):SMS_UpdatesAssignment").CreateInstance()
		
		$Deployment.AssignedCIs = $AssignedCIs
		$Deployment.AssignmentDescription = $AssignmentDescription
		$Deployment.AssignmentName = $AssignmentName
		$Deployment.DisableMomAlerts = $DisableMomAlerts
		$Deployment.Enable = $Enabled
		$Deployment.LocaleId = $LocaleId
		$Deployment.OverrideServiceWindows = $OverrideServiceWindows
		$Deployment.RaiseMomAlertsOnFailure = $RaiseMomAlertsOnFailure
		$Deployment.RandomizationEnabled = $RandomizationEnabled
		$Deployment.RebootOutsideOfServiceWindows = $RebootOutsideOfServiceWindows
		$Deployment.StartTime = "$($StartTime.ToString('yyyyMMddHHmmss')).000000+***"
		$Deployment.UseBranchCache = $UseBranchCache
		$Deployment.UseGMTTimes = $UseGMTTimes
		$Deployment.WoLEnabled = $WoLEnabled
		
		if ($AssignmentAction -eq 'Apply')
		{
			$Deployment.AssignmentAction = 2
		}
		else
		{
			$Deployment.AssignmentAction = 1
		}
		
		if ($DesiredConfigType -eq 'Install')
		{
			$Deployment.DesiredConfigType = 1
		}
		else
		{
			$Deployment.DesiredConfigType = 2
		}
		
		#region DPLocality
		if ($AllowLocalDistributionPoint)
		{
			$DPLocality = 16 # 2^4, too lazy to use [Math]
		}
		
		if ($OnSlowOrUnreliableNetwork -eq 'RemoteDistributionPoint')
		{
			$DPLocality += 64 # 2^6
		}
		
		if ($OnNoContentPreferredDistributionPoint -eq 'NoInstall')
		{
			$DPLocality += 131072 # 2^17
		}
		
		if ($AllowDownloadFromMicrosoftUpdate)
		{
			$DPLocality += 262144 # 2^18
		}
		
		if ($AllowUseMeteredNetwork)
		{
			$DPLocality += 524288 # 2^19
		}
		
		$Deployment.DPLocality = $DPLocality
		#endregion
		
		if ($EnforcementDeadline)
		{
			$Deployment.EnforcementDeadline = "$($EnforcementDeadline.ToString('yyyyMMddHHmmss')).000000+***"
		}
		
		switch ($StateMessageVerbosity)
		{
			'AllMessages' { $Deployment.StateMessageVerbosity = 10 }
			'OnlyErrorMessages' { $Deployment.StateMessageVerbosity = 1 }
			'OnlySuccessAndErrorMessages' { $Deployment.StateMessageVerbosity = 5 }
			'Disabled' { $Deployment.StateMessageVerbosity = 0 }
		}
		
		if (-not $AllowWorkstationRestart)
		{
			$Deployment.SuppressReboot += 1
		}
		
		if (-not $AllowServerRestart)
		{
			$Deployment.SuppressReboot += 2
		}
		
		switch ($UserNotification)
		{
			'DisplayAll' { $Deployment.UserUIExperience = $true; $Deployment.NotifyUser = $true }
			'DisplaySoftwareCenterOnly' { $Deployment.UserUIExperience = $true; $Deployment.NotifyUser = $false }
			'HideAll' { $Deployment.UserUIExperience = $false; $Deployment.NotifyUser = $false }
		}
		
		$Deployment.Put()
	}
}

function Remove-SCCMSoftwareUpdateDeployment
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateDeployment')]
		[System.Management.ManagementObject]$SoftwareUpdateDeployment
	)
	
	Process
	{
		if ($Name)
		{
			$SoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -Filter "AssignmentName = '$Name'"
			
			if (-not $SoftwareUpdateDeployment)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Deployment with AssignmentName $Name"))
				return
			}
		}
		elseif ($SoftwareUpdateDeployment.__Class -ne 'SMS_UpdatesAssignment')
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateDeployment to be a WMI object of class SMS_UpdatesAssignment'))
			return
		}
		
		$SoftwareUpdateDeployment.Delete()
	}
}

function Add-SCCMSoftwareUpdateToSoftwareUpdateDeployment
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateDeployment')]
		[System.Management.ManagementObject]
		$SoftwareUpdateDeployment,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateDeployment')]
		[Alias('CI_ID', 'Updates', 'AssignedCIs')]
		[Int[]]$Update
	)
	
	Process
	{
		if ($Name -and $LoadedSoftwareUpdateDeployment.AssignmentName -ne $Name)
		{
			if ($LoadedSoftwareUpdateDeployment)
			{
				[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
			}
			
			$LoadedSoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -Filter "AssignmentName = '$Name'"
			
			if (-not $LoadedSoftwareUpdateDeployment)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Deployment with AssignmentName $Name"))
				return
			}
		}
		elseif ($SoftwareUpdateDeployment -and ($LoadedSoftwareUpdateDeployment.AssignmentName -ne $SoftwareUpdateDeployment.AssignmentName -or -not $LoadedSoftwareUpdateDeployment))
		{
			if ($LoadedSoftwareUpdateDeployment)
			{
				[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
			}
		
			if ($SoftwareUpdateDeployment.__Class -ne 'SMS_UpdatesAssignment')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateDeployment to be a WMI object of class SMS_UpdatesAssignment'))
				return
			}
			
			$LoadedSoftwareUpdateDeployment = $SoftwareUpdateDeployment
		}
		
		$LoadedSoftwareUpdateDeployment.AssignedCIs += $Update
	}
	End
	{
		[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
	}
}

function Remove-SCCMSoftwareUpdateFromSoftwareUpdateDeployment
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[String]$Name,
		
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateDeployment')]
		[System.Management.ManagementObject]$SoftwareUpdateDeployment,
	
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SoftwareUpdateDeployment')]
		[Alias('CI_ID', 'Updates', 'AssignedCIs')]
		[Int[]]$Update
	)
	
	Process
	{
		if ($Name -and $LoadedSoftwareUpdateDeployment.AssignmentName -ne $Name)
		{
			if ($LoadedSoftwareUpdateDeployment)
			{
				$LoadedSoftwareUpdateDeployment.AssignedCIs = $AssignedCIs.ToArray()
				[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
			}
			
			$LoadedSoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -Filter "AssignmentName = '$Name'"
			
			if (-not $LoadedSoftwareUpdateDeployment)
			{
				$PSCmdlet.WriteError((New-ErrorRecord "Unable to find a Software Update Deployment with AssignmentName $Name"))
				return
			}
		}
		elseif ($SoftwareUpdateDeployment -and ($LoadedSoftwareUpdateDeployment.AssignmentName -ne $SoftwareUpdateDeployment.AssignmentName -or -not $LoadedSoftwareUpdateDeployment))
		{
			if ($LoadedSoftwareUpdateDeployment)
			{
				$LoadedSoftwareUpdateDeployment.AssignedCIs = $AssignedCIs.ToArray()
				[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
			}
			
			if ($SoftwareUpdateDeployment.__Class -ne 'SMS_UpdatesAssignment')
			{
				$PSCmdlet.WriteError((New-ErrorRecord 'Expected $SoftwareUpdateDeployment to be a WMI object of class SMS_UpdatesAssignment'))
				return
			}
			
			$LoadedSoftwareUpdateDeployment = $SoftwareUpdateDeployment
		}
		
		$AssignedCIs = [System.Collections.ArrayList]$LoadedSoftwareUpdateDeployment.AssignedCIs
		foreach ($singleUpdate in $Update)
		{
			$AssignedCIs.Remove($singleUpdate)
		}
	}
	End
	{
		$LoadedSoftwareUpdateDeployment.AssignedCIs = $AssignedCIs.ToArray()
		[wmi] ($LoadedSoftwareUpdateDeployment.Put()).Path
	}
}

$ServerInfo = Get-SCCMServerInfo
$Script:SiteCode = $ServerInfo.SiteCode
$Script:ManagementPoint = $ServerInfo.ManagementPoint
