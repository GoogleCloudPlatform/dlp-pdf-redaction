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

resource "google_service_account" "pdf_merger" {
  account_id   = "pdf-merger-sa${local.app_suffix}"
  display_name = "SA for PDF Merger function"
}

resource "google_project_iam_member" "pdf_merger_storage_user" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.pdf_merger.email}"
}

resource "google_cloud_run_service" "pdf_merger" {
  name     = "pdf-merger${local.app_suffix}"
  location = var.region

  template {
    spec {
      containers {
        image = var.image_pdf_merger
      }
      service_account_name = google_service_account.pdf_merger.email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    module.project_services,
  ]
}
