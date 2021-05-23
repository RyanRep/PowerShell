function AssertADApplicationExists {
    param(
        [string] $AppName
    )
    $App = Get-AzureADApplication -Filter "DisplayName eq '$AppName'"
    if ($null -eq $App) {
        throw "$AppName Does Not Exist!!!" 
    }
    return $App
}

function AssertADServicePrincipalExists {
    param(
        [string] $ServicePrincipalName
    )
    $ServicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq '$ServicePrincipalName'"
    if ($null -eq $ServicePrincipal) {
        throw "$ServicePrincipalName Does Not Exist!!!" 
    }
    return $ServicePrincipal
}

function CreateADApplicationIfNotExists {
    param (
        [string] $AppName
    )
    Write-Host "Creating $AppName If It Doesn't Already Exist"
    $App = Get-AzureADApplication -Filter "DisplayName eq '$AppName'"
    if ($null -eq $App) {
        Write-Host "$AppName Doesn't Exist, Creating it..."
        New-AzureADApplication -DisplayName $AppName | Out-null
        Write-Host "Created $AppName"
    }
    else {
        Write-Host "$AppName Already Exists"
    }
}

function AssignGroupMembershipClaims {
    param(
        [string] $AppName,
        [string] $GroupMembershipClaims
    )
    Write-Host "Setting GroupMembershipClaims to $GroupMembershipClaims for $AppName"
    $App = AssertADApplicationExists -AppName $AppName
    Set-AzureADApplication -ObjectId $App.ObjectId -GroupMembershipClaims $GroupMembershipClaims
    Write-Host "Set GroupMembershipClaims"
}

function RemoveAllAppRolesFromADApplication {
    param(
        [string] $AppName
    )
    Write-Host "Removing All App Roles For $AppName"
    $App = AssertADApplicationExists -AppName $AppName
    $Roles = $App.AppRoles
    Write-Host "$(($Roles | Measure-Object).Count) Roles To Remove"
    Foreach ($Role in $Roles) {
        Write-Host "Disabling Role $($Role.DisplayName)"
        $Role.IsEnabled = $false
    }
    Set-AzureADApplication -ObjectId $App.ObjectId -AppRoles $Roles
    Set-AzureADApplication -ObjectId $App.ObjectId -AppRoles @()
    Write-Host "Removed All App Roles From $AppName"
}

function AddAppRoleForADApplication {
    param(
        [string] $AppName,
        [string] $Value,
        [string] $DisplayName,
        [string] $Description,
        [string] $AllowedMemberTypes
    )
    Write-Host "Adding App Role For $AppName. Value: $Value, DisplayName: $DisplayName, Description: $Description AllowedMemberTypes: $AllowedMemberTypes"
    $App = AssertADApplicationExists -AppName $AppName

    $ExistingAppRole = $App.AppRoles | Where-Object { $_.DisplayName -eq $DisplayName }
    if ($null -ne $ExistingAppRole) {
        Write-Host "$DisplayName Already Exists On $AppName. Not Making Any Changes."
        return
    }

    $Role = New-Object -TypeName Microsoft.Open.AzureAD.Model.AppRole
    $Role.IsEnabled = $true
    $Role.DisplayName = $DisplayName
    $Role.Value = $Value
    $Role.AllowedMemberTypes = $AllowedMemberTypes
    $Role.Id = New-Guid
    $Role.Description = $Description

    $AppRoles = $App.AppRoles
    if (($AppRoles | Measure-Object).Count -eq 0) {
        $AppRoles = @($Role)
    }
    else {
        $AppRoles = $AppRoles + $Role
    }
    Set-AzureADApplication -ObjectId $App.ObjectId -AppRoles $AppRoles
    Write-Host "Added App Role to $AppName"
}

function SetADApplicationIdentifierUris {
    param(
        [string] $AppName
    )
    $App = AssertADApplicationExists -AppName $AppName
    Write-Host "Setting Uri api://$($App.AppId) for $AppName"
    Set-AzureADApplication -ObjectId $App.ObjectId -IdentifierUris @("api://$($App.AppId)")
}

function CreateServicePrincipalIfNotAlreadyExists {
    param(
        [string] $AppName
    )
    $App = AssertADApplicationExists -AppName $AppName
    $ServicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq '$AppName'"
    if ($null -eq $ServicePrincipal) {
        Write-Host "Service Principal $AppName Does Not Exist. Creating it..."
        New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $true -DisplayName $AppName | Out-null
        Write-Host "Created Service Principal $AppName"
    }
    else {
        Write-Host "Service Principal $AppName Already Exists"
    }
}

