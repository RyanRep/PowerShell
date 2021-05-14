#Initial Variables
$ClientAppName = "ValmonClient-Dev-DV6" 
$ServerAppName = "ValmonServer-Dev-DV6" 
[Collections.Generic.List[String]]$replyUrls = "https://localhost:44392/authentication/login-callback".Split(',')
$ServerApp = Get-AzureADApplication -Filter "DisplayName eq '$ServerAppName'"

#######################################################################################################################

#Find Client App
$query = "DisplayName eq '$ClientAppName'" 
$ClientApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Create Client App If It Does Not Exist 
if ($ClientApp -eq $null){
   Write-Host $ClientAppName "Does Not Exist, Creating..."
   New-AzureADApplication -DisplayName $ClientAppName 
}else{
   Remove-AzureADApplication -ObjectId $ClientApp.ObjectId 
   Write-Host $ClientAppName "Already Exists"
   New-AzureADApplication -DisplayName $ClientAppName
}
$ClientApp = Get-AzureADApplication -Filter $query
Set-AzureADApplication -ObjectId $ClientApp.ObjectId -ReplyUrls $replyUrls
$ClientApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

# Disable the App Registration scope.
$Scopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]
$Scope = $ClientApp.Oauth2Permissions | Where-Object { $_.Value -eq "user_impersonation" }
$Scope.IsEnabled = $false
$Scopes.Add($Scope)
Set-AzureADApplication -ObjectId $ClientApp.ObjectID -Oauth2Permissions $Scopes
$ClientApp = Get-AzureADApplication -Filter $query

# Remove the App Registration scope.
$EmptyScopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]
Set-AzureADApplication -ObjectId $ClientApp.ObjectID -Oauth2Permissions $EmptyScopes
$ClientApp = Get-AzureADApplication -Filter $query


#######################################################################################################################

#Create Enterprise Client App
$ClientEnterpriseApp = Get-AzureADServicePrincipal -SearchString $ClientAppName
if ($ClientEnterpriseApp -eq $null){
  Write-Host "Enterprise Client App Does Not Exist"
  New-AzureADServicePrincipal -AccountEnabled $true -AppId $ClientApp.AppId -AppRoleAssignmentRequired $true -DisplayName $ClientAppName
}else{
  Write-Host "Enterprise Client App Already Exists" 
  Remove-AzureADServicePrincipal -ObjectId $ClientEnterpriseApp.ObjectId
  Set-AzureADServicePrincipal -ObjectId $ClientEnterpriseApp.ObjectId -AccountEnabled $true -AppId $ClientApp.AppId -AppRoleAssignmentRequired $true -DisplayName $ClientAppName
}

#######################################################################################################################

#Create Graph Perms For Client App
$GraphApiRequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess 
$GraphApiRequiredResourceAccess.ResourceAppId = '00000003-0000-0000-c000-000000000000'
$GraphiApiDelegatedUserRead = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess' 
$GraphiApiDelegateduserRead.id = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
$GraphiApiDelegateduserRead.type = 'Scope'
$GraphApiRequiredResourceAccess.ResourceAccess = $GraphiApiDelegatedUserRead

#######################################################################################################################

#Create API Permission So Client Can Call Server
$RequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess 
$RequiredResourceAccess.ResourceAppId = $ServerApp.AppId
$ResourceAccess = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess'
$ResourceAccess.id = $ServerApp.Oauth2Permissions[0].Id 
$ResourceAccess.type='Scope'
$RequiredResourceAccess.ResourceAccess=$ResourceAccess

#######################################################################################################################

#Apply Perm Changes
$RequiredResourceAccess = @($GraphApiRequiredResourceAccess,$RequiredResourceAccess)
Set-AzureADApplication -ObjectId $ClientApp.ObjectId -RequiredResourceAccess $RequiredResourceAccess
$ClientApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Give myself perms
$user = Get-AzureADUser -ObjectId "ef843754-3e72-4dd9-968e-0754efacfaae"
$servicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$($ClientApp.AppId)'"
New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $servicePrincipal.ObjectId -Id ([Guid]::Empty)
