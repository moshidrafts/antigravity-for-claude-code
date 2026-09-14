---
name: neural-context
description: "Neural Associative Memory & Context Builder for Claude Code. Uses Modern Hopfield networks, continuous dense semantic embeddings, Hebbian synaptic reinforcement, and Ebbinghaus memory consolidation to learn developer habits, project gotchas, and recall relevant context associatively. Trigger with /neural-context, 'neural context', 'neural learn', or 'neural recall'."
---

# /neural-context

Neural Associative Memory & Continuous Context Learner. Connects developer memories, project gotchas, and past decisions into a dense associative graph network using Modern Hopfield retrieval and Hebbian synaptic reinforcement.

## Usage

```bash
# Query the neural associative memory network for relevant context
neural-context recall "<query>"

# Teach the network a new fact, rule, or preference
neural-context learn "<rule or preference>" --category preference

# Harvest Claude Code project memories and repo docs into the neural graph
neural-context sync

# Display neural network topology, active nodes, and synaptic links
neural-context stats

# Run Ebbinghaus decay and memory consolidation (prunes transient noise)
neural-context consolidate
```

## How It Works Under The Hood

1. **Continuous Semantic Embeddings:** Encodes subword n-grams and programming tokens onto a high-dimensional unit hypersphere $\mathbb{R}^{256}$.
2. **Modern Hopfield Associative Retrieval:** Computes associative energy $\xi = \text{softmax}(\beta X^T q) X$ combined with synaptic graph spread.
3. **Hebbian Reinforcement:** Synaptic connections between co-activated memories strengthen when recalled together (*"neurons that fire together wire together"*).
4. **Ebbinghaus Memory Consolidation:** Applies biological forgetting dynamics ($R = S \cdot e^{-\lambda t}$) to automatically prune transient noise while preserving durable knowledge.
