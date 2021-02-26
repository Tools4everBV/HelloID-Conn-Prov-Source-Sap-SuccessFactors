#####################################################
# HelloID-Conn-Prov-SOURCE-SAP-SuccessFactors-Persons
# 
# Version: 1.1.0
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
            # Use the following code with using on-premises, because a bug in Powershell 5.1 and lower with RestMethods:
            # } elseif ($_.Exception.Response) {
            #     $result = $_.Exception.Response.GetResponseStream()
            #     $reader = New-Object System.IO.StreamReader($result)
            #     $responseReader = $reader.ReadToEnd()
            #     $errorExceptionDetails = $responseReader #| ConvertFrom-Json
            #     $reader.Dispose()
            # }
        }
        # Write-Verbose -verbose  ("Could not Invoke-SAPSFRestMethod with url: '$Url', message: $($_.Exception.Message), $errorExceptionDetails".Trim(" "))
        throw ("Could not Invoke-SAPSFRestMethod with url: '$Url', message: $($_.Exception.Message), $errorExceptionDetails".Trim(" "))
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
    $resultPerPerson = Invoke-SAPSFRestMethod -Url "$url/PerPerson"     -headers  $headers     
    #$resultPerPersonal = Invoke-SAPSFRestMethod -Url "$url/PerPersonal"  -headers  $headers    
    $resultPerPersonal = Invoke-SAPSFRestMethod -Url "$url/PerPersonal?`$expand=personNav"  -headers  $headers

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
    $resultEmpEmploymentRaw = Invoke-SAPSFRestMethod -Url "$url/EmpEmployment"  -headers  $headers
    
    #select only what you need, because of the memory usage of the reponse of this endpoint. The default set has a very large number of properties, Feel free to modify your desired properties
    $resultEmpJobRaw = Invoke-SAPSFRestMethod -Url "$url/EmpJob?`$select=userId,jobCode,department,division,costCenter,emplStatus,countryOfCompany,managerId,businessUnit,jobTitle,company,location,seqNumber" -headers  $headers

    # Select only the meaningfull properties of the raw result  (To decreacse the size of the objects)
    $resultEmpEmployment = $resultEmpEmploymentRaw | Select-Object personIdExternal , userId, @{name = "employmentStartDate"; expression = { $_.originalStartDate } }, @{name = "employmentEndDate"; expression = { $_.lastDateWorked } } #RN: originalstartdate + lastdateworked
    $resultEmpJob = $resultEmpJobRaw | Select-Object userId, startDate, endDate, Jobcode, department, division, costCenter, emplStatus, countryOfCompany, ManagerID, businessUnit, jobTitle, standaardHours, position, company, location, seqNumber
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
    $resultPrefixlabels = Invoke-SAPSFRestMethod -Url "$url/Picklist('prefix_cust')?`$expand=picklistOptions/picklistLabels"  -headers  $headers
    $phoneLabels = Format-PickListLabel -ResultLabels $resultPhoneLabels 
    $emailLabels = Format-PickListLabel -ResultLabels $resultEmailLabels
    $PrefixLabels = $resultPrefixlabels.picklistOptions.results.picklistLabels.results | where-object locale -eq "en_US" | select-object -property optionId, label


    ## CompnayInfo
    $companyInfo = Invoke-SAPSFRestMethod -Url "$url/FOCompany" -headers  $headers
    $companyInfoGrouped = $companyInfo | Group-Object -Property "externalCode" -AsHashTable
  
    ## CostCenterInfo
    $costCenter = Invoke-SAPSFRestMethod -Url "$url/FOCostCenter" -headers  $headers
    $costCenterGrouped = $costCenter | Group-Object -Property "externalCode" -AsHashTable

    #locationInfo
    $location = Invoke-SAPSFRestMethod -Url "$url/FOLocation" -headers  $headers
    $locationGrouped = $location | Group-Object -Property "externalCode" -AsHashTable

    #DivisionInfo
    $division = Invoke-SAPSFRestMethod -Url "$url/FODivision" -headers  $headers
    $divisionGrouped = $division | Group-Object -Property "externalCode" -AsHashTable    

    #DepartmentInfo
    $department = Invoke-SAPSFRestMethod -Url "$url/FODepartment" -headers  $headers
    $departmentGrouped = $department | Group-Object -Property "externalCode" -AsHashTable  
    
    #businessunitInfo
    $BusinessUnit = Invoke-SAPSFRestMethod -Url "$url/FOBusinessUnit" -headers  $headers
    $BusinessUnitGrouped = $BusinessUnit | Group-Object -Property "externalCode" -AsHashTable 

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

            $middlename = ($PrefixLabels | where-object optionId -eq $($personalGrouped[$id].middleName)).label
            If ($null -eq $middlename) {
                $middlename = $personalGrouped[$id].middleName
            }

            $middleNamePartner = ($PrefixLabels | where-object optionId -eq $($personalGrouped[$id].partnerNamePrefix)).label
            If ($null -eq $middleNamePartner) {
                $middleNamePartner = $personalGrouped[$id].partnerNamePrefix
            }
            
            $personObject = [PscustomObject]@{
                ExternalId           = $id
                PersonId             = $person.personId
                DisplayName          = $personalGrouped[$id].formalName
                Initials             = $personalGrouped[$id].initials
                FirstName            = $personalGrouped[$id].firstName
                LastName             = $personalGrouped[$id].lastName
                middleName           = $middleName
                birthName            = $personalGrouped[$id].birthName
                partnerNamePrefix    = $middleNamePartner
                partnerName          = $personalGrouped[$id].partnerName
                conventionSourceCode = $personalGrouped[$id].nameFormatCode
                dateOfBirth          = $personalGrouped[$id].personNav.dateOfBirth
                BusinessEmail        = ($PerEmailGrouped[$id] | Where-Object { $_.emailType -eq $emailLabels["Business"] }).emailAddress
                PrivateEmail         = ($PerEmailGrouped[$id] | Where-Object { $_.PhoneType -eq $emailLabels["Personal"] }).emailAddress
                BusinessPhone        = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Business"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                MobilePhone          = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Home"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                CellPhone            = ($PerPhoneGrouped[$id] | Where-Object { $_.PhoneType -eq $phoneLabels["Cell"] }).phoneNumber  ## The telephone number can be split in multiply proprties (AreaCode, CountryCode, phoneNumber)
                Gender               = $personalGrouped[$id].gender
                Contracts            = [System.Collections.Generic.List[PscustomObject]]::new()
            }
            #Contract Section 
            [array]$contracts = $null
            [array]$contracts = $EmpEmploymentGrouped[$id]
            if ($contracts.count -gt 0) {
                foreach ($c in $contracts) {
                    if (-not [string]::IsNullOrEmpty($c.company)) {
                        $c | Add-Member -MemberType NoteProperty -Name "CompanyName" -Value $companyInfoGrouped[$c.company].name
                    }
              
                    if (-not [string]::IsNullOrEmpty($c.costCenter)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "CostCenterName" -Value $costCenterGrouped[$c.costCenter].name
                    }

                    if (-not [string]::IsNullOrEmpty($c.location)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "locationName" -Value $locationGrouped[$c.location].name
                        $c | Add-Member -MemberType NoteProperty -Name "CustomClinicCode" -Value  $ExteneddataGrouped[$c.location].ClinicCode
                        $c | Add-Member -MemberType NoteProperty -Name "CustomCompany" -Value  $ExteneddataGrouped[$c.location].Company
                        $c | Add-Member -MemberType NoteProperty -Name "CustomLocation" -Value  $ExteneddataGrouped[$c.location].Location
                        $c | Add-Member -MemberType NoteProperty -Name "CustomCostcenterID" -Value  $ExteneddataGrouped[$c.location].CostCentreID
                        $c | Add-Member -MemberType NoteProperty -Name "CustomCostcenterName" -Value  $ExteneddataGrouped[$c.location].CostCentre 
                        $c | Add-Member -MemberType NoteProperty -Name "CustomPMS" -Value  $ExteneddataGrouped[$c.location].PMS
                        $c | Add-Member -MemberType NoteProperty -Name "CustomTenantID" -Value  $ExteneddataGrouped[$c.location].TenantID
                        $c | Add-Member -MemberType NoteProperty -Name "CustomDomainName" -Value  $ExteneddataGrouped[$c.location].DomainName
                    }
                    if (-not [string]::IsNullOrEmpty($c.division)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "divisionName" -Value $divisionGrouped[$c.division].name
                    }
                    if (-not [string]::IsNullOrEmpty($c.department)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "departmentName" -Value $departmentGrouped[$c.department].name
                    }
                    if (-not [string]::IsNullOrEmpty($c.businessUnit)) {                    
                        $c | Add-Member -MemberType NoteProperty -Name "businessUnitName" -Value $BusinessUnitGrouped[$c.businessUnit].name
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