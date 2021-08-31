# Get required environment variables from .\config\settings.json file
$accessToken = Get-Content .\config\ds_access_token.txt

# Construct your API headers
# Step 2 start
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.add("Authorization", "Bearer $accessToken")
$headers.add("Content-Type", "application/json")
# Step 2 end

# Get required environment variables from .\config\settings.json file
$variables = Get-Content .\config\settings.json -Raw | ConvertFrom-Json

# Check that we have an organization id in the settings.json config file
if (!$variables.ORGANIZATION_ID) {
    Write-Output "Organization ID is needed. Please add the ORGANIZATION_ID variable to the settings.json"
    exit -1
}

$base_path = "https://api-d.docusign.net/management"
$organizationId = $variables.ORGANIZATION_ID

# Create the bulk export request
$uri2 = "${base_path}/v2/organizations/$organizationId/exports/user_list"

$body = @"
{
    "type": "organization_memberships_export"
}
"@

$result = Invoke-WebRequest -headers $headers -Uri $uri2 -body $body -Method POST

# Get request Id
$requestId = $($result.Content  | ConvertFrom-Json).id
$requestId

# Step 3 start
Write-Output "Checking Bulk Action Status"
$uri2 = "${base_path}/v2/organizations/$organizationId/exports/user_list/$requestId"
$result2 = Invoke-WebRequest -headers $headers -Uri $uri2 -Method GET
$result2.Content
$results = $result2 | ConvertFrom-Json
$retrycount = 0

Do {
    Write-Output "The Bulk Action has not been completed. Retrying in 5 seconds. To abort, Press Control+C"
    Start-Sleep 5
    $result2 = Invoke-WebRequest -headers $headers -Uri $uri2 -Method GET
    $resultStatus = $($result2 | ConvertFrom-Json).status
    $retrycount++
    if ($retrycount -eq 5) {
        exit 1
    }
} While ($resultStatus -ne "completed")

if ($resultStatus -eq "completed") {
    Write-Output $($result2 | ConvertFrom-Json).results.id
    $resultId = $($result2 | ConvertFrom-Json).results.id
}
else {
    Write-Output "An error has occurred, the Bulk Action has not been completed."
    exit 1
}
# Step 3 end

# Check the request status
# Step 4 start
$uri2 = "${base_path}/v2/organizations/$organizationId/exports/user_list/$requestId"
$result2 = Invoke-WebRequest -headers $headers -Uri $uri2 -Method GET
$result2.Content
$results = $result2 | ConvertFrom-Json
# Step 4 end
$results

# Get result Id
$resultId = $($result2 | ConvertFrom-Json).results.id

# Download the exported user data
# Step 5 start
$uri3 = "https://demo.docusign.net/restapi/v2/organization_exports/$organizationId/user_list/$resultId"
$result3 = Invoke-WebRequest -headers $headers -Uri $uri3 -Method GET
$result3.Content
# Step 5 end
Write-Output "Export data to file bulkexport.csv ..."
$result3.Content > bulkexport.csv