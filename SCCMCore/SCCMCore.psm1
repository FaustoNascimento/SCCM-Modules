function Get-SCCMAdInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$DomainDN = ([adsi]"").distinguishedName,
		
		[Parameter()]
		[String]$Filter = '(ObjectClass=*)'
	)
	
	End
	{
		$SearchRoot = [adsi] "LDAP://CN=System Management,CN=System,$DomainDN"
		$AdSearcher = [adsisearcher]$Filter
		$AdSearcher.SearchRoot = $SearchRoot
		$AdSearcher.FindAll()
	}
}

function Get-SCCMClientSiteCode
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[Alias('IPAddress', 'CN')]
		[String]$ComputerName = $env:COMPUTERNAME
	)
	
	Process
	{
		if ($ComputerName -ne $env:COMPUTERNAME -and -not (Test-Connection -ComputerName $ComputerName -Count 1))
		{
			$PSCmdlet.WriteError((New-ErrorRecord "Unable to connect to '$ComputerName'"))
			return
		}
		
		if (-not (Get-WmiObject -ComputerName $ComputerName -Namespace ROOT -Class __Namespace -Filter 'Name = "CCM"'))
		{
			$PSCmdlet.WriteError((New-ErrorRecord "Unable to find CCM namespace in computer $ComputerName or access denied."))
			return
		}
		
		(Invoke-WmiMethod -Namespace ROOT/CCM -Class SMS_Client -Name GetAssignedSite).sSiteCode
	}
}

function Set-SCCMServerInfo
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[String]$SiteCode = (Get-SCCMClientSiteCode -ErrorAction SilentlyContinue)
	)
	
	End
	{
		if (-not $SiteCode)
		{
			Write-Verbose 'Site code not specified and unable to retrieve it from local client, attempting to retrieving it from Active Directory'
			$Filter = '(ObjectClass=mSSMSManagementPoint)'
		}
		else
		{
			Write-Verbose 'Retrieving Management Point from Active Directory'
			$Filter = "&(ObjectClass=mSSMSManagementPoint)(mssmssitecode=$SiteCode)"
		}
		
		$results = Get-SCCMAdInfo -Filter $Filter -ErrorAction Stop
		
		if ($results.Count -gt 1)
		{
			$PSCmdlet.WriteError((New-ErrorRecord 'More than one Management Point with specified site code found, use -SiteCode parameter to specify which to connect to.'))
		}
		
		$Script:SiteCode = $results.Properties['mssmssitecode']
		$Script:ManagementPoint = $results.Properties['mssmsmpname']
	}
}

function Get-SCCMServerInfo
{
	[CmdletBinding()]
	param
	(
	)
	
	End
	{
		$ServerInfo = @{ }
        $ServerInfo.ManagementPoint = $Script:ManagementPoint
        $ServerInfo.SiteCode = $Script:SiteCode

        New-Object -TypeName PSObject -Property $ServerInfo
	}
}

function Get-SCCMWmiObject
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Class')]
		[Alias('__Class')]
		[String]$Class,
		
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Class')]
		[String]$Filter,
		
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Class')]
		[String[]]$Property,
		
		[Parameter(Mandatory, ParameterSetName = 'Query')]
		[String]$Query,
		
		[Parameter(ParameterSetName = 'Class')]
		[Parameter(ParameterSetName = 'Query')]
		[Switch]$ExpandLazyProperties
	)
	
	Begin
	{
		$Namespace = "root\SMS\Site_$Script:SiteCode"
		$ComputerName = $Script:ManagementPoint
	}
	
	Process
	{
		[void]$PSBoundParameters.Remove('ExpandLazyProperties')
		$results = Get-WmiObject @PSBoundParameters -Namespace $Namespace -ComputerName $ComputerName
		
		if ($ExpandLazyProperties)
		{
			foreach ($result in $results)
			{
				[WMI] ($result).__Path
			}
		}
		else
		{
			$results
		}
	}
}

function Get-SCCMWmiClass
{
	[cmdletbinding()]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('__Class')]
		[string]$Class
	)
	Process
	{
		[WmiClass] "\\$Script:ManagementPoint\root\SMS\Site_$Script:SiteCode`:$Class"
	}
}

function New-SCCMWmiInstance
{
	[cmdletbinding()]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('__Class')]
		[string]$Class
	)
	
	Process
	{
		(Get-SCCMWmiClass -Class $Class).CreateInstance()
	}
}

function New-SCCMLocalizedProperties
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[Alias('LocalizedDisplayName')]
		[String]$DisplayName,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('LocalizedDescription')]
		[String]$Description,
		
		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('LocalizedPropertyLocaleID')]
		[Int]$LocaleID = 1033
	)
	
	Process
	{
		$LocalizedPropertiesInstance = New-SCCMWmiInstance -Class SMS_CI_LocalizedProperties
		$LocalizedPropertiesInstance.DisplayName = $DisplayName
		$LocalizedPropertiesInstance.LocaleID = $LocaleID
		$LocalizedPropertiesInstance.Description = $Description
		
		$LocalizedPropertiesInstance
	}
}

function New-WmiQueryFormatting
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[Object[]]
		$Object,
		
		[Parameter(Mandatory)]
		[String]$LeftOperand,
		
		[Parameter()]
		[ValidateSet('OR', 'AND')]
		[String]$ConnectOperator = 'OR',
		
		[Parameter()]
		[ValidateSet('Equals', 'NotEquals', 'Like')]
		[String]$CompareOperator = 'Equals',
		
		[Parameter()]
		[ValidateSet('AtStart', 'AtEnd', 'AtStartAndEnd')]
		[String]$PercentSign
	)
	
	End
	{
		for ($i = 0; $i -lt $Object.Count; $i++)
		{
			$RightOperator = $Object[$i]
			
			switch ($CompareOperator)
			{
				'Equals' 	{ $Operator = '=' }
				'NotEquals'	{ $Operator = '!=' }
				'Like' 		{ $Operator = 'like' } # Not needed, kept for visibility
			}
			
			if ($CompareOperator -eq 'Like')
			{
				switch ($PercentSign)
				{
					'AtStart' 		{ $RightOperator = "%$RightOperator" }
					'AtEnd'   		{ $RightOperator = "$RightOperator%" }
					'AtStartAndEnd'	{ $RightOperator = "%$RightOperator%" }
				}
			}
			
			$Query += "$LeftOperand $Operator '$($RightOperator)'"
			
			if ($Object.Count - 1 -gt $i)
			{
				$Query += " $ConnectOperator "
			}
		}
		
		$Query
	}
}

function New-ErrorRecord
{
	[CmdletBinding(DefaultParameterSetName = 'ErrorMessageSet')]
	param
	(
		[Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'ErrorMessageSet')]
		[String]$ErrorMessage,
		
		[Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'ExceptionSet')]
		[System.Exception]$Exception,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, ParameterSetName = 'ErrorMessageSet')]
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, ParameterSetName = 'ExceptionSet')]
		[System.Management.Automation.ErrorCategory]$ErrorCategory = [System.Management.Automation.ErrorCategory]::NotSpecified,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 2, ParameterSetName = 'ErrorMessageSet')]
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 2, ParameterSetName = 'ExceptionSet')]
		[String]$ErrorId,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 3, ParameterSetName = 'ErrorMessageSet')]
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 3, ParameterSetName = 'ExceptionSet')]
		[Object]
		$TargetObject
	)
	
	End
	{
		if (!$Exception)
		{
			$Exception = New-Object System.Exception $ErrorMessage
		}
		
		New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $ErrorCategory, $TargetObject
	}
}

Set-SCCMServerInfo
