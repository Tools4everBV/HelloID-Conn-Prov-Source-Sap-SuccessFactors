#####################################################
# HelloID-Conn-Prov-SOURCE-SAP-SuccessFactors-Persons
# 
# Version: 1.0.2
#####################################################
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
    Write-Output ("Basic $encodedCreds")
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
        [System.Collections.Generic.List[Object]]$returnValue = @() 
        while ($returnValue.count -eq $offset) {    
          
            #Make sure function works with and wihtout query parameters in the Url
            if ($Url.Contains("?")) {
                $urlWithOffSet = $Url + "&`$skip=$offset&`$top=$BatchSize" 
            } else {
                $urlWithOffSet = $Url + "?`$skip=$offset&`$top=$BatchSize" 
            }
            
            $rawResponse = Invoke-RestMethod -Uri $urlWithOffSet.ToString() -Method GET -ContentType "application/json" -Headers $headers

            if ($rawResponse.d.results.count -gt 0) {
                $returnValue.AddRange([System.Collections.Generic.List[PSCustomObject]]$rawResponse.d.results)    
            } else {
                $returnValue.AddRange([System.Collections.Generic.List[PSCustomObject]]$rawResponse.d)
            }   
            $offset += $BatchSize
        }             
    } catch {
        if ($_.ErrorDetails) {
            $errorExceptionDetails = $_.ErrorDetails
        }
        throw "Could not Invoke-SAPSFRestMethod with url: '$Url', message: $($_.Exception.Message), $errorExceptionDetails".Trim(" ")        
    }
    Write-Output $returnValue
}

function Format-PickListLabel($ResultLabels) {
    $labelList = @{ }
    foreach ($label in $resultLabels.picklistOptions.results) {
        $labelList += @{
            ($label.picklistLabels.results | Where-Object { $_.locale -eq "en_US" }).label = $label.id  
        } 
    }
    Write-Output $labelList
}

# Configuration
$config = ConvertFrom-Json $configuration 
if ($config.UseUsernamePassword) {
    $Headers = @{
        Authorization = (New-BasicBase64 -UserName $config.userName -PlainPassword $config.password )
        accept        = "application/json"
    }	
} else {
    $Headers = @{
        APIKey = $config.APIKey
        accept = "application/json"
    }	
}
$url = $config.url.trim("/")

$InformationPreference = "continue"

