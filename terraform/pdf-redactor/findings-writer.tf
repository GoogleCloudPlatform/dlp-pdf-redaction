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

resource "google_service_account" "findings_writer" {
  account_id   = "findings-writer-sa${local.app_suffix}"
  display_name = "SA for Findings Writer function"
}

resource "google_project_iam_member" "findings_writer_bq_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.findings_writer.email}"
}

resource "google_project_iam_member" "findings_writer_storage_user" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.findings_writer.email}"
}

resource "google_cloud_run_service" "findings_writer" {
  name     = "findings-writer${local.app_suffix}"
  location = var.region

  template {
    spec {
      containers {
        image = var.image_findings_writer
        env {
          name  = "BQ_DATASET"
          value = google_bigquery_dataset.pdf_redaction.dataset_id
        }
        env {
          name  = "BQ_TABLE"
          value = google_bigquery_table.findings.table_id
        }
      }
      service_account_name = google_service_account.findings_writer.email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal"
    }
  }

  depends_on = [
    module.project_services,
  ]
}