function RmoveAllADGroupAssignmentsFromServicePrincipal {
    param(
        [string] $ServicePrincipalName
    )
    $ServicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq '$ServicePrincipalName'"
    $Assignments = Get-AzureADServiceAppRoleAssignment -ObjectId $ServicePrincipal.ObjectId
    Foreach ($Assignment in $Assignments) {
        $Group = Get-AzureADGroup -Filter "DisplayName eq '$($Assignment.PrincipalDisplayName)'"
        if ($null -ne $Group) {
            Write-Host "Removing Assigment $($Assignment.PrincipalDisplayName) From $($Assignment.ResourceDisplayName)"
            Remove-AzureADGroupAppRoleAssignment -AppRoleAssignmentId $Assignment.ObjectId -ObjectId $Group.ObjectId
        }
    }
}

function AssignADGroupToAppRole {
    param(
        [string] $AppName,
        [string] $ADGroupName,
        [string] $AppRoleName
    )
    Write-Host "Assigning $ADGroupName To $AppRoleName on $AppName"

    $Group = Get-AzureADGroup -Filter "DisplayName eq '$ADGroupName'"
    if ($null -eq $Group) {
        throw "AD Group $ADGroupName Does Not Exist!!"
    }

    $ServicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq '$AppName'"
    if ($null -eq $ServicePrincipal) {
        throw "Service Principal $AppName Does Not Exist!!"
    }

    $AppRole = $ServicePrincipal.AppRoles | Where-Object { $_.DisplayName -eq $AppRoleName }
    if ($null -eq $AppRole) {
        throw "App Role $AppRoleName Does Not Exist!!"
    }   
    
    New-AzureADGroupAppRoleAssignment -ObjectId $Group.ObjectId -PrincipalId $Group.ObjectId -ResourceId $ServicePrincipal.ObjectId -Id $AppRole.Id | Out-null
    Write-Host "Assigned $ADGroupName To $AppRoleName on $AppName"
}

function RemoveOauth2PermissionIfExists {
    param(
        [string] $AppName,
        [string] $Oauth2Value 
    )
    Write-Host "Removing Oauth2Perm $Oauth2Value on $AppName If It Exists"
    $App = AssertADApplicationExists -AppName $AppName
    $Oauth2Permission = $App.Oauth2Permissions | Where-Object { $_.Value -eq $Oauth2Value }
    if ($null -eq $Oauth2Permission) {
        Write-Host "Oauth2Perm $Oauth2Value on $AppName Does Not Exist"
    }
    else {
        $Oauth2Permission.IsEnabled = $false
        Write-Host "Disabling Oauth2Perm $Oauth2Value on $AppName"
        Set-AzureADApplication -ObjectId $App.ObjectId -Oauth2Permissions $App.Oauth2Permissions
        Write-Host "Disabled Oauth2Perm $Oauth2Value on $AppName"
        Write-Host "Removing Oauth2Perm $Oauth2Value on $AppName"
        $Oauth2Permissions = (AssertADApplicationExists -AppName $AppName).Oauth2Permissions
        $Oauth2Permissions.Remove($Oauth2Permission)
        Set-AzureADApplication -ObjectId $App.ObjectId -Oauth2Permissions $Oauth2Permissions
        Write-Host "Removed Oauth2Perm $Oauth2Value on $AppName"
    }
}

function CreateOauth2PermissionIfNotExists {
    param(
        [string] $AppName,
        [string] $Oauth2Value,
        [string] $UserConsentDisplayName, 
        [string] $UserConsentDescription, 
        [string] $AdminConsentDisplayName, 
        [string] $AdminConsentDescription
    )
    Write-Host "Creating OathPermission $Oauth2Value on $AppName"
    $ExistingOauth2Permission = (AssertADApplicationExists -AppName $AppName).Oauth2Permissions | Where-Object { $_.Value -eq $Oauth2Value }
    if ($null -ne $ExistingOauth2Permission) {
        Write-Host "Oauth2Permission $Oauth2Value Already Exists on $AppName" 
        return
    }

    $Oauth2Permission = New-Object Microsoft.Open.AzureAD.Model.OAuth2Permission
    $Oauth2Permission.Id = New-Guid
    $Oauth2Permission.Value = $Oauth2Value
    $Oauth2Permission.UserConsentDisplayName = $UserConsentDisplayName
    $Oauth2Permission.UserConsentDescription = $UserConsentDescription
    $Oauth2Permission.AdminConsentDisplayName = $AdminConsentDisplayName
    $Oauth2Permission.AdminConsentDescription = $AdminConsentDescription
    $Oauth2Permission.IsEnabled = $true
    $Oauth2Permission.Type = "User"

    $App = AssertADApplicationExists -AppName $AppName
    $App.Oauth2Permissions.Add($Oauth2Permission)
    Set-AzureADApplication -ObjectId $App.ObjectId -Oauth2Permissions $App.Oauth2Permissions
    Write-Host "Created OathPermission $Oauth2Value on $AppName"
}

