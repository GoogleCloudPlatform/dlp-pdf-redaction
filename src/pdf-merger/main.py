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
from PyPDF2 import PdfFileMerger
import pytesseract

app = Flask(__name__)

# Initiate GCP clients
storage_client = storage.Client()


@app.route("/", methods=["POST"])
def handle_post():
    # Read inputs
    req = request.get_json()
    files_bucket = req["files_bucket"]
    files_to_concatenate = req["files_to_concatenate"]
    output_file = req["output_file"]
    output_file_bucket = req["output_file_bucket"]

    try:
        result = concatenate_images_into_pdf(
            files_bucket=files_bucket,
            files_to_concatenate=files_to_concatenate,
            output_bucket=output_file_bucket,
            output_file=output_file)
        return jsonify(result)
    except Exception as e:
        print(f"error: {e}")
        return ("", 500)


def concatenate_images_into_pdf(files_bucket, files_to_concatenate,
                                output_bucket, output_file):
    # Download all images
    print(
        f"Images to concatenate: {files_to_concatenate} from bucket: {files_bucket}"
    )

    pdf_merger = PdfFileMerger()
    for file in files_to_concatenate.split(","):
        # Skip if this is not a valid image filename
        file = file.strip()
        if not file:
            continue

        # Download image
        temp_image_name = f"{str(uuid.uuid4())}.jpg"
        files_bucket = storage_client.get_bucket(files_bucket)
        blob = files_bucket.get_blob(file)
        blob.download_to_filename(temp_image_name)
        print(f"Downloaded file {file}")

        # Make image searcheable and add it to the main PDF
        searchable_page_pdf = pytesseract.image_to_pdf_or_hocr(temp_image_name,
                                                               extension='pdf')
        searchable_page_pdf_file = f"{str(uuid.uuid4())}.pdf"
        with open(searchable_page_pdf_file, 'w+b') as f:
            f.write(searchable_page_pdf)
        pdf_merger.append(searchable_page_pdf_file)

        # Cleanup local files
        os.remove(temp_image_name)
        os.remove(searchable_page_pdf_file)

    # Write searchable pdf to disk and upload to GCS
    searchable_concatenated_pdf = f"{str(uuid.uuid4())}.pdf"
    pdf_merger.write(searchable_concatenated_pdf)

    # Upload final concatenated PDF to bucket
    files_bucket = storage_client.get_bucket(output_bucket)
    out_blob = files_bucket.blob(output_file)
    out_blob.upload_from_filename(searchable_concatenated_pdf)
    print(
        f"Searchable concatenated PDF uploaded to: gs://{output_bucket}/{output_file}"
    )

    # Cleanup local files
    os.remove(searchable_concatenated_pdf)

    # result
    return {
        "full_file": f"gs://{output_bucket}/{output_file}",
        "file": output_file,
        "bucket": output_bucket
    }


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
