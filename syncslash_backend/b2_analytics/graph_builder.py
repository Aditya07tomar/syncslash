from backend.db.neo4j_connection import db_neo4j
from backend.db.connection import run_query

def sync_services_to_graph():
    services = run_query(
        "SELECT service_id, service_name, category, base_cost_inr FROM Services"
    )

    for svc in services:
        
        db_neo4j.query(
,
            parameters={"category": svc["category"]}
        )

        db_neo4j.query(
,
            parameters={
                "sid": svc["service_id"],
                "name": svc["service_name"],
                "cost": float(svc["base_cost_inr"]) if svc["base_cost_inr"] else 0,
                "category": svc["category"]
            }
        )

    return len(services)

def sync_user_graph(user_id: int):
    
    sync_services_to_graph()

    db_neo4j.query(
,
        parameters={"uid": user_id}
    )

    subs = run_query(
,
        params=(user_id,)
    )

    db_neo4j.query(
,
        parameters={"uid": user_id}
    )

    for sub in subs:
        db_neo4j.query(
,
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

    sync_user_graph(user_id)

    results = db_neo4j.query(
,
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
    sync_user_graph(user_id)

    results = db_neo4j.query(
,
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