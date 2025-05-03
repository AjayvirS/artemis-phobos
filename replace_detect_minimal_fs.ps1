param(
    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [string]$SourceFile = "C:\Users\ajayv\Desktop\bwrap_docker\artemis-maven-docker-main\detect_minimal_fs.sh",

    [Parameter(Mandatory = $false)]
    $DestinationPath = "/opt/detect_minimal_fs.sh"

)

Write-Output "Replacing file in container '$ContainerName': $DestinationPath with file: $SourceFile"
# Use $($ContainerName) to safely insert the container name followed by a colon
docker cp "$SourceFile" "$($ContainerName):$DestinationPath"

if ($LASTEXITCODE -eq 0) {
    Write-Output "File replaced successfully."
} else {
    Write-Error "Failed to replace the file in container '$ContainerName'."
}
