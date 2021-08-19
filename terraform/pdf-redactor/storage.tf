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

resource "google_storage_bucket" "pdf_input_bucket" {
  name          = "pdf-input-bucket${local.app_suffix}"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket" "working_bucket" {
  name          = "pdf-working-bucket${local.app_suffix}"
  location      = var.region
  force_destroy = true
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "pdf_output_bucket" {
  name          = "pdf-output-bucket${local.app_suffix}"
  location      = var.region
  force_destroy = true
}
