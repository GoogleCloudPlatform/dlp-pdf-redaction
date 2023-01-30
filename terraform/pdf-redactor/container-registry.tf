# resource "google_artifact_registry_repository" "docker_repo" {
#   project       = var.project_id
#   location      = var.region
#   repository_id = "pdf-redaction-images"
#   description   = "Docker repository for PDF Redaction images"
#   format        = "DOCKER"

#   depends_on = [
#     module.project_services,
#   ]
# }

# locals {
#     docker_repo = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
# }
locals {
    docker_repo = "gcr.io/${var.project_id}"
}