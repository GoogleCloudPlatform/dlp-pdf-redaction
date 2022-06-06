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

resource "google_service_account" "workflow" {
  account_id   = "pdf-redactor-workflow-sa${local.app_suffix}"
  display_name = "SA for PDF Redactor Workflow"
}

resource "google_project_iam_member" "workflow_cloudrun_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_project_iam_member" "workflow_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_project_iam_member" "workflow_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

data "template_file" "workflow" {
  template = file("${path.module}/templates/workflow.yaml")

  vars = {
    pdf_splitter_url    = google_cloud_run_service.pdf_splitter.status[0].url
    pdf_merger_url      = google_cloud_run_service.pdf_merger.status[0].url
    dlp_runner_url      = google_cloud_run_service.dlp_runner.status[0].url
    findings_writer_url = google_cloud_run_service.findings_writer.status[0].url
    working_bucket      = google_storage_bucket.working_bucket.name
    output_bucket       = google_storage_bucket.pdf_output_bucket.name
    dlp_template        = google_data_loss_prevention_inspect_template.dlp_pdf_template.id
  }
}

resource "google_workflows_workflow" "pdf_redactor" {
  name            = "pdf-redactor-workflow${local.app_suffix}"
  region          = var.wf_region
  description     = "Workflow that redacts sensitive information from a single PDF file"
  service_account = google_service_account.workflow.id
  source_contents = data.template_file.workflow.rendered

  depends_on = [
    module.project_services,
  ]
}
