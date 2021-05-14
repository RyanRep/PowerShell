#Initial Variables
$ServerAppName = "ValmonServer-Dev-DV6" 

#######################################################################################################################

#Find Server App
$query = "DisplayName eq '$ServerAppName'" 
$ServerApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Create Server App If It Does Not Exist
if ($ServerApp -eq $null){
  Write-Host $ServerAppName "Does Not Exist, Creating..."
  New-AzureADApplication -DisplayName $ServerAppName 
}else{
  Remove-AzureADApplication -ObjectId $ServerApp.ObjectId 
  Write-Host $ServerAppName "Already Exists" 
  New-AzureADApplication -DisplayName $ServerAppName
}
$ServerApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Set Server Application ID URI
$IdentifierUris = @("api://$($ServerApp.AppId)")
Set-AzureADApplication -ObjectId $ServerApp.ObjectId -IdentifierUris $IdentifierUris
$ServerApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Rename OAuth Permission on Server
$OAuthPerm = $ServerApp.Oauth2Permissions[0]
$OAuthPerm.Value = "API.Access"
Set-AzureADApplication -ObjectId $ServerApp.ObjectId -Oauth2Permissions @($OAuthPerm) 
$ServerApp = Get-AzureADApplication -Filter $query

#######################################################################################################################

#Create Enterprise Server App
$ServerEnterpriseApp = Get-AzureADServicePrincipal -SearchString $ServerAppName
if ($ServerEnterpriseApp -eq $null){
  Write-Host "Enterprise Server App Does Not Exist"
  New-AzureADServicePrincipal -AccountEnabled $true -AppId $ServerApp.AppId -AppRoleAssignmentRequired $true -DisplayName $ServerAppName
}else{
  Write-Host "Enterprise Server App Already Exists" 
  Remove-AzureADServicePrincipal -ObjectId $ServerEnterpriseApp.ObjectId
  Set-AzureADServicePrincipal -ObjectId $ServerEnterpriseApp.ObjectId -AccountEnabled $true -AppId $ServerApp.AppId -AppRoleAssignmentRequired $true -DisplayName $ServerAppName
}

#######################################################################################################################

#Give myself perms
$user = Get-AzureADUser -ObjectId "ef843754-3e72-4dd9-968e-0754efacfaae"
$servicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$($ServerApp.AppId)'"
New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $servicePrincipal.ObjectId -Id ([Guid]::Empty)