try {
#region Person
    $resultPerPerson = Invoke-SAPSFRestMethod -Url "$url/PerPerson"   -headers  $headers
    $resultPerPersonal = Invoke-SAPSFRestMethod -Url "$url/PerPersonal"  -headers  $headers
    $resultPerPhone = Invoke-SAPSFRestMethod -Url "$url/PerPhone"  -headers  $headers
    $resultPerEmail = Invoke-SAPSFRestMethod -Url "$url/PerEmail" -headers  $headers   ## No addresses added yet  

    # Groups Result list to Make the lookups below way faster! (Create a index on a List)
    $personalGrouped = $resultPerPersonal | Group-Object -Property personIdExternal -AsHashTable
    $PerPhoneGrouped = $resultPerPhone | Group-Object -Property personIdExternal -AsHashTable
    $PerEmailGrouped = $resultPerEmail | Group-Object -Property personIdExternal -AsHashTable

    # # TODO AS_OF_DATE To retreive future PersonDetails and Employment Details     
    #$resultPerPersonal = Invoke-SAPSFRestMethod -Url "$url/PerPersonal?asOfDate=$asOfDate"  -headers  $headers
    #$resultEmpJob = Invoke-SAPSFRestMethod -Url "$url/EmpJob?asOfDate=$asOfDate -headers  $headers
#endregion Person

#region Employment
    $resultEmpEmployment = Invoke-SAPSFRestMethod -Url "$url/EmpEmployment"  -headers  $headers
    $resultEmpJob = Invoke-SAPSFRestMethod -Url "$url/EmpJob" -headers  $headers
    
    # Select only the meaningfull properties of the raw result  (To decreacse the size of the objects)
    $resultEmpEmployment = $resultEmpEmployment | Select-Object personIdExternal , userId, @{name = "employmentStartDate"; expression = { $_.startDate } }, @{name = "employmentEndDate"; expression = { $_.endDate } }
    $resultEmpJob = $resultEmpJob | Select-Object userId, startDate, endDate, Jobcode, department, division, costCenter, emplStatus, countryOfCompany, ManagerID, businessUnit, jobTitle, standaardHours, position, company, location, seqNumber
    $EmpJobGrouped = $resultEmpJob | Group-Object -Property UserID -AsHashTable

    #Job Employments are the function and worker details of the employment of a person. The JobDetails are actuale set when the person start working. 
    #Left Join Employments Result with the Job Employments
    $employmentsWithoutAJob = [System.Collections.Generic.List[psobject]]@()
    for ($i = 0; $i -lt $resultEmpEmployment.Count; $i++) {
        try {
            $employmentJobHash = @{ }
            ($EmpJobGrouped[$resultEmpEmployment[$i].userId] | Select-Object -first 1).psobject.properties | ForEach-Object { $employmentJobHash[$_.Name] = $_.Value }    
            $resultEmpEmployment[$i] | Add-Member -NotePropertyMembers $employmentJobHash -Force
        } catch {
            $employmentsWithoutAJob.Add($resultEmpEmployment[$i])
        } 
    }
    $EmpEmploymentGrouped = $resultEmpEmployment | Group-Object -Property personIdExternal -AsHashTable
    # Overview
    Write-information ("ResultPerPerson:".padright(40) + $resultPerPerson.count)
    Write-information ("ResultPerPersonal:".padright(40) + $resultPerPersonal.count)
    Write-information ("ResultPerPhone:".padright(40) + $resultPerPhone.count)
    Write-information ("ResultPerEmail:".padright(40) + $resultPerEmail.count)
    Write-information ("ResultEmpEmployment:".padright(40) + $resultEmpEmployment.count)
    Write-information ("ResultEmpJob:".padright(40) + $resultEmpJob.count)
    write-information ("Employments without Job Details:".PadRight(40) + $($employmentsWithoutAJob.count))
#endregion Employment

#region Additional Lists
    ## Email Type List:
    $resultEmailLabels = Invoke-SAPSFRestMethod -Url "$url/Picklist('ecEmailType')?`$expand=picklistOptions/picklistLabels" -headers  $headers
    $resultPhoneLabels = Invoke-SAPSFRestMethod -Url "$url/Picklist('ecPhoneType')?`$expand=picklistOptions/picklistLabels"  -headers  $headers
    $phoneLabels = Format-PickListLabel -ResultLabels $resultPhoneLabels 
    $emailLabels = Format-PickListLabel -ResultLabels $resultEmailLabels

    ## CompnayInfo
    $companyInfo = Invoke-SAPSFRestMethod -Url "$url/FOCompany" -headers  $headers
    $companyInfoGrouped = $companyInfo | Group-Object -Property "externalCode" -AsHashTable
  
    ## CostCenterInfo
    $costCenter = Invoke-SAPSFRestMethod -Url "$url/FOCostCenter" -headers  $headers
    $costCenterGrouped = $costCenter | Group-Object -Property "externalCode" -AsHashTable

#endregion Additional Lists
} catch {
    throw ($_.exception.message)
}

try {
#region HelloID
    ## Creating Person + contract Object For HelloID Incl Mappping 
    #Person Section
    $persons = [System.Collections.Generic.List[PscustomObject]]::new() 
    foreach ($person in $resultPerPerson) {
        try {      
            $id = $person.personIdExternal   #used between person endpoint 
            $personObject = [PscustomObject]@{
                ExternalId    = $id
                PersonId      = $person.personId
                DisplayName   = $personalGrouped[$id].firstName + " " + $personalGrouped[$id].lastName
                FirstName     = $personalGrouped[$id].firstName
                LastName      = $personalGrouped[$id].lastName
                Initials      = $personalGrouped[$id].initials
                BusinessEmail = ($PerEmailGrouped[$id] | Where-Object { $_.emailType -eq $emailLabels["Business"] }).emailAddress
                PrivateEmail  = ($PerEmailGrouped[$id] | Where-Object { $_.PhoneType -eq $emailLabels["Personal"] }).emailAddress
                BusinessPhone = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Business"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                MobilePhone   = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Home"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                CellPhone     = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Cell"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                Convention    = "B";
                Gender        = $personalGrouped[$id].gender
                Contracts     = [System.Collections.Generic.List[PscustomObject]]::new()
            }

            #Contract Section 
            [array]$contracts = $null
            [array]$contracts = $EmpEmploymentGrouped[$id]
            if ($contracts.count -gt 0) {
                foreach ($c in $contracts) {
                    if (-not [string]::IsNullOrEmpty($c.company)) {
                        $c | Add-Member -MemberType NoteProperty -Name "CompanyName" -Value $companyInfoGrouped[$c.company].description_localized
                    }

                    if (-not [string]::IsNullOrEmpty($c.costCenter)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "CostCenterName" -Value $costCenterGrouped[$c.costCenter].description_localized
                    }
                    $personObject.Contracts.Add($c)

                }    
            }        
            $persons.Add($personObject)
        } catch {
            Write-Warning ($_.exception.message)
        }
    }
} catch {
    throw ($_.exception.message)
}
#endregion HelloID

foreach ($person in $persons) {
    Write-Output $person | ConvertTo-json -Depth 10
}

Write-Verbose -Verbose "Person import completed";