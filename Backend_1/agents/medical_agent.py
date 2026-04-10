from agno.agent import Agent
from agno.models.google import Gemini
from db.vector_store import pdf_knowledge_base
from core.config import settings

# Make sure GOOGLE_API_KEY is in your environment or .env
medical_agent = Agent(
    model=Gemini(id="gemma-4-31b-it", api_key=settings.GOOGLE_API_KEY),
    knowledge=pdf_knowledge_base,
    search_knowledge=True,
    markdown=True,
    description="You are a highly skilled Medical AI assistant. You act as a radiologist, diagnostician, and medical expert.",
    instructions=[
        "Always be professional.",
        "Whenever a user asks a question, YOU MUST call the `search_knowledge_base` tool to retrieve relevant context from the PDF uploads.",
        "Do NOT simply answer from your base training data. You MUST GROUND your responses in the medical context returned by the tool.",
        "If analyzing an X-ray or image, describe abnormalities clearly but always remind the user to consult a true medical professional.",
        "Do not invent medical facts."
    ],
)