function AddRequiredResourceAccessIfNotExists {
    param(
        [string] $RequiredResourceAppName,
        [string] $OAuthPermValueToGrant,
        [string] $AppToGrantToName
    )
    Write-Host "Granting $OAuthPermValueToGrant on $RequiredResourceAppName to $AppToGrantToName"
    $AppToGrantPermsTo = AssertADApplicationExists -AppName $AppToGrantToName
    $RequiredResourceApp = AssertADServicePrincipalExists -ServicePrincipalName $RequiredResourceAppName
    $OAuth2Perm = $RequiredResourceApp.Oauth2Permissions | Where-Object { $_.Value -eq $OAuthPermValueToGrant }
    if ($null -eq $OAuth2Perm) {
        throw "OAuth2Permission $OAuthPermValueToGrant Cannot be Found on $RequiredResourceAppName!!!"
    }

    $ExistingRequiredResourceAccess = $AppToGrantPermsTo.RequiredResourceAccess | Where-Object { $_.ResourceAppId -eq $RequiredResourceApp.AppId }
    $ExistingGrant = $ExistingRequiredResourceAccess.ResourceAccess | Where-Object { $_.Id -eq $OAuth2Perm.Id }
    if ($null -ne $ExistingGrant) {
        Write-Host "$OAuthPermValueToGrant On $RequiredResourceAppName Already Granted To $AppToGrantToName"
        return
    }

    $RequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess 
    $RequiredResourceAccess.ResourceAppId = $RequiredResourceApp.AppId
    $ResourceAccess = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess'
    $ResourceAccess.id = $OAuth2Perm.Id
    $ResourceAccess.type = 'Scope'
    $RequiredResourceAccess.ResourceAccess = $ResourceAccess

    $AppToGrantPermsTo.RequiredResourceAccess.Add($RequiredResourceAccess)
    Set-AzureADApplication -ObjectId $AppToGrantPermsTo.ObjectId -RequiredResourceAccess $AppToGrantPermsTo.RequiredResourceAccess | Out-null

    Write-Host "Granted $OAuthPermValueToGrant on $RequiredResourceAppName to $AppToGrantToName"
}


$OctopusParameters = @{
    "AzurePlatform.Application[ids].PlatformEnvironment.Name" = "dev"
    "AzurePlatform.Application[ids].ApplicationInstance.Name" = "dv6"
    "IDS.Auth.API.ReplyUrls"                                  = "https://localhost:5000/authentication/login-callback"
    "ViewerRoles"                                             = "GBL ROL IT INVESTMENT DATA STORE DEVELOPER"
    "ApproverRoles"                                           = "GBL ROL IT INVESTMENT DATA STORE DEVELOPER"
    
}

$PlatformEnvironment = $OctopusParameters["AzurePlatform.Application[ids].PlatformEnvironment.Name"] #Eg Dev
$InstanceEnvironment = $OctopusParameters["AzurePlatform.Application[ids].ApplicationInstance.Name"] #Eg DV6

#######################################
#Server Setup
#######################################

#Initial Variables
$ServerAppName = "ValmonServer-$($PlatformEnvironment)-$($InstanceEnvironment)"
Write-Host "Server App Name $ServerAppName"

#######################################################################################################################

