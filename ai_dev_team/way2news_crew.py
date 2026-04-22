import os
from crewai import Agent, Task, Crew, Process, LLM
from crewai_tools import DirectoryReadTool, FileReadTool
# ==========================================
# 1. CONFIGURATION
# ==========================================

OLLAMA_OPENAI_BASE_URL = os.getenv("OLLAMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.1:latest")

# Avoid interactive tracing/telemetry prompts in non-interactive runs.
os.environ.setdefault("CREWAI_DISABLE_TELEMETRY", "true")
os.environ.setdefault("CREWAI_DISABLE_TRACING", "true")
os.environ.setdefault("OTEL_SDK_DISABLED", "true")


# CrewAI's OpenAI-compatible client needs an API key string, even for local Ollama.
os.environ.setdefault("OPENAI_API_KEY", "ollama")

llm = LLM(
    model=OLLAMA_MODEL,
    base_url=OLLAMA_OPENAI_BASE_URL,
    api_key=os.environ["OPENAI_API_KEY"],
)


print("## Initializing Way2News Development Team...")
docs_tool = DirectoryReadTool(directory='./flutter_app')
file_tool = FileReadTool()


# ==========================================
# 2. AGENT DEFINITIONS
# ==========================================

analyst = Agent(
    role="Senior Mobile App Analyst",
    goal="Analyze requirements for a Way2News style application",
    backstory="""You are an expert in news aggregation apps. You understand the importance 
    of categorized feeds, fast loading times, and clean UI similar to Way2News or InShorts.""",
    verbose=True,
    allow_delegation=False,
    llm=llm,
)

planner = Agent(
    role="MERN & Flutter Architect",
    goal="Design the database schema and API structure for a news app",
    backstory="""You design scalable architectures for mobile apps. You specialize in 
    MongoDB for storing articles and Node.js for high-performance APIs. 
    You know how to structure Flutter apps for scalability.""",
    verbose=True,
    allow_delegation=False,
    llm=llm,
)

backend_dev = Agent(
    role="Node.js Backend Developer",
    goal="Write robust backend code for news management",
    backstory="""You are a Node.js specialist. You write clean Express servers, 
    Mongoose schemas, and RESTful APIs. You ensure data is served quickly to mobile clients.""",
    verbose=True,
    allow_delegation=False,
    llm=llm,
    tools=[docs_tool, file_tool],
)

flutter_dev = Agent(
    role="Flutter UI Developer",
    goal="Build a pixel-perfect Way2News style UI",
    backstory="""You are a Flutter expert obsessed with clean UI. You excel at 
    building list views, category tabs, and card widgets that look professional 
    and match design specs exactly.""",
    verbose=True,
    allow_delegation=False,
    llm=llm,
    tools=[docs_tool, file_tool],
)

# ==========================================
# 3. TASK DEFINITIONS
# ==========================================

analysis_task = Task(
    description="""
    Analyze the project idea: '{project_idea}'.
    
    Produce a detailed feature list focusing on:
    1. User Experience (UX) requirements for a news reader.
    2. Data structure requirements (Categories, Articles, Sources).
    3. Functional requirements (Filtering by category, Infinite scroll).
    """,
    expected_output="A detailed Feature Specification Document.",
    agent=analyst,
)

planning_task = Task(
    description="""
    Based on the analysis, create the Technical Architecture Plan.
    
    1. MongoDB Schema: Define the `Article` model fields (title, img, category, etc).
    2. API Routes: Define endpoints to GET articles by category and POST new articles.
    3. Flutter Structure: Define the screens and widgets needed to mimic the UI style.
    """,
    expected_output="A technical blueprint with Database Schema, API Routes, and UI Component Tree.",
    agent=planner,
    context=[analysis_task],
)

backend_task = Task(
    description="""
    Write the complete Backend code (Node.js & MongoDB) based on the Architecture Plan.
    
    Provide full code for:
    1. `models/Article.js` (The Mongoose schema).
    2. `routes/news.js` (The API routes for fetching news by category and posting news).
    3. `server.js` (The main Express app setup with CORS enabled).
    
    Ensure the code is ready to run with a simple `npm start`.
    """,
    expected_output="Complete code blocks for server.js, model, and routes.",
    agent=backend_dev,
    context=[planning_task],
)

flutter_task = Task(
    description="""
    Write the complete Flutter code based on the Architecture Plan.
    
    Provide full code for:
    1. `flutter_app/lib/models/models.dart` (add/extend an `Article`/`NewsPost`-style data class used by the app).
    2. `flutter_app/lib/services/api_service.dart` (add/extend methods to fetch articles by category from the Node backend).
    3. `flutter_app/lib/widgets/news_card.dart` (Way2News-style card: image, bold title, short summary, source, timestamp).
    4. `flutter_app/lib/screens/user/feed_screen.dart` (main feed screen with horizontal category tabs + infinite scroll list).
    
    Ensure the UI uses a TabBar for categories and a ListView.builder for the feed.
    Do not reference placeholder paths like `/path/to/your/project/...` and do not attempt to read files that don't exist.
    """,
    expected_output="Complete code blocks for model, service, card widget, and home screen.",
    agent=flutter_dev,
    context=[planning_task, backend_task],
)

# ==========================================
# 4. CREW ASSEMBLY
# ==========================================

dev_crew = Crew(
    agents=[analyst, planner, backend_dev, flutter_dev],
    tasks=[analysis_task, planning_task, backend_task, flutter_task],
    process=Process.sequential,
    verbose=True,
)

# ==========================================
# 5. EXECUTION
# ==========================================

def run_team(project_idea):
    print(f"\n\n############# KICKOFF: Way2News Clone #############\n")
    
    result = dev_crew.kickoff(inputs={'project_idea': project_idea})
    
    print("\n\n############# FINAL OUTPUT #############")
    print(result)
    
    # Save to file
    filename = "way2news_project_output.md"
    with open(filename, "w") as f:
        f.write(str(result))
    print(f"\nOutput saved to '{filename}'")

if __name__ == "__main__":
    # --- SPECIFIC PROJECT IDEA ---
    my_project_idea = """
    Project: Refactor an existing Flutter News App to replicate the UI/UX and functionality of 'Way2News'.
    
    Current Status: A basic Flutter news app structure exists.
    
    Requirements:
    
    1. UI/UX Style (Way2News Clone):
       - Home Screen: A vertical infinite scroll feed of news cards.
       - Card Design: Each card must have an Image, bold Headline, short summary, source name, and timestamp.
       - Top Navigation: A horizontal scrollable tab bar for categories (e.g., 'Top Stories', 'Politics', 'Sports', 'Cinema').
       - Minimalist design with a white background.
    
    2. Backend (Node.js & MongoDB):
       - Database: MongoDB schema for 'Articles'.
       - API Endpoints: GET articles by category, POST new articles (Admin).
       - Optimized for quick fetching.
    
    3. Flutter Integration:
       - State Management: Provider or Riverpod.
       - Logic: Tab clicks filter the list of articles shown in the feed.
    """
    # -----------------------------
    
    run_team(my_project_idea)
