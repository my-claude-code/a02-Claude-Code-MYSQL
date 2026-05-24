# Connect to graph

Import-Module Microsoft.Graph.Authentication

Connect-MgGraph -TenantId "097f33a9-6fc9-423f-923e-f9e3a3122986" -Scopes "Application.ReadWrite.All"

Get-MgContext

$ErrorActionPreference = "Stop"

$DisplayName = "Flask-Entra-Notes-Test"
$RedirectUri = "http://localhost:5000/auth/callback"
$LogoutUri = "http://localhost:5000/logout"
$SecretDisplayName = "flask-local-dev-secret"
$SecretValidityMonths = 6

$Context = Get-MgContext

if (-not $Context) {
    throw "You are not connected to Microsoft Graph. Run Connect-MgGraph first."
}

$TenantId = $Context.TenantId

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    throw "Could not detect TenantId from the current Microsoft Graph context."
}

Write-Host "Connected tenant: $TenantId"
Write-Host "Creating app registration: $DisplayName"

$EscapedDisplayName = $DisplayName.Replace("'", "''")

$ExistingApps = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$EscapedDisplayName'"

if ($ExistingApps.value.Count -gt 0) {
    Write-Host ""
    Write-Host "An app registration with this name already exists:"
    $ExistingApps.value | Select-Object displayName, appId, id | Format-Table

    throw "Stopping to avoid duplicate app registrations. Change the DisplayName variable if you want a new app."
}

$ApplicationBodyObject = @{
    displayName = $DisplayName
    signInAudience = "AzureADMyOrg"
    web = @{
        redirectUris = @($RedirectUri)
        logoutUrl = $LogoutUri
        implicitGrantSettings = @{
            enableAccessTokenIssuance = $false
            enableIdTokenIssuance = $false
        }
    }
}

$ApplicationBody = $ApplicationBodyObject | ConvertTo-Json -Depth 20

$Application = Invoke-MgGraphRequest `
    -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/applications" `
    -Body $ApplicationBody `
    -ContentType "application/json"

Write-Host "App registration created."
Write-Host "Application object ID: $($Application.id)"
Write-Host "Application client ID: $($Application.appId)"

Write-Host "Creating service principal / Enterprise Application..."

$ServicePrincipalBodyObject = @{
    appId = $Application.appId
}

$ServicePrincipalBody = $ServicePrincipalBodyObject | ConvertTo-Json -Depth 5

$ServicePrincipal = $null

for ($i = 1; $i -le 6; $i++) {
    try {
        $ServicePrincipal = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
            -Body $ServicePrincipalBody `
            -ContentType "application/json"

        break
    }
    catch {
        if ($i -eq 6) {
            Write-Warning "Could not create service principal automatically. App registration was created."
            Write-Warning $_.Exception.Message
        }
        else {
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host "Creating client secret..."

$SecretEndDate = (Get-Date).ToUniversalTime().AddMonths($SecretValidityMonths).ToString("o")

$SecretBodyObject = @{
    passwordCredential = @{
        displayName = $SecretDisplayName
        endDateTime = $SecretEndDate
    }
}

$SecretBody = $SecretBodyObject | ConvertTo-Json -Depth 10

$Secret = Invoke-MgGraphRequest `
    -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)/addPassword" `
    -Body $SecretBody `
    -ContentType "application/json"

if ([string]::IsNullOrWhiteSpace($Secret.secretText)) {
    throw "Secret was created but secretText was not returned. Create a new client secret manually in the Entra portal."
}

$Authority = "https://login.microsoftonline.com/$TenantId"

$EnvLines = @(
    "# Generated Entra app settings for Flask app"
    ""
    "ENTRA_CLIENT_ID=$($Application.appId)"
    "ENTRA_CLIENT_SECRET=$($Secret.secretText)"
    "ENTRA_TENANT_ID=$TenantId"
    "AUTHORITY=$Authority"
    "REDIRECT_URI=$RedirectUri"
    "LOGOUT_URI=$LogoutUri"
    "SCOPES=openid profile email"
    ""
    "# Local testing database"
    "DATABASE_URL=sqlite:///app.db"
    ""
    "# Later MySQL connection string example"
    "# DATABASE_URL=mysql+pymysql://<mysql_user>:<mysql_password>@<mysql_host>:3306/<mysql_database>"
    ""
    "# Replace this before running Flask"
    "FLASK_SECRET_KEY=<random flask secret>"
)

$EnvPath = Join-Path -Path (Get-Location) -ChildPath ".env.generated"
Set-Content -Path $EnvPath -Value $EnvLines -Encoding utf8

Write-Host ""
Write-Host "============================================================"
Write-Host "DONE - APP REGISTRATION CREATED"
Write-Host "============================================================"
Write-Host ""

Write-Host "Give these values to Claude Code / put them in your Flask .env file:"
Write-Host ""

Write-Host "ENTRA_CLIENT_ID=$($Application.appId)"
Write-Host "ENTRA_CLIENT_SECRET=$($Secret.secretText)"
Write-Host "ENTRA_TENANT_ID=$TenantId"
Write-Host "AUTHORITY=$Authority"
Write-Host "REDIRECT_URI=$RedirectUri"
Write-Host "LOGOUT_URI=$LogoutUri"
Write-Host "SCOPES=openid profile email"

Write-Host ""
Write-Host "Extra object IDs:"
Write-Host "Application object ID: $($Application.id)"

if ($ServicePrincipal) {
    Write-Host "Service principal object ID: $($ServicePrincipal.id)"
}
else {
    Write-Host "Service principal object ID: Not created automatically"
}

Write-Host ""
Write-Host ".env.generated created here:"
Write-Host $EnvPath

Write-Host ""
Write-Host "IMPORTANT: Copy the client secret now. You will not be able to view this same secret value again later."