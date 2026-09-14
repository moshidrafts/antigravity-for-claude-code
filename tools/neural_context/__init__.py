"""
Neural Context Builder & Continuous Learner for Coding Agents.
Implements Modern Hopfield associative retrieval, Hebbian synaptic reinforcement,
Ebbinghaus forgetting dynamics, and automated Claude Code session ingestion.
"""

from .embeddings import NeuralEmbedder
from .memory_network import HopfieldAssociativeMemory, MemoryNode
from .store import NeuralMemoryStore
from .consolidator import MemoryConsolidator
from .claude_sync import ClaudeMemoryHarvester

__version__ = "1.0.0"
__all__ = [
    "NeuralEmbedder",
    "HopfieldAssociativeMemory",
    "MemoryNode",
    "NeuralMemoryStore",
    "MemoryConsolidator",
    "ClaudeMemoryHarvester",
]
