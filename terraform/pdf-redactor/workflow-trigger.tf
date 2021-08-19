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

resource "google_storage_bucket" "artifact_bucket" {
  name = "pdf-redaction-artifacts-${local.app_suffix}"
}

locals {
  function_dir           = "${path.module}/../../src/workflow-trigger"
  function_dir_sha1      = sha1(join("", [for f in fileset(local.function_dir, "**") : filesha1("${local.function_dir}/${f}")]))
  local_artifacts_folder = "./dist"
  artifact_name          = "${local.function_dir_sha1}.zip"
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = local.function_dir
  output_path = "${local.local_artifacts_folder}/${local.artifact_name}"
}

resource "google_storage_bucket_object" "build_artifact" {
  name   = "builds/workflow-trigger/${local.artifact_name}"
  bucket = google_storage_bucket.artifact_bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_service_account" "workflow_trigger" {
  account_id   = "workflow-trigger-sa${local.app_suffix}"
  display_name = "SA for Workflow Trigger function"
}

resource "google_project_iam_member" "workflow_trigger" {
  role   = "roles/workflows.invoker"
  member = "serviceAccount:${google_service_account.workflow_trigger.email}"
}

resource "google_cloudfunctions_function" "function" {
  name = "workflow-trigger${local.app_suffix}"

  description = "Triggers PDF redaction workflow"
  runtime     = "python39"

  entry_point           = "handler"
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.artifact_bucket.name
  source_archive_object = google_storage_bucket_object.build_artifact.name
  service_account_email = google_service_account.workflow_trigger.email

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.pdf_input_bucket.name
  }

  environment_variables = {
    WORKFLOW_ID = google_workflows_workflow.pdf_redactor.id
  }

  depends_on = [
    module.project_services,
  ]
}
