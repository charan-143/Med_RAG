from agents.routing_agent import medical_team_agent
from agno.agent import Agent

def get_medical_team_router() -> Agent:
    """
    Dependency Injection provider. 
    Supplies the centralized Supervisor routing agent to endpoints cleanly, 
    eliminating global variable leaks and facilitating clean unit testing.
    """
    return medical_team_agent

