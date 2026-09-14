import sys
import os
import argparse
import time

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

from .embeddings import NeuralEmbedder
from .memory_network import MemoryNode, HopfieldAssociativeMemory
from .store import NeuralMemoryStore
from .consolidator import MemoryConsolidator
from .claude_sync import ClaudeMemoryHarvester

DEFAULT_DB = os.path.expanduser("~/.claude/neural_memory.db")

def get_engine(db_path: str = DEFAULT_DB):
    embedder = NeuralEmbedder(dimension=256)
    store = NeuralMemoryStore(db_path)
    network = store.load_network()
    return embedder, store, network

def cmd_learn(args):
    embedder, store, network = get_engine(args.db)
    content = " ".join(args.text).strip()
    if not content:
        print("Error: content cannot be empty.")
        return 1

    node_id = f"mem_{int(time.time()*1000)}"
    emb = embedder.embed(content)
    node = MemoryNode(
        id=node_id,
        content=content,
        category=args.category,
        embedding=emb,
        strength=args.strength,
        metadata={"tags": args.tags}
    )
    network.add_node(node)
    
    # Check for associative resonance with existing nodes
    query_results = network.query(emb, top_k=3, min_score=0.35)
    for existing, score in query_results:
        if existing.id != node_id:
            network.link(node_id, existing.id, weight=score * 0.5)

    store.save_network(network)
    print(f"[+] Learned memory [{node_id}] in category '{args.category}'.")
    if query_results:
        print(f"    Resonated with {len(query_results)} existing memory patterns.")
    return 0

def cmd_recall(args):
    embedder, store, network = get_engine(args.db)
    query_text = " ".join(args.query).strip()
    if not query_text:
        print("Error: query cannot be empty.")
        return 1

    q_emb = embedder.embed(query_text)
    results = network.query(q_emb, top_k=args.top, min_score=args.min_score)

    print(f"=== NEURAL ASSOCIATIVE RECALL (Query: \'{query_text}\') ===")
    if not results:
        print("No resonant memories found above activation threshold.")
        return 0

    for idx, (node, score) in enumerate(results, 1):
        print(f"[{idx}] Confidence: {score*100:.1f}% | Category: {node.category} | Access: {node.access_count}x")
        print(f"    Content: {node.content[:160]}..." if len(node.content) > 160 else f"    Content: {node.content}")
        print(f"    Retention: {node.current_retention()*100:.1f}% | ID: {node.id}")
        print("-" * 65)

    # Persist reinforced weights
    store.save_network(network)
    return 0

def cmd_sync(args):
    embedder, store, network = get_engine(args.db)
    harvester = ClaudeMemoryHarvester(embedder)
    
    print("[*] Harvesting Claude Code project memories...")
    claude_nodes = harvester.harvest_claude_memories()
    for n in claude_nodes:
        network.add_node(n)
    print(f"    Ingested {len(claude_nodes)} memories from Claude Code.")

    if args.project:
        print(f"[*] Harvesting project documentation from {args.project}...")
        doc_nodes = harvester.harvest_project_docs(args.project)
        for n in doc_nodes:
            network.add_node(n)
        print(f"    Ingested {len(doc_nodes)} documentation chunks.")

    # Cross-link resonant patterns
    print("[*] Wiring synaptic links across memory topology...")
    all_nodes = list(network.nodes.values())
    links_formed = 0
    for i in range(len(all_nodes)):
        for j in range(i + 1, min(i + 20, len(all_nodes))):
            sim = NeuralEmbedder.cosine_similarity(all_nodes[i].embedding, all_nodes[j].embedding)
            if sim > 0.50:
                network.link(all_nodes[i].id, all_nodes[j].id, weight=sim * 0.3)
                links_formed += 1

    store.save_network(network)
    print(f"[+] Sync complete! Total active nodes: {len(network.nodes)} | Synaptic edges: {len(network.synapses)}")
    return 0

def cmd_stats(args):
    _, store, network = get_engine(args.db)
    print("==========================================================================")
    print("                 NEURAL CONTEXT & MEMORY NETWORK TOPOLOGY                 ")
    print("==========================================================================")
    print(f"  Database Path:        {args.db}")
    print(f"  Total Neural Nodes:   {len(network.nodes)}")
    print(f"  Synaptic Connections: {len(network.synapses)}")
    
    categories = {}
    for n in network.nodes.values():
        categories[n.category] = categories.get(n.category, 0) + 1

    print("\n  Category Breakdown:")
    for cat, count in sorted(categories.items()):
        print(f"    - {cat:<20}: {count} nodes")
    print("==========================================================================")
    return 0

def cmd_consolidate(args):
    _, store, network = get_engine(args.db)
    consolidator = MemoryConsolidator(retention_threshold=args.threshold)
    pruned, strengthened = consolidator.consolidate(network)
    store.save_network(network)
    print(f"[+] Consolidation cycle complete.")
    print(f"    - Pruned {pruned} decayed/transient nodes.")
    print(f"    - Maintained {strengthened} strong synaptic pathways.")
    print(f"    - Active nodes remaining: {len(network.nodes)}")
    return 0

def main():
    parser = argparse.ArgumentParser(description="Neural Context Builder & Memory Engine for Claude Code")
    parser.add_argument("--db", default=DEFAULT_DB, help="Path to SQLite neural memory database")
    subparsers = parser.add_subparsers(dest="command")

    # learn
    p_learn = subparsers.add_parser("learn", help="Teach the network a new fact, rule, or preference")
    p_learn.add_argument("text", nargs="+", help="Memory text content")
    p_learn.add_argument("--category", default="preference", choices=["preference", "architecture", "gotcha", "code_pattern", "workflow"])
    p_learn.add_argument("--strength", type=float, default=1.0, help="Initial synaptic strength")
    p_learn.add_argument("--tags", nargs="*", default=[], help="Optional metadata tags")

    # recall
    p_recall = subparsers.add_parser("recall", help="Associatively query memories using Hopfield energy")
    p_recall.add_argument("query", nargs="+", help="Query string")
    p_recall.add_argument("--top", type=int, default=5, help="Number of results")
    p_recall.add_argument("--min-score", type=float, default=0.15, help="Minimum activation score")

    # sync
    p_sync = subparsers.add_parser("sync", help="Harvest Claude Code memory files and project docs")
    p_sync.add_argument("--project", default=".", help="Path to project directory")

    # stats
    subparsers.add_parser("stats", help="Display neural network topology and statistics")

    # consolidate
    p_cons = subparsers.add_parser("consolidate", help="Run Ebbinghaus memory decay and consolidation")
    p_cons.add_argument("--threshold", type=float, default=0.15, help="Retention cutoff threshold")

    args = parser.parse_args()
    if args.command == "learn":
        sys.exit(cmd_learn(args))
    elif args.command == "recall":
        sys.exit(cmd_recall(args))
    elif args.command == "sync":
        sys.exit(cmd_sync(args))
    elif args.command == "stats":
        sys.exit(cmd_stats(args))
    elif args.command == "consolidate":
        sys.exit(cmd_consolidate(args))
    else:
        parser.print_help()
        sys.exit(0)

if __name__ == "__main__":
    main()
