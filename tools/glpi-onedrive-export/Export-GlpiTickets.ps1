#Requires -Version 5.1
<#
.SYNOPSIS
    Exporte, pour chaque technicien configure, les tickets GLPI qui lui sont
    assignes vers un fichier JSON dans un dossier synchronise OneDrive.

.DESCRIPTION
    Ce script comble l'absence d'acces reseau direct a GLPI depuis un
    telephone hors du reseau de l'entreprise : execute toutes les heures
    (Planificateur de taches Windows) sur une machine qui, elle, a acces a
    GLPI, il ecrit un fichier JSON par technicien dans un dossier OneDrive.
    Ce dossier se synchronise ensuite tout seul vers le cloud, et l'app iOS
    (mode "Fichier partage") va lire ce fichier via son URL de partage.

    Le format JSON produit reutilise exactement les cles de l'API GLPI
    (id, name, content, status, priority, date, date_mod, followups[]) afin
    de rester decodable tel quel cote app sans mapping supplementaire.

.NOTES
    Compte de service GLPI requis : App-Token + User-Token d'un compte
    ayant le droit de voir les tickets de TOUS les techniciens listes dans
    la config (jamais un compte personnel).
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.json")
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    if ($script:Config -and $script:Config.LogFile) {
        $logDir = Split-Path -Parent $script:Config.LogFile
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:Config.LogFile -Value $line
    }
}

function ConvertTo-ArraySafe {
    # Invoke-RestMethod/ConvertFrom-Json can hand back $null (empty JSON
    # array) or a single bare object (JSON array of exactly one item)
    # instead of a real collection. Normalize to always get a real array.
    param($InputObject)
    if ($null -eq $InputObject) { return @() }
    return @($InputObject)
}

function New-JsonList {
    # ConvertTo-Json silently collapses a native PowerShell array holding
    # exactly one element into a bare JSON object instead of a one-item
    # array. A generic List<object> does not have that quirk.
    [System.Collections.Generic.List[object]]::new()
}

function Invoke-GlpiApi {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Headers
    )
    $uri = "{0}/apirest.php/{1}" -f $script:Config.GlpiUrl.TrimEnd('/'), $Path
    return Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get
}

function Build-QueryString {
    param([hashtable]$Params)
    $pairs = foreach ($key in $Params.Keys) {
        "{0}={1}" -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$Params[$key])
    }
    return ($pairs -join '&')
}

function Open-GlpiSession {
    $headers = @{
        "App-Token"     = $script:Config.AppToken
        "Authorization" = "user_token $($script:Config.UserToken)"
    }
    $response = Invoke-GlpiApi -Path "initSession" -Headers $headers
    return $response.session_token
}

function Close-GlpiSession {
    param([string]$SessionToken)
    if (-not $SessionToken) { return }
    try {
        Invoke-GlpiApi -Path "killSession" -Headers (Get-AuthHeaders $SessionToken) | Out-Null
    } catch {
        Write-Log "Echec de fermeture de session GLPI (sans gravite) : $_" "WARN"
    }
}

function Get-AuthHeaders {
    param([string]$SessionToken)
    return @{
        "App-Token"     = $script:Config.AppToken
        "Session-Token" = $SessionToken
    }
}

function Get-AssignedTicketIds {
    param([string]$SessionToken, [int]$TechnicianId)

    $fields = $script:Config.Fields
    $query = [ordered]@{
        "range"                        = "0-99"
        "criteria[0][field]"           = $fields.AssignedTechnician
        "criteria[0][searchtype]"      = "equals"
        "criteria[0][value]"           = $TechnicianId
        "forcedisplay[0]"              = $fields.Id
        "forcedisplay[1]"              = $fields.Title
        "forcedisplay[2]"              = $fields.Status
    }
    if (-not $script:Config.IncludeClosed) {
        $query["criteria[1][link]"] = "AND"
        $query["criteria[1][field]"] = $fields.Status
        $query["criteria[1][searchtype]"] = "notequals"
        $query["criteria[1][value]"] = 6
    }

    $path = "search/Ticket?{0}" -f (Build-QueryString $query)
    $result = Invoke-GlpiApi -Path $path -Headers (Get-AuthHeaders $SessionToken)
    $rows = ConvertTo-ArraySafe $result.data

    $ids = foreach ($row in $rows) {
        $idProperty = $fields.Id
        if ($row.PSObject.Properties.Name -contains $idProperty) {
            [int]$row.$idProperty
        }
    }
    return $ids
}

function Get-TicketExportEntry {
    param([string]$SessionToken, [int]$TicketId)

    $headers = Get-AuthHeaders $SessionToken
    $ticket = Invoke-GlpiApi -Path "Ticket/$TicketId" -Headers $headers
    $followupsRaw = ConvertTo-ArraySafe (Invoke-GlpiApi -Path "Ticket/$TicketId/ITILFollowup" -Headers $headers)

    $followups = New-JsonList
    foreach ($followup in $followupsRaw) {
        $followups.Add([ordered]@{
            id         = $followup.id
            content    = $followup.content
            date       = $followup.date
            is_private = $followup.is_private
        })
    }

    return [ordered]@{
        id        = $ticket.id
        name      = $ticket.name
        content   = $ticket.content
        status    = $ticket.status
        priority  = $ticket.priority
        date      = $ticket.date
        date_mod  = $ticket.date_mod
        followups = $followups
    }
}

function Export-TechnicianTickets {
    param([string]$SessionToken, $Technician)

    Write-Log "Export du technicien '$($Technician.Slug)' (id $($Technician.Id))…"
    $ticketIds = Get-AssignedTicketIds -SessionToken $SessionToken -TechnicianId $Technician.Id
    Write-Log "  -> $($ticketIds.Count) ticket(s) trouve(s)."

    $tickets = New-JsonList
    foreach ($id in $ticketIds) {
        try {
            $tickets.Add((Get-TicketExportEntry -SessionToken $SessionToken -TicketId $id))
        } catch {
            Write-Log "  -> Echec de recuperation du ticket #$id : $_" "WARN"
        }
    }

    $export = [ordered]@{
        generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        tickets      = $tickets
    }

    $targetFile = Join-Path $script:Config.OneDriveExportFolder "tickets_$($Technician.Slug).json"
    $tempFile = "$targetFile.tmp"

    if (-not (Test-Path $script:Config.OneDriveExportFolder)) {
        New-Item -ItemType Directory -Path $script:Config.OneDriveExportFolder -Force | Out-Null
    }

    ($export | ConvertTo-Json -Depth 10) | Out-File -FilePath $tempFile -Encoding utf8 -Force
    Move-Item -Path $tempFile -Destination $targetFile -Force

    Write-Log "  -> Ecrit dans $targetFile"
}

# --- Programme principal ---

if (-not (Test-Path $ConfigPath)) {
    throw "Fichier de configuration introuvable : $ConfigPath (copiez config.example.json vers config.json et remplissez-le)."
}
$script:Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

$sessionToken = $null
try {
    Write-Log "Ouverture de session GLPI sur $($script:Config.GlpiUrl)…"
    $sessionToken = Open-GlpiSession

    foreach ($technician in $script:Config.Technicians) {
        try {
            Export-TechnicianTickets -SessionToken $sessionToken -Technician $technician
        } catch {
            Write-Log "Echec de l'export pour '$($technician.Slug)' : $_" "ERROR"
        }
    }
} catch {
    Write-Log "Erreur fatale : $_" "ERROR"
    exit 1
} finally {
    Close-GlpiSession -SessionToken $sessionToken
}

Write-Log "Export termine."
