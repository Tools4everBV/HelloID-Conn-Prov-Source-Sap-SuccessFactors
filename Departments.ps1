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

function Invoke-SAPSFRestMethod { 
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]  
        [string]
        $Url,
     
        [string]
        $Proxy,

        [System.Collections.Hashtable]
        $headers,

        [int]
        $BatchSize = 250
    )
    try {       
        $offset = 0       
        [System.Collections.Generic.List[PSCustomObject]]$returnValue = @() 
        while ($returnValue.count -eq $offset) {    
          
            # Make sure function works with and wihtout query parameters in the Url
            if ($Url.Contains("?")) {
                $urlWithOffSet = $Url + "&`$skip=$offset&`$top=$BatchSize" 
            } else {
                $urlWithOffSet = $Url + "?`$skip=$offset&`$top=$BatchSize" 
            }
            
            $rawResponse = Invoke-RestMethod -Uri $urlWithOffSet.ToString() -Method GET -ContentType "application/json" -Headers $headers

            if ($rawResponse.d.results.count -gt 0) {
                [System.Collections.Generic.List[PSCustomObject]]$partialResult = $rawResponse.d.results    
            } else {
                [System.Collections.Generic.List[PSCustomObject]]$partialResult = $rawResponse.d
            }  
            $returnValue.AddRange($partialResult)
            $offset += $BatchSize
        }             
    } catch {
        $returnValue = [PSCustomObject]@{
            Error = "Could not Get SAPSuccessFactorsList, message: $($_.Exception.Message)"
        } 
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
$url = $config.url.trim("/")

$resultDeparments = Invoke-SAPSFRestMethod -Url "$url/FOBusinessUnit"  -headers  $headers


$departments = $resultDeparments | Select-Object @{n = "ExternalId"; e = { $_.externalCode } }, @{n = "Displayname"; e = { $_.description_en_US } }, name, headOfUnit
Write-Verbose -Verbose "Department import completed";

Write-Output $departments | ConvertTo-Json -Depth 10