CreateADApplicationIfNotExists -AppName $ServerAppName
AssignGroupMembershipClaims -AppName $ServerAppName -GroupMembershipClaims "All"
RemoveOauth2PermissionIfExists -AppName $ServerAppName -Oauth2Value "user_impersonation"
CreateOauth2PermissionIfNotExists -AppName $ServerAppName -Oauth2Value "API.Access" -UserConsentDisplayName "Access ValmonClient-dev-dv6" -UserConsentDescription "Access ValmonClient-dev-dv6" -AdminConsentDisplayName "Access ValmonClient-dev-dv6" -AdminConsentDescription "Access ValmonClient-dev-dv6"
RemoveAllAppRolesFromADApplication -AppName $ServerAppName
AddAppRoleForADApplication -Appname $ServerAppName -Value "Viewer" -DisplayName "Viewer" -Description "Viewer Role for the application" -AllowedMemberTypes "User"
AddAppRoleForADApplication -Appname $ServerAppName -Value "Approver" -DisplayName "Approver" -Description "Approver Role for the application" -AllowedMemberTypes "User"
SetADApplicationIdentifierUris -AppName $ServerAppName
CreateServicePrincipalIfNotAlreadyExists -AppName $ServerAppName
RmoveAllADGroupAssignmentsFromServicePrincipal -ServicePrincipalName $ServerAppName
$ADViewerGroups = $OctopusParameters["ViewerRoles"].Split(';')
Foreach ($ADGroup in $ADViewerGroups) {
    AssignADGroupToAppRole -AppName $ServerAppName -ADGroupName $ADGroup -AppRoleName "Viewer"
}
$ADApproverGroups = $OctopusParameters["ApproverRoles"].Split(';')
Foreach ($ADGroup in $ADApproverGroups) {
    AssignADGroupToAppRole -AppName $ServerAppName -ADGroupName $ADGroup -AppRoleName "Approver"
}
AddRequiredResourceAccessIfNotExists -RequiredResourceAppName "Microsoft Graph" -AppToGrantToName $ServerAppName -OAuthPermValueToGrant "GroupMember.Read.All"

#######################################
#Client Setup
#######################################

#Initial Variables
$ClientAppName = "ValmonClient-$($PlatformEnvironment)-$($InstanceEnvironment)"
Write-Host "Client App Name $ClientAppName"

#######################################################################################################################

CreateADApplicationIfNotExists -AppName $ClientAppName
AssignGroupMembershipClaims -AppName $ClientAppName -GroupMembershipClaims "All"
RemoveAllAppRolesFromADApplication -AppName $ClientAppName
AddAppRoleForADApplication -Appname $ClientAppName -Value "Viewer" -DisplayName "Viewer" -Description "Viewer Role for the application" -AllowedMemberTypes "User"
AddAppRoleForADApplication -Appname $ClientAppName -Value "Approver" -DisplayName "Approver" -Description "Approver Role for the application" -AllowedMemberTypes "User"
SetADApplicationIdentifierUris -AppName $ClientAppName
CreateServicePrincipalIfNotAlreadyExists -AppName $ClientAppName
RmoveAllADGroupAssignmentsFromServicePrincipal -ServicePrincipalName $ClientAppName
$ADViewerGroups = $OctopusParameters["ViewerRoles"].Split(';')
Foreach ($ADGroup in $ADViewerGroups) {
    AssignADGroupToAppRole -AppName $ClientAppName -ADGroupName $ADGroup -AppRoleName "Viewer"
}
$ADApproverGroups = $OctopusParameters["ApproverRoles"].Split(';')
Foreach ($ADGroup in $ADApproverGroups) {
    AssignADGroupToAppRole -AppName $ClientAppName -ADGroupName $ADGroup -AppRoleName "Approver"
}
AddRequiredResourceAccessIfNotExists -RequiredResourceAppName $ServerAppName -AppToGrantToName $ClientAppName -OAuthPermValueToGrant "API.Access"
AddRequiredResourceAccessIfNotExists -RequiredResourceAppName "Microsoft Graph" -AppToGrantToName $ClientAppName -OAuthPermValueToGrant "User.Read"
AddRequiredResourceAccessIfNotExists -RequiredResourceAppName "Microsoft Graph" -AppToGrantToName $ClientAppName -OAuthPermValueToGrant "openid"
AddRequiredResourceAccessIfNotExists -RequiredResourceAppName "Microsoft Graph" -AppToGrantToName $ClientAppName -OAuthPermValueToGrant "profile"


#######################################################################################################################
#Write Output Required For Auth.

Write-Host "Primary Domain: "(Get-AzureADDomain).Name
Write-Host "Tenant Id: "(Get-AzureADTenantDetail).ObjectId
Write-Host "Server App Id: "(AssertADApplicationExists -AppName $ServerAppName).AppId
Write-Host "Client App Id: "(AssertADApplicationExists -AppName $ClientAppName).AppId