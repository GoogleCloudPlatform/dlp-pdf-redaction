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
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = var.image_dlp_runner
    }
    service_account = google_service_account.dlp_runner.email
  }

  depends_on = [
    module.project_services,
  ]
}
