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

import json
import os

from google.cloud.workflows import executions_v1beta

WORKFLOW_ID = os.getenv("WORKFLOW_ID", "")

if not WORKFLOW_ID:
    raise Exception("Misconfiguration: Missing 'WORKFLOW_ID' env")

# Initiate GCP clients
wf_execution_client = executions_v1beta.ExecutionsClient()


def handler(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
        event (dict): Event payload.
            context (google.cloud.functions.Context): Metadata for the event.
    """
    arguments = {"bucket": event['bucket'], "file": event['name']}
    print(
        f"Received file: {arguments['file']}, from bucket: {arguments['bucket']}"
    )

    print(json.dumps(arguments))

    # trigger the workflow
    wf_exec = wf_execution_client.create_execution(request={
        "parent": WORKFLOW_ID,
        "execution": {
            "argument": json.dumps(arguments)
        }
    })

    print(f"Execution created: {wf_exec.name}.")
