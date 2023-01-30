# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  pdf_merger_source = "${local.src_path}/pdf-merger"
}

resource "docker_image" "pdf_merger" {
  name = "${local.docker_repo}/pdf-merger"
  build {
    context = local.pdf_merger_source
  }
}

resource "docker_registry_image" "pdf_merger" {
  name = docker_image.pdf_merger.name

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(local.pdf_merger_source, "**") : filesha1("${local.pdf_merger_source}/${f}")]))
  }

  depends_on = [
    docker_image.pdf_merger
  ]
}

resource "google_service_account" "pdf_merger" {
  account_id   = "pdf-merger-sa${local.app_suffix}"
  display_name = "SA for PDF Merger function"
}

resource "google_project_iam_member" "pdf_merger_storage_user" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.pdf_merger.email}"
}

resource "google_cloud_run_v2_service" "pdf_merger" {
  name     = "pdf-merger${local.app_suffix}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = docker_registry_image.pdf_merger.name
    }
    service_account = google_service_account.pdf_merger.email
  }

  depends_on = [
    module.project_services,
    docker_registry_image.pdf_merger,
  ]
}
