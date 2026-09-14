import sqlite3
import json
import os
import numpy as np
from typing import List, Dict, Optional
from .memory_network import MemoryNode, HopfieldAssociativeMemory

class NeuralMemoryStore:
    """
    Lightweight, embedded SQLite persistence for Neural Memory Nodes and Synapses.
    Runs 100% locally with zero external database processes or servers.
    """
    def __init__(self, db_path: str):
        self.db_path = db_path
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
        self._init_db()

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def _init_db(self):
        with self._get_conn() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS memory_nodes (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    category TEXT NOT NULL,
                    embedding BLOB NOT NULL,
                    created_at REAL NOT NULL,
                    last_accessed REAL NOT NULL,
                    access_count INTEGER NOT NULL,
                    strength REAL NOT NULL,
                    decay_lambda REAL NOT NULL,
                    metadata TEXT NOT NULL
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS synapses (
                    source_id TEXT NOT NULL,
                    target_id TEXT NOT NULL,
                    weight REAL NOT NULL,
                    PRIMARY KEY (source_id, target_id)
                )
            """)
            conn.commit()

    def save_node(self, node: MemoryNode):
        with self._get_conn() as conn:
            emb_blob = node.embedding.astype(np.float32).tobytes()
            meta_str = json.dumps(node.metadata)
            conn.execute("""
                INSERT INTO memory_nodes (id, content, category, embedding, created_at, last_accessed, access_count, strength, decay_lambda, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    content=excluded.content,
                    category=excluded.category,
                    embedding=excluded.embedding,
                    last_accessed=excluded.last_accessed,
                    access_count=excluded.access_count,
                    strength=excluded.strength,
                    metadata=excluded.metadata
            """, (node.id, node.content, node.category, emb_blob, node.created_at, node.last_accessed, node.access_count, node.strength, node.decay_lambda, meta_str))
            conn.commit()

    def save_synapse(self, source_id: str, target_id: str, weight: float):
        u, v = (source_id, target_id) if source_id < target_id else (target_id, source_id)
        with self._get_conn() as conn:
            conn.execute("""
                INSERT INTO synapses (source_id, target_id, weight)
                VALUES (?, ?, ?)
                ON CONFLICT(source_id, target_id) DO UPDATE SET weight=excluded.weight
            """, (u, v, weight))
            conn.commit()

    def load_network(self) -> HopfieldAssociativeMemory:
        network = HopfieldAssociativeMemory()
        with self._get_conn() as conn:
            cur = conn.cursor()
            cur.execute("SELECT id, content, category, embedding, created_at, last_accessed, access_count, strength, decay_lambda, metadata FROM memory_nodes")
            for row in cur.fetchall():
                emb = np.frombuffer(row[3], dtype=np.float32)
                meta = json.loads(row[9])
                node = MemoryNode(
                    id=row[0],
                    content=row[1],
                    category=row[2],
                    embedding=emb,
                    created_at=row[4],
                    last_accessed=row[5],
                    access_count=row[6],
                    strength=row[7],
                    decay_lambda=row[8],
                    metadata=meta
                )
                network.add_node(node)
            
            cur.execute("SELECT source_id, target_id, weight FROM synapses")
            for row in cur.fetchall():
                network.synapses[(row[0], row[1])] = row[2]

        return network

    def save_network(self, network: HopfieldAssociativeMemory):
        for node in network.nodes.values():
            self.save_node(node)
        for (u, v), w in network.synapses.items():
            self.save_synapse(u, v, w)

    def delete_node(self, node_id: str):
        with self._get_conn() as conn:
            conn.execute("DELETE FROM memory_nodes WHERE id = ?", (node_id,))
            conn.execute("DELETE FROM synapses WHERE source_id = ? OR target_id = ?", (node_id, node_id))
            conn.commit()

    def count(self) -> int:
        with self._get_conn() as conn:
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM memory_nodes")
            return cur.fetchone()[0]
