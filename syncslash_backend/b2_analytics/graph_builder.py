"""
graph_builder.py — Neo4j Knowledge Graph Builder for Subscription Analytics
This module syncs user subscription data from PostgreSQL into a Neo4j
Knowledge Graph, then uses Cypher queries to detect content/category
redundancy across a user's subscriptions.
Graph Model:
  (:User {user_id})
      -[:SUBSCRIBED_TO {cost, status}]->
  (:Service {name, base_cost})
      -[:BELONGS_TO]->
  (:Category {name})
Key Cypher Patterns:
  - Redundancy: Find all categories where a user has 2+ services
  - Overlap:    Compare services within the same category
"""

from backend.db.neo4j_connection import db_neo4j
from backend.db.connection import run_query

def sync_services_to_graph():
    """
    One-time (or periodic) sync of the Services master table
    into Neo4j as (:Service) and (:Category) nodes.
    Why MERGE instead of CREATE?
      MERGE = "find or create". If the node already exists,
      it won't duplicate it. This makes the function idempotent —
      safe to call multiple times without side effects.
    """
    services = run_query(
        "SELECT service_id, service_name, category, base_cost_inr FROM Services"
    )

    for svc in services:
        
        db_neo4j.query(
            """
            MERGE (c:Category {name: $category})
            """,
            parameters={"category": svc["category"]}
        )

        db_neo4j.query(
            """
            MERGE (s:Service {service_id: $sid})
            SET s.name = $name,
                s.base_cost = $cost
            WITH s
            MATCH (c:Category {name: $category})
            MERGE (s)-[:BELONGS_TO]->(c)
            """,
            parameters={
                "sid": svc["service_id"],
                "name": svc["service_name"],
                "cost": float(svc["base_cost_inr"]) if svc["base_cost_inr"] else 0,
                "category": svc["category"]
            }
        )

    return len(services)

def sync_user_graph(user_id: int):
    """
    Syncs a specific user's subscriptions into the Knowledge Graph.
    Steps:
      1. Create/update the (:User) node
      2. Fetch the user's active subscriptions from Postgres
      3. Create [:SUBSCRIBED_TO] edges from User → Service
    Why sync on-demand and not in real-time?
      Real-time sync (via DB triggers or CDC) adds complexity.
      For a demo/university project, syncing when the user
      hits the /analytics endpoint is sufficient and simpler.
      In production, you'd use Debezium or a Change Data Capture
      pipeline to stream Postgres changes into Neo4j.
    """
    
    sync_services_to_graph()

    db_neo4j.query(
        """
        MERGE (u:User {user_id: $uid})
        """,
        parameters={"uid": user_id}
    )

    subs = run_query(
        """
        SELECT
            s.sub_id,
            s.service_id,
            s.detected_cost,
            s.status,
            sv.service_name,
            sv.category,
            COALESCE(usm.usage_count, 0) AS usage_count
        FROM Subscriptions s
        JOIN Services sv ON s.service_id = sv.service_id
        LEFT JOIN User_Subscription_Mapping usm
            ON s.sub_id = usm.sub_id AND s.user_id = usm.user_id
        WHERE s.user_id = %s AND s.status = 'active'
        """,
        params=(user_id,)
    )

    db_neo4j.query(
        """
        MATCH (u:User {user_id: $uid})-[r:SUBSCRIBED_TO]->()
        DELETE r
        """,
        parameters={"uid": user_id}
    )

    for sub in subs:
        db_neo4j.query(
            """
            MATCH (u:User {user_id: $uid})
            MATCH (s:Service {service_id: $sid})
            MERGE (u)-[r:SUBSCRIBED_TO]->(s)
            SET r.cost = $cost,
                r.status = $status,
                r.usage_count = $usage
            """,
            parameters={
                "uid": user_id,
                "sid": sub["service_id"],
                "cost": float(sub["detected_cost"]) if sub["detected_cost"] else 0,
                "status": sub["status"],
                "usage": sub["usage_count"]
            }
        )

    return len(subs)

