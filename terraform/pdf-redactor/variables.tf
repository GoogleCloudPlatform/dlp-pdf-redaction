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

variable "project_id" {
  type        = string
  description = "Project ID"
}
variable "region" {
  type        = string
  description = "GCP Region"
}
variable "wf_region" {
  type        = string
  description = "Cloud Workflows Region (choose a supported region: https://cloud.google.com/workflows/docs/locations)"
}
variable "suffix" {
  type        = string
  description = "Suffix to be used for all created resources (3 to 6 characters)"
  validation {
    condition     = length(var.suffix) > 3 && length(var.suffix) < 6
    error_message = "Suffix must be between 3 and 6 characters."
  }
}
variable "image_dlp_runner" {
  type        = string
  description = "Docker image for PDF Merger"
}
variable "image_findings_writer" {
  type        = string
  description = "Docker image for PDF Merger"
}
variable "image_pdf_merger" {
  type        = string
  description = "Docker image for PDF Merger"
}
variable "image_pdf_splitter" {
  type        = string
  description = "Docker image for PDF Merger"
}
