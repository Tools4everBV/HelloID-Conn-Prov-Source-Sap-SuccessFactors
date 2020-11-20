function New-BasicBase64 {
    [CmdletBinding()]
    param(
        [string]
        $UserName,

        [string]
        $PlainPassword       
    )
    $pair = "$($UserName):$($plainPassword)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    return ("Basic $encodedCreds")
}

function Get-SAPSuccessFactorsList{ 
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]  
        [string]
        $Url,
     
        [string]
        $Proxy,

        [System.Collections.Hashtable]
        $headers
    )
    try {
        $webResponse = Invoke-RestMethod -Uri  $Url -Method GET -ContentType "application/json"  -Headers $headers
        if($webResponse.d.results.count -gt 0) {
            $returnValue = $webResponse.d.results    
        }else{
            $returnValue = $webResponse.d
        }
      
           
    } catch {
        
            throw "Could not Get SAPSuccessFactorsList, message: $($_.Exception.Message)"
      
    }
    return $returnValue
}

function Format-PickListLabel($ResultLabels) {
    $labelList = @{ }
    foreach ($label in $resultLabels.picklistOptions.results) {
        $labelList += @{
            ($label.picklistLabels.results | where { $_.locale -eq "en_US" }).label = $label.id  
        } 
    }
    return $labelList
}

#Tools4ever environment
$config = ConvertFrom-Json $configuration
$Headers = @{
    APIKey = $config.APIKey
    accept = "application/json"
}	
$url =  $config.url

$resultDeparments = Get-SAPSuccessFactorsList -Url "$url/FOBusinessUnit"  -Proxy  $proxy -headers  $headers


 $departments = $resultDeparments  | Select-Object @{n="ExternalId";e={$_.externalCode}}, @{n="Displayname";e={$_.description_en_US}}, name, headOfUnit
Write-Verbose -Verbose "Department import completed";

Write-Output $departments | ConvertTo-Json