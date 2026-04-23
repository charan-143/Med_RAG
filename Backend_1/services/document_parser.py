from db.vector_store import pdf_knowledge_base
from agno.knowledge.reader.pdf_reader import PDFReader

def load_documents_to_db(file_path: str, original_name: str):
    """
    Reads a PDF, tags chunks with original filename for better RAG retrieval,
    and filters out empty parts to avoid Gemini API errors.
    """
    reader = PDFReader()
    documents = reader.read(pdf=file_path)
    
    # Filter and enrich with metadata
    valid_documents = []
    for d in documents:
        if d.content and d.content.strip():
            # Tag with original name so the LLM can find it by literal filename search
            d.meta_data["original_name"] = original_name
            valid_documents.append(d)
    
    if valid_documents:
        # Knowledge.insert doesn't accept a list of Documents in this version.
        # We manually use the vector_db to insert our filtered/tagged chunks.
        import hashlib
        with open(file_path, "rb") as f:
            pdf_bytes = f.read()
        content_hash = hashlib.md5(pdf_bytes).hexdigest()
        pdf_knowledge_base.vector_db.insert(content_hash=content_hash, documents=valid_documents)
    else:
        import logging
        logging.getLogger(__name__).warning(f"No extractable text found in {original_name}. Skipping vectorization.")
