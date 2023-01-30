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
  dlp_runner_source = "${local.src_path}/dlp-runner"
}

resource "docker_image" "dlp_runner" {
  name = "${local.docker_repo}/dlp-runner"
  build {
    context = local.dlp_runner_source
  }
}

resource "docker_registry_image" "dlp_runner" {
  name = docker_image.dlp_runner.name

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(local.dlp_runner_source, "**") : filesha1("${local.dlp_runner_source}/${f}")]))
  }

  depends_on = [
    docker_image.dlp_runner
  ]
}

resource "google_service_account" "dlp_runner" {
  project      = var.project_id
  account_id   = "dlp-runner-sa${local.app_suffix}"
  display_name = "SA for DLP Runner function"
}

resource "google_project_iam_member" "dlp_runner_dlp_user" {
  project = var.project_id
  role    = "roles/dlp.user"
  member  = "serviceAccount:${google_service_account.dlp_runner.email}"
}

resource "google_project_iam_member" "dlp_runner_dlp_template_reader" {
  project = var.project_id
  role    = "roles/dlp.inspectTemplatesReader"
  member  = "serviceAccount:${google_service_account.dlp_runner.email}"
}

resource "google_project_iam_member" "dlp_runner_storage_user" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dlp_runner.email}"
}

resource "google_cloud_run_v2_service" "dlp_runner" {
  name     = "dlp-runner${local.app_suffix}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = docker_registry_image.dlp_runner.name
    }
    service_account = google_service_account.dlp_runner.email
  }

  depends_on = [
    module.project_services,
    docker_registry_image.dlp_runner,
  ]
}
