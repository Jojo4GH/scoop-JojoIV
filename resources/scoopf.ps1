#Requires -Modules PSWriteColor

# scoopf - Scoop search with extra features
#
# Usage:
#   scoopf <query> [page]
#
# Examples:
#   scoopf git
#   scoopf git 2
#


# Settings
$url = "https://scoopsearch.search.windows.net/indexes/apps/docs/search?api-version=2020-06-30"
$apiKey = "DC6D2BBE65FC7313F2C52BBD2B0286ED"
$pageSize = 40

$appColor = "Yellow"
$commandColor = "DarkMagenta"
$infoColor = "Gray"



function Find-Query ($query) {
    $headers = @{
        "Api-Key" = $apiKey
    }
    $body = @{
        "search" = "$query"
        "searchMode" = "all"
        "filter" = "Metadata/DuplicateOf eq null"
        "orderby" = "search.score() desc, Metadata/OfficialRepositoryNumber desc, NameSortable asc"
        "count" = $true
        "top" = $pageSize
        "skip" = $pageSize * ($page - 1)
    }

    echo "Searching for `"$query`" ..."
    $response = Invoke-WebRequest $url -Method POST -Headers $headers -Body (ConvertTo-Json $body) -ContentType "application/json"

    if ($response.StatusCode -ne 200) {
        $response
        exit 1
    }

    return ConvertFrom-Json $response.Content
}

function Get-AvailableBucket {
    $dirs = Get-ChildItem "$env:SCOOP\buckets" -Directory
    return $dirs | % {
        @{
            "name" = $_.Name
            "url" = (git -C $_.FullName config --get remote.origin.url)
        }
    }
}

function Get-InstalledApp {
    return Get-ChildItem "$env:SCOOP\apps" -Directory
}

function Write-App ($app, $bucketName, $indent = "") {
    $name = $app.Name

    Write-Color "$indent", "$name", " ", "@$($app.Version)", "" -Color White, $appColor, White, DarkCyan, White -NoNewline
    Write-Color "  `tscoop install $bucketName/$name" -Color $commandColor

    Write-Color "$indent  " -NoNewline
    if ($null -ne $app.Description) {
        Write-Color "$($app.Description)" -Color $infoColor -NoNewline
        if ($null -ne $app.Homepage) {
            Write-Color " [$($app.Homepage)]" -Color $infoColor -NoNewline
        }
    } elseif ($null -ne $app.Homepage) {
        Write-Color "$($app.Homepage)" -Color $infoColor -NoNewline
    }
    Write-Color ""
}

function Write-BucketRating ($metadata) {
    if ($metadata.OfficialRepository) {
        Write-Color "✓" -Color $infoColor -NoNewline
    } else {
        Write-Color "⭐$($metadata.RepositoryStars)" -Color $infoColor -NoNewline
    }
}

function Write-Bucket ($apps, $availableBuckets, $indent = "") {
    $metadata = $apps[0].Metadata
    $bucket = $metadata.Repository
    $bucketName = $bucket.Split("/")[-1] -replace "scoop-", "" -replace "Scoop-", ""
    $bucketName = "$($bucket.Split("/")[-2])_$bucketName"
    $bucketColor = "Red"
    $installedBucket = $availableBuckets | ? { $_.url -eq $bucket }
    if ($null -ne $installedBucket) {
        $bucket = $installedBucket.name
        $bucketName = $installedBucket.name
        $bucketColor = "Green"
    } elseif ($metadata.OfficialRepository) {
        # $bucketColor = "DarkGreen"
    }

    Write-Color "$indent", "$bucket", " " -Color White, $bucketColor, White -NoNewline
    Write-BucketRating $metadata
    if ($null -eq $installedBucket) {
        Write-Color "  `tscoop bucket add $bucketName $bucket" -Color $commandColor -NoNewline
    } else {
        # Write-Color " [available]" -Color DarkGray -NoNewline
    }
    Write-Color ""
    foreach ($app in $apps) {
        Write-App $app $bucketName -indent "$indent  "
    }
}


# Input parsing
$query = $args[0]
if ($null -eq $query) {
    Write-Color "Please provide a search query" -Color Red
    exit 1
}

$page = $args[1]
if ($null -eq $page -or $page -lt 1) {
    $page = 1
}

# Request
$result = Find-Query $query

# Result processing
$totalCount = $result.'@odata.count'
$count = $result.value.Count
if ($count -eq 0) {
    Write-Color "No results found" -Color Red
    exit 1
}
$remainingCount = $totalCount - $pageSize * $page
$appsByBucket = $result.value | Group-Object -Property { $_.Metadata.Repository } | Sort-Object -Property { $_.Name } | Sort-Object -Property { $_.Group[0].Metadata.OfficialRepositoryNumber } -Descending

# Output
Write-Color "Found $totalCount result(s) in $($appsByBucket.Count) bucket(s)" -NoNewline
if ($totalCount -gt $count) {
    $start = ($page - 1) * $pageSize + 1
    $end = $start + $count - 1
    Write-Color " (showing $start-$end)" -NoNewline
}
Write-Color ":"
Write-Color ""

$availableBuckets = Get-AvailableBucket

foreach ($apps in $appsByBucket) {
    Write-Bucket $apps.Group $availableBuckets -indent ""
    Write-Color ""
}

if ($remainingCount -gt 0) {
    Write-Color "There are $remainingCount more results available." -Color White
    Write-Color "Use   ", "$($MyInvocation.MyCommand) $query $($page + 1)", "   to show $([Math]::Min($pageSize, $remainingCount)) more" -Color White, $commandColor, White
}
