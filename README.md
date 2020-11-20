![image](SAP-SuccessFactors.png)
### Note!  This connector is a work in progress


## Table of contents
[TOC]

---

## Introduction

A vital part of SAP since 2012, SAP SuccessFactors is a world-leading provider of cloud human experience management (HXM) – the new people-focused term for HCM. Our HXM suite lets you provide employees with experiences that recognise their individual value and consistently motivate them to achieve peak performance levels.

This connector is created based on the following Endpoints, to get the appropriate field to map the HelloID person. Note that the property on the contracts are reference codes with additional list like the company code “7030t. This is not now implemented.


## Endpoints implemented

- /PerPerson
- /PerPersonal
- /PerPhone
- /PerEmail
- /EmpEmployment
- /EmpJob
- /Picklist('ecEmailType')
- /Picklist('ecPhoneType')
- /FOCompany
- /FODepartments

## Todo

 - [ ] Filter the active employments 
 - [ ] Multiply Employment per person
 - [ ] Adding Additional List to translate or map the codes in the contracts to a meaningful display name
   - [ ] Division
   - [ ] CostCenter
   - [ ] EmplStatus
   - [ ] BusinessUnit
   - [ ] Position
   - [x] Company
   - [ ] Location   

- [ ] Adding Additional List to translate or map the codes in the Person Object to a meaningful display name 
    - [ ] Salutation (MRS , MR , e.g.)

 - [ ] Adding *AsOfDate* to the PerPersonal and EmpJob endpoint to retrieve personal or Job details for future employees.

---


## Prerequisites

 - UserName and password Or a API key to access Authorizate with the SAP-SuccessFactors Webservice
 -

---

## Getting started

#### Configuration Settings
  You must fill the Webservice URL of the SAP SuccessFactors, with differs for each customer Example: https://sandbox.api.sap.com/successfactors/odata/v2
  The way you authenticate to the web service depends on your implementation, some environments require a username and password while others accept only an API-Key. The connector now supports both. To use "Username and Password" you must use the enable the toggle: *Use Username and Password*



---