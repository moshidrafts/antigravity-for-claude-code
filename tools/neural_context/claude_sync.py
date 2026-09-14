import os
import re
import glob
import hashlib
from typing import List, Dict
from .embeddings import NeuralEmbedder
from .memory_network import MemoryNode, HopfieldAssociativeMemory

class ClaudeMemoryHarvester:
    """
    Scans Claude Code's native memory directories (~/.claude/projects/*/memory/*.md)
    and project documentation, vectorizing and wiring them into the neural associative graph.
    """
    def __init__(self, embedder: NeuralEmbedder):
        self.embedder = embedder

    def harvest_claude_memories(self, claude_dir: str = None) -> List[MemoryNode]:
        if claude_dir is None:
            user_profile = os.environ.get("USERPROFILE") or os.environ.get("HOME")
            claude_dir = os.path.join(user_profile, ".claude")
        
        memory_pattern = os.path.join(claude_dir, "projects", "*", "memory", "*.md")
        files = glob.glob(memory_pattern)
        nodes = []

        for fp in files:
            try:
                with open(fp, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                
                # Parse frontmatter description or body
                desc_match = re.search(r'description:\s*"([^"]+)"', content)
                desc = desc_match.group(1) if desc_match else ""
                
                # Strip frontmatter for body text
                body = re.sub(r'^---[\s\S]*?---\s*', '', content).strip()
                full_text = f"{desc}\n\n{body}".strip()
                
                basename = os.path.splitext(os.path.basename(fp))[0]
                node_id = f"claude_mem:{basename}"
                
                # Category inference
                category = "architecture"
                if "deploy" in basename or "push" in basename:
                    category = "workflow"
                elif "env" in basename or "config" in basename:
                    category = "gotcha"
                elif "role" in basename or "assign" in basename:
                    category = "preference"

                emb = self.embedder.embed(full_text)
                node = MemoryNode(
                    id=node_id,
                    content=full_text,
                    category=category,
                    embedding=emb,
                    strength=1.5,
                    decay_lambda=0.001,  # Pinned/durable memories decay very slowly
                    metadata={"source_file": fp, "title": basename, "pinned": True}
                )
                nodes.append(node)
            except Exception as e:
                pass

        return nodes

    def harvest_project_docs(self, project_path: str) -> List[MemoryNode]:
        nodes = []
        doc_files = []
        for ext in ("*.md", "*.txt", "*.rst"):
            doc_files.extend(glob.glob(os.path.join(project_path, ext)))
            doc_files.extend(glob.glob(os.path.join(project_path, "docs", "**", ext), recursive=True))

        for fp in set(doc_files):
            try:
                with open(fp, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
                
                if len(text.strip()) < 40 or "node_modules" in fp or ".git" in fp:
                    continue

                # Chunk long markdown files by section headers
                sections = re.split(r'\n(?=##?\s+)', text)
                rel_path = os.path.relpath(fp, project_path)
                for idx, sec in enumerate(sections):
                    sec_clean = sec.strip()
                    if len(sec_clean) < 30:
                        continue
                    node_id = f"doc:{rel_path}#{idx}"
                    emb = self.embedder.embed(sec_clean)
                    node = MemoryNode(
                        id=node_id,
                        content=sec_clean,
                        category="documentation",
                        embedding=emb,
                        strength=1.0,
                        decay_lambda=0.003,
                        metadata={"file": rel_path, "section_index": idx}
                    )
                    nodes.append(node)
            except Exception:
                pass
        return nodes