def calculate_redundancy(user_id: int):
    """
    Uses the Knowledge Graph to find categories where the user
    has MORE than one active subscription — i.e., redundancy.
    Cypher Strategy:
      1. Start from the User node
      2. Traverse SUBSCRIBED_TO → Service → BELONGS_TO → Category
      3. GROUP BY Category
      4. HAVING count(services) >= 2
      5. Return the overlapping services with cost data
    Why Neo4j instead of plain SQL for this?
      You CAN do this in SQL with JOINs and GROUP BY.
      But the graph model makes it:
        - More intuitive to query (path traversals vs multi-joins)
        - Extensible: later you can add (:Content) nodes with
          [:AVAILABLE_ON] edges for true content-level overlap,
          not just category-level.
        - Demonstrable: your professor sees a Knowledge Graph,
          which is a novel DBMS concept beyond basic relational.
    """

    sync_user_graph(user_id)

    results = db_neo4j.query(
        """
        MATCH (u:User {user_id: $uid})-[r:SUBSCRIBED_TO]->(s:Service)-[:BELONGS_TO]->(c:Category)
        WITH c, collect({
            name: s.name,
            cost: r.cost,
            usage: r.usage_count,
            service_id: s.service_id
        }) AS services, sum(r.cost) AS total_cost
        WHERE size(services) >= 2
        RETURN
            c.name          AS category,
            size(services)  AS overlap_count,
            total_cost      AS combined_cost,
            services        AS overlapping_services
        ORDER BY total_cost DESC
        """,
        parameters={"uid": user_id}
    )

    if not results:
        return {
            "user_id": user_id,
            "has_redundancy": False,
            "message": "No overlapping subscriptions found. Your subscriptions are well-diversified!",
            "overlaps": []
        }

    overlaps = []
    total_waste = 0.0

    for record in results:
        category = record["category"]
        services = record["overlapping_services"]
        combined_cost = record["combined_cost"]
        overlap_count = record["overlap_count"]

        sorted_services = sorted(services, key=lambda x: x["cost"])
        cheapest = sorted_services[0]
        potential_saving = combined_cost - cheapest["cost"]
        total_waste += potential_saving

        service_names = [s["name"] for s in services]
        
        most_used = max(services, key=lambda x: x["usage"])

        recommendation = (
            f"You have {overlap_count} {category} services "
            f"({', '.join(service_names)}) costing ₹{combined_cost:.0f}/mo total. "
            f"Your most-used is {most_used['name']}. "
            f"Consider keeping only {most_used['name']} to save ₹{potential_saving:.0f}/mo."
        )

        overlaps.append({
            "category": category,
            "overlap_count": overlap_count,
            "services": services,
            "combined_monthly_cost": combined_cost,
            "potential_monthly_saving": potential_saving,
            "most_used_service": most_used["name"],
            "recommendation": recommendation
        })

    return {
        "user_id": user_id,
        "has_redundancy": True,
        "total_redundant_categories": len(overlaps),
        "total_potential_savings": total_waste,
        "overlaps": overlaps
    }

def get_full_graph(user_id: int):
    """
    Returns the complete graph structure for a user — useful for
    visualization on the frontend (e.g., with D3.js or vis.js).
    Returns nodes and edges in a format ready for graph rendering.
    """
    sync_user_graph(user_id)

    results = db_neo4j.query(
        """
        MATCH (u:User {user_id: $uid})-[r:SUBSCRIBED_TO]->(s:Service)-[b:BELONGS_TO]->(c:Category)
        RETURN
            u.user_id       AS user_id,
            s.name          AS service_name,
            s.service_id    AS service_id,
            r.cost          AS cost,
            r.usage_count   AS usage_count,
            r.status        AS status,
            c.name          AS category
        """,
        parameters={"uid": user_id}
    )

    if not results:
        return {"nodes": [], "edges": []}

    nodes = []
    edges = []
    seen_nodes = set()

    user_node_id = f"user_{user_id}"
    nodes.append({"id": user_node_id, "label": f"User {user_id}", "type": "user"})
    seen_nodes.add(user_node_id)

    for record in results:
        
        svc_id = f"service_{record['service_id']}"
        if svc_id not in seen_nodes:
            nodes.append({
                "id": svc_id,
                "label": record["service_name"],
                "type": "service",
                "cost": record["cost"]
            })
            seen_nodes.add(svc_id)

        cat_id = f"category_{record['category']}"
        if cat_id not in seen_nodes:
            nodes.append({
                "id": cat_id,
                "label": record["category"],
                "type": "category"
            })
            seen_nodes.add(cat_id)

        edges.append({
            "from": user_node_id,
            "to": svc_id,
            "label": "SUBSCRIBED_TO",
            "cost": record["cost"],
            "usage": record["usage_count"]
        })
        edges.append({
            "from": svc_id,
            "to": cat_id,
            "label": "BELONGS_TO"
        })

    return {"nodes": nodes, "edges": edges}