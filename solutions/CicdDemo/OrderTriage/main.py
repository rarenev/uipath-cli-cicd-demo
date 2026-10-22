from langgraph.graph import START, StateGraph, END
from pydantic import BaseModel

# Bump this in a PR to show a change flowing DEV -> TEST -> PROD.
RULES_VERSION = "2"

HIGH_VALUE_EUR = 10_000
EXPRESS_COUNTRIES = {"DE", "AT", "RO", "NL", "EN"}


class GraphState(BaseModel):
    order_id: str
    amount_eur: float
    country: str


class GraphOutput(BaseModel):
    order_id: str
    priority: str
    route: str
    rules_version: str


def triage(state: GraphState) -> GraphOutput:
    country = state.country.upper()
    if state.amount_eur >= HIGH_VALUE_EUR:
        priority, route = "high", "manual-review"
    elif country in EXPRESS_COUNTRIES:
        priority, route = "normal", "express"
    else:
        priority, route = "normal", "standard"
    return GraphOutput(
        order_id=state.order_id,
        priority=priority,
        route=route,
        rules_version=RULES_VERSION,
    )


builder = StateGraph(GraphState, output=GraphOutput)

builder.add_node("triage", triage)

builder.add_edge(START, "triage")
builder.add_edge("triage", END)

graph = builder.compile()
