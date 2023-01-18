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

# resource "google_storage_bucket" "artifact_bucket" {
#   location                    = var.region
#   name                        = "pdf-redaction-artifacts-${local.app_suffix}"
#   uniform_bucket_level_access = true
# }

# locals {
#   function_dir           = "${path.module}/../../src/workflow-trigger"
#   function_dir_sha1      = sha1(join("", [for f in fileset(local.function_dir, "**") : filesha1("${local.function_dir}/${f}")]))
#   local_artifacts_folder = "./dist"
#   artifact_name          = "${local.function_dir_sha1}.zip"
# }

# data "archive_file" "function_zip" {
#   type        = "zip"
#   source_dir  = local.function_dir
#   output_path = "${local.local_artifacts_folder}/${local.artifact_name}"
# }

# resource "google_storage_bucket_object" "build_artifact" {
#   name   = "builds/workflow-trigger/${local.artifact_name}"
#   bucket = google_storage_bucket.artifact_bucket.name
#   source = data.archive_file.function_zip.output_path
# }

resource "google_service_account" "workflow_trigger" {
  account_id   = "workflow-trigger-sa${local.app_suffix}"
  display_name = "SA for Workflow Trigger function"
}

resource "google_project_iam_member" "workflow_trigger_workflow_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.workflow_trigger.email}"
}
resource "google_project_iam_member" "workflow_trigger_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.workflow_trigger.email}"
}

# GCP creates a special SA for GCS that needs to be granted pub/sub permissions
# ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account
data "google_project" "project" {
}
data "google_storage_project_service_account" "gcs_account" {
}
locals {
    pubsub_default_sa_email = "service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "gcs_sa_to_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_project_iam_member" "pubsub_sa_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${local.pubsub_default_sa_email}"
}

# resource "google_cloudfunctions_function" "function" {
#   name = "workflow-trigger${local.app_suffix}"

#   description = "Triggers PDF redaction workflow"
#   runtime     = "python39"

# entry_point           = "handler"
# available_memory_mb   = 128
# source_archive_bucket = google_storage_bucket.artifact_bucket.name
# source_archive_object = google_storage_bucket_object.build_artifact.name
# service_account_email = google_service_account.workflow_trigger.email
# ingress_settings      = "ALLOW_INTERNAL_AND_GCLB"

#   event_trigger {
#     event_type = "google.storage.object.finalize"
#     resource   = google_storage_bucket.pdf_input_bucket.name
#   }

#   environment_variables = {
#     WORKFLOW_ID = google_workflows_workflow.pdf_redactor.id
#   }

#   depends_on = [
#     module.project_services,
#   ]
# }

resource "google_eventarc_trigger" "primary" {
  name            = "workflow-trigger${local.app_suffix}"
  location        = var.region
  service_account = google_service_account.workflow_trigger.email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.pdf_input_bucket.name
  }
  destination {
    workflow = google_workflows_workflow.pdf_redactor.name
  }

  depends_on = [
    module.project_services,
    google_project_iam_member.gcs_sa_to_pubsub,
    google_project_iam_member.pubsub_sa_token_creator,
    google_project_iam_member.workflow_trigger_workflow_invoker,
    google_project_iam_member.workflow_trigger_event_receiver
  ]
}
