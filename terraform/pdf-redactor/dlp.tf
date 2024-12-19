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

# This file defines the DLP (Data Loss Prevention) Inspect Template used for PDF redaction.
#
# The inspect template defines what types of sensitive information (infoTypes) to look for in the documents.
# It includes built-in infoTypes (like email addresses, phone numbers) and custom infoTypes defined using
# dictionaries or regular expressions.
#
# To modify this configuration:
# 1. **Add new infoTypes:**
#    - Add a new `info_types` block within the `inspect_config` section.
#    - Set the `name` attribute to the desired built-in infoType (e.g., "CREDIT_CARD_NUMBER").
#    - Refer to the DLP documentation for a list of available built-in infoTypes:
#      https://cloud.google.com/dlp/docs/infotypes-reference
# 2. **Add custom infoTypes using dictionaries:**
#    - Add a new `custom_info_types` block.
#    - Set the `info_type` name and `exclusion_type` (if it's an exclusion).
#    - Define a `dictionary` with a `word_list` containing the terms to match.
# 3. **Add custom infoTypes using regular expressions:**
#    - Add a new `custom_info_types` block.
#    - Set the `info_type` name, `exclusion_type` (if it's an exclusion), and `likelihood`.
#    - Define a `regex` with the desired `pattern`.
# 4. **Modify likelihood settings:**
#    - Adjust the `likelihood` attribute for each infoType to control the sensitivity of detection.
#    - Possible values: LIKELIHOOD_UNSPECIFIED, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY
#    - Higher likelihood values increase the chance of detection but may also increase false positives.
# 5. **Modify regular expressions:**
#    - Adjust the `pattern` attribute within a `regex` block to change the matching behavior.
#    - Refer to regular expression documentation for syntax and options.
#
# After making changes, run `terraform apply` to update the DLP Inspect Template.

resource "google_data_loss_prevention_inspect_template" "dlp_pdf_template" {
  parent       = "projects/${var.project_id}/locations/global"
  description  = "PDF Redaction Inspect Template"
  display_name = "pdf_redaction_dlp_template"

  inspect_config {
    info_types {
      # Detects email addresses.
      name = "EMAIL_ADDRESS"
    }
    info_types {
      # Detects person names (broad category).
      name = "PERSON_NAME"
    }
    info_types {
      # Detects last names.
      name = "LAST_NAME"
    }
    info_types {
      # Detects phone numbers.
      name = "PHONE_NUMBER"
    }
    info_types {
      # Detects first names.
      name = "FIRST_NAME"
    }
    custom_info_types {
      info_type {
        # This custom infoType is used to exclude "Foley catheter" from being detected as a person's name.
        name = "FOLEY_CATHETER"
      }
      # This sets the exclusion type to EXCLUDE, meaning it will prevent the term from being flagged.
      exclusion_type = "EXCLUSION_TYPE_EXCLUDE"
      dictionary {
        word_list {
          words = ["Foley catheter"]
        }
      }
    }
    custom_info_types {
      info_type {
        # This custom infoType uses a regex to exclude names with "MD" before or after them.
        # This helps prevent false positives for doctor's names, which are not considered PHI in this context.
        # The regex matches patterns like "Dr. John Smith, MD" or "Jane Doe MD".
        name = "NAMES_WITH_MD"
      }
      exclusion_type = "EXCLUSION_TYPE_EXCLUDE"
      regex {
        pattern = "(?i)(Dr\\.|MD)?\\s*[A-Z][a-z]+\\s+[A-Z][a-z]+\\s*(MD|M\\.D\\.)?" 
      }
    }
    custom_info_types {
      info_type {
        # This custom infoType detects case numbers that start with E000.
        # The likelihood is set to LIKELIHOOD_UNLIKELY because they might not always be present.
        name = "CASE_NUMBER"
      }
      likelihood = "LIKELIHOOD_UNLIKELY"
      regex {
        pattern = "E000[a-zA-Z0-9\\-]*"
      }
      
    }


  }

  depends_on = [
    module.project_services,
  ]
}
