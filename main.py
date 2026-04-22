from agents.analyser import analyser_agent
from agents.planner import planner_agent
from agents.mongodb_agent import mongodb_agent
from agents.node_agent import node_agent
from agents.flutter_agent import flutter_agent

user_input = "Build a food delivery app"

analysis = analyser_agent(user_input)
print("Analysis:", analysis)

plan = planner_agent(analysis)
print("Plan:", plan)

db = mongodb_agent(plan)
print("DB:", db)

backend = node_agent(plan)
print("Backend:", backend)

frontend = flutter_agent(plan)
print("Frontend:", frontend)