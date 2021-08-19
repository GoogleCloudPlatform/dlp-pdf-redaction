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

from flask import Flask, request, jsonify
from google.cloud import storage
from google.cloud import bigquery

app = Flask(__name__)

BQ_DATASET = os.getenv("BQ_DATASET")
BQ_TABLE = os.getenv("BQ_TABLE")

if not BQ_DATASET:
    raise Exception("Misconfiguration: Missing 'BQ_DATASET' env")
if not BQ_TABLE:
    raise Exception("Misconfiguration: Missing 'BQ_TABLE' env")

# Initiate GCP clients
storage_client = storage.Client()
bq_client = bigquery.Client()


@app.route("/", methods=["POST"])
def handle_post():
    # Read inputs
    req = request.get_json()
    project_id = req["project_id"]
    files_bucket = req["files_bucket"]
    findings_files = req["findings_files"]

    try:
        result = write_to_bq(input_bucket=files_bucket,
                             findings_files=findings_files,
                             project=project_id)
        return jsonify(result)
    except Exception as e:
        print(f"error: {e}")
        return ("", 500)


def write_to_bq(input_bucket, findings_files, project):
    # Flatten the arrays of findings into a single array
    all_findings = []
    findings_to_write = findings_files.split(",")
    for findings_file in findings_to_write:
        if findings_file:
            print(f"Processing file: {findings_file}")

            # Read findings file from GCS to memory
            bucket = storage_client.get_bucket(input_bucket)
            blob = bucket.get_blob(findings_file)

            # Append findings to all_findings list
            blob_findings = blob.download_as_bytes()
            findings_string = blob_findings.decode('utf-8')

            all_findings = all_findings + json.loads(findings_string)

            print(f"Findings file '{findings_file}' parsed correctly")

    # Configure write out
    full_table_name = f"{project}.{BQ_DATASET}.{BQ_TABLE}"

    # Save to BQ the metadata about redacted fields
    bq_result = bq_client.insert_rows_json(table=full_table_name,
                                           json_rows=all_findings,
                                           ignore_unknown_values=True)

    # Check if write to BQ was successfull
    if (len(bq_result) == 0):
        print(f"Findings inserted in BQ table: {full_table_name}")
    else:
        print(f"BQ insert errors: {bq_result}")


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
