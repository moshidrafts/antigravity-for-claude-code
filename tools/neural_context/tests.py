import unittest
import numpy as np
import os
import shutil
import tempfile
import time
from .embeddings import NeuralEmbedder
from .memory_network import MemoryNode, HopfieldAssociativeMemory
from .store import NeuralMemoryStore
from .consolidator import MemoryConsolidator

class TestNeuralContext(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = os.path.join(self.temp_dir, "test_memory.db")
        self.embedder = NeuralEmbedder(dimension=256)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_embeddings_semantic_similarity(self):
        v1 = self.embedder.embed("deploy by pushing to main on DigitalOcean")
        v2 = self.embedder.embed("commit and push directly to main branch deployment")
        v3 = self.embedder.embed("baking chocolate chip cookies with sugar and flour")

        sim_related = NeuralEmbedder.cosine_similarity(v1, v2)
        sim_unrelated = NeuralEmbedder.cosine_similarity(v1, v3)

        self.assertGreater(sim_related, 0.25)
        self.assertLess(sim_unrelated, 0.18)
        self.assertGreater(sim_related, sim_unrelated * 1.8)

    def test_hopfield_associative_memory(self):
        network = HopfieldAssociativeMemory(beta=6.0)
        
        node1 = MemoryNode(
            id="auth_bug",
            content="Authentication token expiry check must use <= instead of <",
            category="gotcha",
            embedding=self.embedder.embed("Authentication token expiry check must use <= instead of <")
        )
        node2 = MemoryNode(
            id="docker_deploy",
            content="Build multi-stage Dockerfile with alpine base for small images",
            category="workflow",
            embedding=self.embedder.embed("Build multi-stage Dockerfile with alpine base for small images")
        )
        network.add_node(node1)
        network.add_node(node2)

        q_vec = self.embedder.embed("JWT token validation bug in auth middleware")
        results = network.query(q_vec, top_k=2)

        self.assertGreater(len(results), 0)
        top_node, top_score = results[0]
        self.assertEqual(top_node.id, "auth_bug")
        self.assertGreater(top_score, 0.25)

    def test_hebbian_synaptic_linking(self):
        network = HopfieldAssociativeMemory()
        node1 = MemoryNode(id="n1", content="React state", category="ui", embedding=self.embedder.embed("React state"))
        node2 = MemoryNode(id="n2", content="Redux store", category="ui", embedding=self.embedder.embed("Redux store"))
        network.add_node(node1)
        network.add_node(node2)

        network.link("n1", "n2", weight=0.5)
        self.assertIn(("n1", "n2"), network.synapses)
        self.assertAlmostEqual(network.synapses[("n1", "n2")], 0.5)

    def test_store_persistence(self):
        store = NeuralMemoryStore(self.db_path)
        net = HopfieldAssociativeMemory()
        node = MemoryNode(
            id="test_persist",
            content="Always use pnpm instead of npm",
            category="preference",
            embedding=self.embedder.embed("Always use pnpm instead of npm"),
            metadata={"source": "user"}
        )
        net.add_node(node)
        store.save_network(net)

        loaded_net = store.load_network()
        self.assertIn("test_persist", loaded_net.nodes)
        loaded_node = loaded_net.nodes["test_persist"]
        self.assertEqual(loaded_node.content, "Always use pnpm instead of npm")
        self.assertEqual(loaded_node.category, "preference")

    def test_ebbinghaus_decay_and_consolidation(self):
        network = HopfieldAssociativeMemory()
        old_time = time.time() - (3600 * 200) # 200 hours ago
        stale_node = MemoryNode(
            id="stale",
            content="temporary debug print in line 42",
            category="gotcha",
            embedding=self.embedder.embed("temporary debug print"),
            last_accessed=old_time,
            access_count=1,
            decay_lambda=0.05
        )
        durable_node = MemoryNode(
            id="durable",
            content="Production database is PostgreSQL on AWS RDS",
            category="architecture",
            embedding=self.embedder.embed("PostgreSQL on AWS RDS"),
            metadata={"pinned": True}
        )
        network.add_node(stale_node)
        network.add_node(durable_node)

        consolidator = MemoryConsolidator(retention_threshold=0.20)
        pruned, _ = consolidator.consolidate(network)

        self.assertEqual(pruned, 1)
        self.assertNotIn("stale", network.nodes)
        self.assertIn("durable", network.nodes)

if __name__ == "__main__":
    unittest.main()
