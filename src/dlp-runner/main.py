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

import datetime
import json
import mimetypes
import os
import uuid

from flask import Flask, request, jsonify
from google.cloud import storage
import google.cloud.dlp
import proto

app = Flask(__name__)

# Initiate GCP clients
dlp_client = google.cloud.dlp_v2.DlpServiceClient()
storage_client = storage.Client()


@app.route("/", methods=["POST"])
def handle_post():
    # Read inputs
    req = request.get_json()
    project_id = req["project_id"]
    input_file = req["input_file"]
    input_file_bucket = req["input_file_bucket"]
    output_file = req["output_file"]
    output_file_bucket = req["output_file_bucket"]
    dlp_template = req["dlp_template"]
    include_quotes_in_findings = req["include_quote_in_findings"]
    findings_labels = req["findings_labels"]

    try:
        result = process_image(input_file_bucket=input_file_bucket,
                               input_file=input_file,
                               output_file_bucket=output_file_bucket,
                               output_file=output_file,
                               project=project_id,
                               inspect_template=dlp_template,
                               include_quotes=include_quotes_in_findings,
                               labels=findings_labels)
        return jsonify(result)
    except Exception as e:
        print(f"error: {e}")
        return ("", 500)


def process_image(input_file_bucket, input_file, output_file_bucket,
                  output_file, project, inspect_template, include_quotes,
                  labels):
    # declare names for temporary files
    name, ext = os.path.splitext(os.path.basename(input_file))
    hash = str(uuid.uuid4())
    tmp_file = f"{hash}{ext}"
    tmp_file_redacted = f"{hash}-redacted{ext}"

    # download file from bucket
    print(f"Downloading input file from gs://{input_file_bucket}/{input_file}")
    input_bucket_client = storage_client.get_bucket(input_file_bucket)
    blob_pdf = input_bucket_client.get_blob(input_file)
    blob_pdf.download_to_filename(tmp_file)
    print(f"Input file downloaded from GCS to {tmp_file}")

    # redact file using DLP
    findings = redact_image(project, tmp_file, tmp_file_redacted,
                            inspect_template, include_quotes)
    print(f"Redacted image saved to file {tmp_file_redacted}")

    # upload redacted image to bucket
    output_bucket_client = storage_client.get_bucket(output_file_bucket)
    out_blob = output_bucket_client.blob(output_file)
    out_blob.upload_from_filename(tmp_file_redacted)
    print(
        f"Redacted image uploaded to gs://{output_file_bucket}/{output_file}")

    for f in findings:
        # Create time is not properly parsed to match BQ table, so we need to pass from a string
        # datetime into BQ's structure for create_time (create_time.seconds and create_time.nanos)
        # Workaround: The [0:19] was added to trim the string to the first 20 characters,
        # this cuts off the milliseconds, as the API omits 000 when at the round second.
        create_time = datetime.datetime.strptime(f["create_time"][0:19],
                                                 '%Y-%m-%dT%H:%M:%S')

        f["create_time"] = {"seconds": create_time.strftime('%s'), "nanos": 0}
        f["location"]["container"] = {
            "project_id": project,
            "full_path": f"gs://{input_file_bucket}/{input_file}"
        }

        if labels and len(labels) > 0:
            f["labels"] = []
            for key in labels:
                f["labels"].append({"key": key, "value": labels[key]})
        else:
            f.pop("labels")

    # upload findings to cloud storage
    findings_file = output_file.replace(ext, ".json")
    out_blob = output_bucket_client.blob(findings_file)
    out_blob.upload_from_string(data=json.dumps(findings),
                                content_type='application/json')
    print(
        f"Redaction metadata successfully uploaded to gs://{output_file_bucket}/{findings_file}"
    )

    # Cleanup local files
    os.remove(tmp_file)
    os.remove(tmp_file_redacted)

    return {
        "redacted_image": {
            "bucket": output_file_bucket,
            "file": output_file
        },
        "findings": {
            "bucket": output_file_bucket,
            "file": findings_file
        }
    }


def redact_image(
    project,
    input_filename,
    output_filename,
    inspect_template,
    include_quotes,
    mime_type=None,
):
    """
    Taken from https://github.com/googleapis/python-dlp/blob/master/samples/snippets/redact.py

    Uses the Data Loss Prevention API to redact protected data in an image.
    Args:
        project: The Google Cloud project id to use as a parent resource.
        filename: The path to the file to inspect.
        output_filename: The path to which the redacted image will be written.
        info_types: A list of strings representing info types to look for.
            A full list of info type categories can be fetched from the API.
        inspect_template: The DLP template with the inspection/redaction configuration
            (INFO_TYPES, Likelihood, etc.)
        mime_type: The MIME type of the file. If not specified, the type is
            inferred via the Python standard library's mimetypes module.
    Returns:
        None; the response from the API is printed to the terminal.
    """
    # If mime_type is not specified, guess it from the filename.
    if mime_type is None:
        mime_guess = mimetypes.MimeTypes().guess_type(input_filename)
        mime_type = mime_guess[0] or "application/octet-stream"

    # Select the content type index from the list of supported types.
    supported_content_types = {
        None: 0,  # "Unspecified"
        "image/jpeg": 1,
        "image/bmp": 2,
        "image/png": 3,
        "image/svg": 4,
        "text/plain": 5,
    }
    content_type_index = supported_content_types.get(mime_type, 0)

    # Construct the byte_item, containing the file's byte data.
    with open(input_filename, mode="rb") as f:
        byte_item = {"type_": content_type_index, "data": f.read()}

    # Convert the project id into a full resource id.
    parent = f"projects/{project}"

    # As of today, Python SDK doesn't support passing the DLP Inspect Template directly for Image Redactions
    # So we will work around that by reading the InfoTypes and configurations from the Template and provide them to the RedactImage method
    inspect_template = dlp_client.get_inspect_template(name=inspect_template)

    # Include quote (redacted data) in findings result
    inspect_template.inspect_config.include_quote = include_quotes

    # Call the API
    response = dlp_client.redact_image(
        request={
            "parent": parent,
            "inspect_config": inspect_template.inspect_config,
            "byte_item": byte_item,
            "include_findings": True
        })

    # Write out the redacted image to local disk
    with open(output_filename, mode="wb") as f:
        f.write(response.redacted_image)

    return proto.Message.to_dict(response.inspect_result)["findings"]


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
