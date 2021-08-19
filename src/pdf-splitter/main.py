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

import os
import uuid

from flask import Flask, request, jsonify
from google.cloud import storage
from pdf2image import convert_from_path

app = Flask(__name__)

# Initiate GCP clients
storage_client = storage.Client()

# Default DPI
DEFAULT_DPI = 92


@app.route("/", methods=["POST"])
def handle_post():
    # Read inputs
    req = request.get_json()
    input_file = req["input_file"]
    input_file_bucket = req["input_file_bucket"]
    output_bucket = req["output_bucket"]
    output_folder = req["output_folder"]
    dpi = DEFAULT_DPI
    if "dpi" in req:
        try:
            dpi = int(req["dpi"])
        except:
            print(f"Unable to parse 'dpi' param. Defaulting to ${dpi}")

    try:
        images = split_pdf(input_bucket=input_file_bucket,
                           input_file=input_file,
                           output_bucket=output_bucket,
                           output_folder=output_folder,
                           dpi=dpi)
        return jsonify(images)
    except Exception as e:
        print(f"error: {e}")
        return ("", 500)


def split_pdf(input_bucket, input_file, output_bucket, output_folder, dpi):
    print(f"Downloading file: gs://{input_bucket}/{input_file}")

    bucket = storage_client.get_bucket(input_bucket)
    blob = bucket.get_blob(input_file)
    downloaded_filename = str(uuid.uuid4())
    blob.download_to_filename(downloaded_filename)
    print(f"Input file downloaded from GCS to {downloaded_filename}")

    images = convert_from_path(downloaded_filename, dpi)
    uploaded_images = []

    # Save pages as images in the pdf
    bucket = storage_client.get_bucket(output_bucket)
    for i in range(len(images)):
        tmp_name = f"${str(uuid.uuid4())}.jpg"
        images[i].save(tmp_name, 'JPEG')

        # Upload image to GCS
        uploaded_filename = f"{output_folder}/page-{str(i).zfill(4)}.jpg"
        blob = bucket.blob(uploaded_filename)
        blob.upload_from_filename(tmp_name)

        # Keep a list of the uploaded images
        uploaded_images.append(uploaded_filename)
        print(f"Image uploaded to gs://{output_bucket}/{uploaded_filename}")

        # Cleanup local file
        os.remove(tmp_name)

    # Cleanup local file
    os.remove(downloaded_filename)

    return uploaded_images


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
