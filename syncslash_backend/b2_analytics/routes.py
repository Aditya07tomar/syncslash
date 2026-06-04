from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from backend.db.connection import run_query

router = APIRouter(
    prefix="/analytics",
    tags=["B2 — Analytics Engine"]
)

@router.get("/fatigue/{user_id}")
def get_fatigue_scores(user_id: int):
    try:
        rows = run_query(
            "SELECT * FROM GenerateFatigueScore(%s)",
            params=(user_id,)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    if not rows:
        return {
            "user_id": user_id,
            "message": "No active subscriptions found for this user.",
            "scores": []
        }

    total_monthly = sum(float(r["monthly_cost"]) for r in rows)
    avg_fatigue = sum(float(r["fatigue_score"]) for r in rows) / len(rows)
    ghost_count = sum(1 for r in rows if r["usage_count"] == 0)

    return {
        "user_id": user_id,
        "total_monthly_spend": total_monthly,
        "average_fatigue_score": round(avg_fatigue, 2),
        "active_subscriptions": len(rows),
        "ghost_subscriptions": ghost_count,
        "scores": rows
    }

@router.get("/ghosts/{user_id}")
def get_ghost_subscriptions(user_id: int):
    try:
        rows = run_query(
            "SELECT * FROM ghost_subscriptions_view WHERE user_id = %s",
            params=(user_id,)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    total_ghost_cost = sum(float(r["detected_cost"]) for r in rows) if rows else 0

    return {
        "user_id": user_id,
        "ghost_count": len(rows),
        "total_monthly_waste": total_ghost_cost,
        "message": (
            f"You have {len(rows)} ghost subscription(s) costing ₹{total_ghost_cost:.0f}/mo. "
            "These are services you pay for but don't actively use."
            if rows else
            "No ghost subscriptions detected. You're using all your services!"
        ),
        "ghosts": rows
    }

@router.get("/redundancy/{user_id}")
def get_redundancy_analysis(user_id: int):
    try:
        
        rows = run_query("""
            SELECT s2.category,
                   COUNT(*) as service_count,
                   SUM(s.detected_cost) as total_cost,
                   json_agg(json_build_object(
                       'name', s2.service_name,
                       'cost', s.detected_cost,
                       'usage_count', 0
                   )) as services
            FROM Subscriptions s
            JOIN Services s2 ON s.service_id = s2.service_id
            WHERE s.user_id = %s AND s.status = 'active'
            GROUP BY s2.category
            HAVING COUNT(*) >= 2
            ORDER BY SUM(s.detected_cost) DESC
    Returns a comprehensive monthly spending report grouped
    by service category, including ghost counts and savings.
    Builds a knowledge graph structure from PostgreSQL data.
    Returns nodes (user, services, categories) and edges
    for frontend visualization.
            SELECT s.sub_id, s.detected_cost, s.status,
                   s2.service_name, s2.category, s2.service_id
            FROM Subscriptions s
            JOIN Services s2 ON s.service_id = s2.service_id
            WHERE s.user_id = %s
            ORDER BY s2.category, s2.service_name
    Renders an interactive vis.js network diagram of the user's
    Knowledge Graph directly in the browser.
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Subscription Knowledge Graph</title>
        <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
        <style type="text/css">
            body {{ font-family: sans-serif; background-color: #f8f9fa; padding: 20px; }}
            #mynetwork {{
                width: 100%;
                height: 800px;
                border: 1px solid #ddd;
                background-color: white;
                border-radius: 8px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }}
            .header {{ text-align: center; margin-bottom: 20px; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h2>Subscription Topology (User {user_id})</h2>
            <p>Interactive Knowledge Graph powered by Neo4j</p>
        </div>
        <div id="mynetwork"></div>
        <script type="text/javascript">
            // Fetch graph data from our API
            fetch('/analytics/graph/{user_id}')
                .then(response => response.json())
                .then(data => {{
                    const graphData = data.graph;
                    
                    // Transform api nodes to vis.js format
                    const nodes = new vis.DataSet(
                        graphData.nodes.map(n => {{
                            let color = "
                            let shape = "ellipse";
                            
                            if (n.type === 'user') {{
                                color = "#fb7e81";
                                shape = "box";
                            }} else if (n.type === 'category') {{
                                color = "#7BE141";
                                shape = "circle";
                            }}
                            
                            return {{
                                id: n.id,
                                label: n.label + (n.cost ? "\\n₹" + n.cost : ""),
                                color: color,
                                shape: shape,
                                font: {{ multi: 'md', face: 'georgia' }}
                            }};
                        }})
                    );
                    // Transform api edges to vis.js format
                    const edges = new vis.DataSet(
                        graphData.edges.map(e => ({{
                            from: e.from,
                            to: e.to,
                            label: e.label,
                            arrows: 'to',
                            font: {{ align: 'middle' }}
                        }}))
                    );
                    // Provide the data in the vis format
                    const networkData = {{
                        nodes: nodes,
                        edges: edges
                    }};
                    
                    const options = {{
                        physics: {{
                            stabilization: false,
                            barnesHut: {{
                                gravitationalConstant: -8000,
                                springConstant: 0.04,
                                springLength: 95
                            }}
                        }},
                        interaction: {{ hover: true }},
                        nodes: {{
                            borderWidth: 2,
                            shadow: true
                        }},
                        edges: {{
                            width: 2,
                            shadow: true,
                            smooth: {{ type: 'continuous' }}
                        }}
                    }};
                    // Initialize the network!
                    const container = document.getElementById('mynetwork');
                    new vis.Network(container, networkData, options);
                }})
                .catch(err => console.error("Error loading graph:", err));
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)