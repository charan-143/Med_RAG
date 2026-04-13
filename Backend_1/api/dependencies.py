from agents.routing_agent import medical_team_agent
from agno.team import Team

def get_medical_team_router() -> Team:
    """
    Dependency Injection provider.
    Supplies the centralized Supervisor routing Team to endpoints cleanly,
    eliminating global variable leaks and facilitating clean unit testing.
    """
    return medical_team_agent
