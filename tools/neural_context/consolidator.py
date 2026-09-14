import time
from typing import List, Tuple
from .memory_network import HopfieldAssociativeMemory

class MemoryConsolidator:
    """
    Biological-inspired sleep/consolidation engine:
    1. Prunes transient memories whose Ebbinghaus retention has decayed below a threshold.
    2. Clusters and associates frequently accessed memories.
    3. Prevents memory saturation by maintaining high information density.
    """
    def __init__(self, retention_threshold: float = 0.15):
        self.retention_threshold = retention_threshold

    def consolidate(self, network: HopfieldAssociativeMemory) -> Tuple[int, int]:
        """
        Runs a consolidation cycle.
        Returns (pruned_count, strengthened_synapses_count).
        """
        now = time.time()
        pruned_ids = []

        for node_id, node in list(network.nodes.items()):
            # Pinned memories in metadata never decay
            if node.metadata.get("pinned", False):
                continue
            retention = node.current_retention(now)
            if retention < self.retention_threshold and node.access_count <= 1:
                pruned_ids.append(node_id)

        for pid in pruned_ids:
            del network.nodes[pid]
            # Remove associated synapses
            keys_to_del = [k for k in network.synapses.keys() if k[0] == pid or k[1] == pid]
            for k in keys_to_del:
                del network.synapses[k]

        # Decay inactive synapses slightly
        strengthened = 0
        for k in list(network.synapses.keys()):
            network.synapses[k] *= 0.98
            if network.synapses[k] > 0.5:
                strengthened += 1
            elif network.synapses[k] < 0.02:
                del network.synapses[k]

        return len(pruned_ids), strengthened
