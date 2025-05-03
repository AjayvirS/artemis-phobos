$ContainerName = "artemis-student-exercises"
$ImageName = "artemis-student-exercises"

Write-Host "Stopping and removing container if it exists..."
docker stop $ContainerName 2>$null
docker rm $ContainerName 2>$null

Write-Host "Rebuilding image without deleting cached base image..."
docker build -t $ImageName .

Write-Host "Build completed!"
