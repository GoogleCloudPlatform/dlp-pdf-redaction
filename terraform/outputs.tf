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

output "workflow_name" {
  value       = module.pdf_redactor.workflow_name
  description = "Workflow that orchestrated the redaction of a single PDF file"
}

output "pdf_input_bucket" {
  value       = module.pdf_redactor.pdf_input_bucket
  description = "Bucket that will be used to drop/land your raw pfd files for redaction."
}

output "pdf_output_bucket" {
  value       = module.pdf_redactor.pdf_output_bucket
  description = "Bucket that will be used to output your processed pfd files after redaction."
}
