import re
import math
import hashlib
import numpy as np

class NeuralEmbedder:
    """
    Zero-dependency continuous semantic embedding engine.
    Uses subword character n-grams + word n-grams projected via a deterministic
    orthonormal random projection matrix onto a unit hypersphere in R^D (default D=256).
    """
    def __init__(self, dimension: int = 256, seed: int = 42):
        self.dimension = dimension
        self.seed = seed
        self._projection_cache = {}

    def _tokenize(self, text: str):
        text = text.lower()
        words = re.findall(r'[a-z0-9_]+', text)
        features = []
        for w in words:
            features.append(f"w:{w}")
            if len(w) >= 3:
                for n in (3, 4):
                    for i in range(len(w) - n + 1):
                        features.append(f"c:{w[i:i+n]}")
        for i in range(len(words) - 1):
            features.append(f"bi:{words[i]}_{words[i+1]}")
        return features

    def _hash_feature(self, feature: str) -> np.ndarray:
        if feature in self._projection_cache:
            return self._projection_cache[feature]
        h = hashlib.sha256(f"{self.seed}:{feature}".encode("utf-8")).digest()
        seed_val = int.from_bytes(h[:4], "little")
        rng = np.random.RandomState(seed_val)
        vec = rng.randn(self.dimension).astype(np.float32)
        norm = np.linalg.norm(vec)
        if norm > 0:
            vec /= norm
        if len(self._projection_cache) < 15000:
            self._projection_cache[feature] = vec
        return vec

    def embed(self, text: str) -> np.ndarray:
        """Embeds text into a normalized D-dimensional continuous vector."""
        if not text or not text.strip():
            return np.zeros(self.dimension, dtype=np.float32)
        features = self._tokenize(text)
        if not features:
            return np.zeros(self.dimension, dtype=np.float32)
        
        accum = np.zeros(self.dimension, dtype=np.float32)
        for f in features:
            accum += self._hash_feature(f)
        
        norm = np.linalg.norm(accum)
        if norm > 1e-9:
            accum /= norm
        return accum

    @staticmethod
    def cosine_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
        n1 = np.linalg.norm(v1)
        n2 = np.linalg.norm(v2)
        if n1 < 1e-9 or n2 < 1e-9:
            return 0.0
        return float(np.dot(v1, v2) / (n1 * n2))
