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

output "pdf_splitter_url" {
  value       = google_cloud_run_v2_service.dlp_runner.uri
  description = "PDF Splitter function url"
}

output "pdf_merger_url" {
  value       = google_cloud_run_v2_service.pdf_merger.uri
  description = "PDF Splitter function url"
}

output "dlp_runner_url" {
  value       = google_cloud_run_v2_service.dlp_runner.uri
  description = "PDF Splitter function url"
}

output "findings_writer_url" {
  value       = google_cloud_run_v2_service.findings_writer.uri
  description = "PDF Splitter function url"
}

output "pdf_input_bucket" {
  value       = google_storage_bucket.pdf_input_bucket.url
  description = "Bucket that will be used to drop/land your raw pfd files for redaction."
}

output "workflow_working_bucket" {
  value       = google_storage_bucket.working_bucket.url
  description = "Bucket that will be use for temp files, this will automatically be emptied/scrapped every day."
}

output "pdf_output_bucket" {
  value       = google_storage_bucket.pdf_output_bucket.url
  description = "Bucket that will be used to output your processed pfd files after redaction."
}

output "workflow_name" {
  value       = google_workflows_workflow.pdf_redactor.name
  description = "Workflow that orchestrated the redaction of a single PDF file"
}
