# safe_peer

**Run potentially crashy or untrusted Erlang / NIF code on isolated hidden BEAM peer nodes.**

`safe_peer` protects your main node from catastrophic crashes caused by:

- Native Implemented Functions (NIFs)
- Bad ports or drivers
- Calls to `erlang:halt/0`
- Segfaults inside native code
- Hard VM exits

Instead of executing dangerous code locally, it runs the function on a hidden peer node.  
If the peer crashes, only the peer dies — your node remains alive and receives a clean error.

---

## ⚠️ Status

**Experimental.**

API stability is expected, but pooling, peer bootstrapping, and performance optimizations are still in progress.

This library prioritizes **isolation and correctness over latency**.

---

## ✨ Features

- ✅ Full VM isolation using OTP `peer`
- ✅ Hidden nodes (no cluster pollution)
- ✅ Clean OTP supervision tree
- ✅ Crash containment for NIFs and native code
- ✅ Deterministic timeout control
- ✅ Erlang-native API (no Elixir dependency)
- 🚧 Peer pooling (planned)
- 🚧 Peer bootstrap synchronization (planned)

---

## 🚀 Quick Start

### Requirements

- Erlang/OTP 25+ (peer module required)
- Node must run in **distributed mode**

Start your shell with a node name:

```bash
erl -sname safepeer
