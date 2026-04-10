from db.vector_store import pdf_knowledge_base
from agno.knowledge.reader.pdf_reader import PDFReader

def load_documents_to_db(file_path: str):
    """
    Reads a single PDF and loads it into LanceDB natively reading text chunks.
    """
    pdf_knowledge_base.insert(path=file_path, reader=PDFReader())
