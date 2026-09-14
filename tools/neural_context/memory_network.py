import time
import math
import numpy as np
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple

@dataclass
class MemoryNode:
    id: str
    content: str
    category: str  # "preference", "architecture", "gotcha", "code_pattern", "workflow"
    embedding: np.ndarray
    created_at: float = field(default_factory=time.time)
    last_accessed: float = field(default_factory=time.time)
    access_count: int = 1
    strength: float = 1.0  # Synaptic strength
    decay_lambda: float = 0.005  # Ebbinghaus forgetting rate per hour
    metadata: Dict = field(default_factory=dict)

    def current_retention(self, current_time: Optional[float] = None) -> float:
        """Computes Ebbinghaus retention: R = strength * exp(-lambda * delta_hours)"""
        if current_time is None:
            current_time = time.time()
        delta_hours = max(0.0, (current_time - self.last_accessed) / 3600.0)
        # Power law / exponential decay modulated by access frequency
        effective_lambda = self.decay_lambda / (1.0 + math.log1p(self.access_count))
        retention = self.strength * math.exp(-effective_lambda * delta_hours)
        return float(min(1.0, max(0.01, retention)))

    def reinforce(self, boost: float = 0.2):
        """Hebbian reinforcement: synapses strengthen upon recall."""
        self.access_count += 1
        self.last_accessed = time.time()
        self.strength = min(3.0, self.strength + boost)


class HopfieldAssociativeMemory:
    """
    Continuous Modern Hopfield Associative Memory Network.
    Implements continuous associative retrieval over stored memory patterns:
    xi = softmax(beta * X^T * q) * X
    Coupled with Hebbian associative edges between co-activated memories.
    """
    def __init__(self, beta: float = 8.0):
        self.beta = beta  # Inverse temperature (higher = sharper focus, lower = broader association)
        self.nodes: Dict[str, MemoryNode] = {}
        # Associative adjacency matrix: edge_weights[(id1, id2)] = weight
        self.synapses: Dict[Tuple[str, str], float] = {}

    def add_node(self, node: MemoryNode):
        self.nodes[node.id] = node

    def link(self, id1: str, id2: str, weight: float = 0.1):
        """Hebbian synaptic link: Neurons that fire together wire together."""
        if id1 == id2 or id1 not in self.nodes or id2 not in self.nodes:
            return
        k1 = (id1, id2) if id1 < id2 else (id2, id1)
        self.synapses[k1] = min(2.0, self.synapses.get(k1, 0.0) + weight)

    def query(self, query_vec: np.ndarray, top_k: int = 5, min_score: float = 0.1) -> List[Tuple[MemoryNode, float]]:
        """
        Performs continuous associative recall.
        Combines semantic cosine energy, associative graph spread, and Ebbinghaus retention.
        """
        if not self.nodes:
            return []

        ids = list(self.nodes.keys())
        patterns = np.array([self.nodes[i].embedding for i in ids])  # (N, D)
        
        # 1. Cosine dot-product similarities
        dots = np.dot(patterns, query_vec)  # (N,)
        
        # 2. Modern Hopfield Softmax attention weights
        scaled_dots = dots * self.beta
        # Numerical stability shift
        exp_vals = np.exp(scaled_dots - np.max(scaled_dots))
        softmax_weights = exp_vals / np.sum(exp_vals)

        # 3. Combine raw semantic similarity with retention score & Hopfield activation
        now = time.time()
        results = []
        for idx, node_id in enumerate(ids):
            node = self.nodes[node_id]
            retention = node.current_retention(now)
            cos_sim = float(dots[idx])
            hopfield_act = float(softmax_weights[idx])
            
            # Incorporate synaptic graph boost from neighboring nodes
            synapse_boost = 0.0
            for (u, v), w in self.synapses.items():
                if u == node_id and v in self.nodes:
                    other_idx = ids.index(v)
                    synapse_boost += w * softmax_weights[other_idx]
                elif v == node_id and u in self.nodes:
                    other_idx = ids.index(u)
                    synapse_boost += w * softmax_weights[other_idx]

            # Composite Associative Energy Score
            final_score = (cos_sim * 0.55) + (hopfield_act * 0.25) + (synapse_boost * 0.10) + (retention * 0.10)
            if cos_sim >= min_score or final_score >= min_score:
                results.append((node, final_score))

        # Sort descending by final score
        results.sort(key=lambda x: x[1], reverse=True)
        top_results = results[:top_k]

        # Hebbian co-activation reinforcement for the top retrieved memories
        for i in range(len(top_results)):
            node_i, _ = top_results[i]
            node_i.reinforce(boost=0.05)
            for j in range(i + 1, len(top_results)):
                node_j, _ = top_results[j]
                self.link(node_i.id, node_j.id, weight=0.05)

        return top_results
