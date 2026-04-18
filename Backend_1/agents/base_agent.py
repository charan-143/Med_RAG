from agno.agent import Agent
from agno.models.google import Gemini
from core.config import settings

def create_base_medical_agent(
    name: str = "Base Medical Agent",
    role: str = "Medical Assistant",
    instructions: list = None,
    knowledge_base = None,
) -> Agent:
    """
    Factory function to securely initialize a baseline Medical API Agent.
    This ensures all future specialized sub-agents natively inherit strict diagnostic parameters!
    """
    default_instructions = [
        "Always maintain a strict, professional clinic demeanor.",
        "Always remind the user to consult a true medical professional for diagnosis.",
        "Do not hallucinate medical statistics."
    ]
    
    if instructions:
        default_instructions.extend(instructions)
        
    return Agent(
        name=name,
        role=role,
        model=Gemini(id="gemma-4-31b-it", api_key=settings.GOOGLE_API_KEY),
        knowledge=knowledge_base,
        search_knowledge=True if knowledge_base else False,
        markdown=True,
        instructions=default_instructions
    )
