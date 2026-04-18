from agno.agent import Agent
from agno.team import Team
from agno.models.google import Gemini
from agents.base_agent import create_base_medical_agent
from db.vector_store import pdf_knowledge_base
from core.config import settings

# --- 1. The Clinical Analyst ---
# Responsible entirely for heavy text RAG (Vector Lookups)
clinical_analyst = create_base_medical_agent(
    name="Clinical Records Analyst",
    role="Expert at retrieving patient data from PDF documents and summarizing clinical context.",
    instructions=[
        "First, check the 'User context' provided in the prompt for a list of specific documents and their summaries.",
        "Then, you MUST call `search_knowledge_base` to retrieve deeper context from the indexed text parts of those specific documents.",
        "Ground your answers STRICTLY in the provided summaries AND the retrieved text chunks.",
    ],
    knowledge_base=pdf_knowledge_base
)

# --- 2. The Radiologist ---
# Focuses heavily on Image descriptions (Images are passed directly, no PDF context)
radiologist = create_base_medical_agent(
    name="Radiologist Expert",
    role="Image Diagnostics Expert analyzing X-rays, MRIs, and medical imagery.",
    instructions=[
        "You analyze uploaded medical imagery carefully.",
        "Describe visible anomalies, texture, patterns, and shape, but refuse to make a final absolute diagnosis.",
    ]
)

# --- 3. Supervisor Orchestrator ---
# agno v2.x uses agno.team.Team for multi-agent orchestration, not Agent(team=[...])
medical_team_agent = Team(
    name="Medical Supervisor System",
    members=[clinical_analyst, radiologist],
    model=Gemini(id="gemma-4-31b-it", api_key=settings.GOOGLE_API_KEY),
    instructions=[
        "You are the orchestrating supervisor for a world-class diagnostic clinic team.",
        "If the user uploaded an image, heavily delegate the visual inquiry to the Radiologist Expert.",
        "If the user asks a question requiring document context, delegate the heavy lookup to the Clinical Records Analyst.",
        "Synthesize and answer the user clearly with the results from the specialized team members without technical jargon."
    ],
    markdown=True
)
