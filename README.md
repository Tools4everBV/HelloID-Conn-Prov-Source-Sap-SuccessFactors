| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/sapsuccessfactors-logo.png">
</p>

## Table of contents
- [Introduction](#Introduction)
-  [Todo](#Todo)
- [Endpoints implemented](#Endpoints-implemented)
- [Getting started](#Getting-started)
  + [Prerequisites](#Prerequisites)
  + [Configuration Settings](#Configuration-Settings)
  


---

## Introduction

A vital part of SAP since 2012, SAP SuccessFactors is a world-leading provider of cloud human experience management (HXM) – the new people-focused term for HCM. Our HXM suite lets you provide employees with experiences that recognize their individual value and consistently motivate them to achieve peak performance levels.

This connector is created based on the endpoints below, which retrieve the suitable fields to map a HelloID person. Note that the properties on the contracts are mostly reference codes to additional lists. To get a meaningful display name, these lists must be implemented.

Sap Successfactors operates with multiply endpoints which combined get a full HelloID person and contracts. The first endpoint PerPerson retrieves all the persons but does not contains any Personal Information. This can be retrieved with the PerPersonal endpoint, although this can be done after the person actually starts working. So as a result there are multiple persons without a name or display name. This must be solved when implementing the connector with the customer's needs. It's possible to retrieve future person information with the parameter 'asofdate', at the moment this is now not implemented. The same applies for Employments and EmploymentsJobs.

## Todo

  - [ ] Adding Additional List to translate or map the codes in the contracts to a meaningful display name
    - [X] Division
    - [x] CostCenter
    - [ ] EmplStatus
    - [X] BusinessUnit
    - [ ] Position
    - [x] Company
    - [X] Location   
    - [X] Department   *(Deparments.ps1)*

- [ ] Adding Additional List to translate or map the codes in the Person Object to a meaningful display name 
    - [ ] Salutation (MRS , MR , e.g.)

 - [ ] Adding *AsOfDate* to the PerPersonal and EmpJob endpoint to retrieve personal or Job details for future employees.
 - [ ] Rate limiting API Calls ? https://blogs.sap.com/2017/08/11/sap-api-management-rate-limiting-api-calls-per-application/

---

## Endpoints implemented

 - /PerPerson  *Biographical Information*
- /PerPersonal *Personal Information*
- /PerPhone
- /PerEmail
- /EmpEmployment *Employment Details*
- /EmpJob *Job Information*
- /Picklist('ecEmailType')
- /Picklist('ecPhoneType')
- /FOCompany
- /FODepartments *(Deparments.ps1)*
- /FOLocation
- /FODivision
- /FODepartment
- /FOBusinessUnit

---

## Getting started

### Prerequisites

 - [ ] UserName and password or an API key to authenticate with SAP-SuccessFactors Webservice



### Configuration Settings
  You must fill the Webservice URL of the SAP SuccessFactors, with differs for each customer Example: https://sandbox.api.sap.com/successfactors/odata/v2
  The way you authenticate to the web service depends on your implementation, some environments require a username and password while others accept only an API-Key. The connector now supports both. To use "Username and Password" you must use the enable the toggle: *Use Username and Password*

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
