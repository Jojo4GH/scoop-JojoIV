$data = scoop export | ConvertFrom-Json
$query = $args

function ContainsAny ($str, [string[]] $arr) {
    foreach ($item in $arr) {
        if ($str -icontains $item) {
            return $true
        }
    }
    return $false
}

$matchingApps = $data.apps | Where-Object {
    (ContainsAny $_.Name $query) -or (ContainsAny $_.Info $query)
}

if ($matchingApps.Count -gt 0) {
    Write-Output $matchingApps
} else {
    Write-Information "No matching apps found." -InformationAction Continue
    exit 1
}