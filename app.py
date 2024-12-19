import streamlit as st

st.title("Document Upload App")

uploaded_file = st.file_uploader("Choose a document", type=["pdf", "docx", "txt"])

if uploaded_file is not None:
    st.write("Filename:", uploaded_file.name)
    st.write("File size:", uploaded_file.size, "bytes")
    # You can further process the uploaded file here
    # Example: Display the file content
    # st.write(uploaded_file.getvalue().decode("utf-8"))