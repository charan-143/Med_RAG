from agents.routing_agent import create_medical_team_agent
from agno.team import Team

def get_medical_team_router() -> Team:
    """
    Dependency Injection provider.
    Defaults to a stateless/generic session pool for background workers (like Vault AI Summaries).
    """
    return create_medical_team_agent(session_id="stateless_api_worker")
