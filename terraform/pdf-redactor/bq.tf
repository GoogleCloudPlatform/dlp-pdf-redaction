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

resource "google_bigquery_dataset" "pdf_redaction" {
  dataset_id    = "pdf_redaction${local.app_suffix_underscore}"
  friendly_name = "PDF Redaction Dataset"
  description   = "This dataset contains data related to the PDF Redaction application"
  location      = var.region

  depends_on = [
    module.project_services,
  ]
}

resource "google_bigquery_table" "findings" {
  dataset_id          = google_bigquery_dataset.pdf_redaction.dataset_id
  table_id            = "findings"
  deletion_protection = false
  schema              = templatefile("${path.module}/templates/bq-table-findings.json", {})

  depends_on = [
    module.project_services,
  ]
}
