# Run in PowerShell 7 (pwsh)
Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
# interactive login; for automation use certificate-based app or service principal
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","Directory.ReadWrite.All","Team.ReadWrite.All"
Connect-PnPOnline -Url "https://<yourtenant>.sharepoint.com" -Interactive
