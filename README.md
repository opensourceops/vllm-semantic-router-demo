# vLLM Semantic Router – Intelligent Routing & Cache Demo

Minimal demo showing how to put **vLLM** behind **Semantic Router + Envoy** and
get:

- Intelligent multi-model routing with `model: "auto"`
- Semantic cache (repeat and similar queries)
- Optional PII & jailbreak protection

The demo runs alongside (not inside) the upstream [`vllm-project/semantic-router`](https://github.com/vllm-project/semantic-router) repo: you clone both, then point Semantic Router at this demo’s `config.yaml` and scripts.

From your home directory:

```bash
cd ~
git clone https://github.com/vllm-project/semantic-router.git
git clone https://github.com/opensourceops/vllm-semantic-router-demo.git
```

---

## 1. Architecture Overview

High-level flow:

```text
Client (OpenAI API, model: "auto")
        │
        ▼
    Envoy (:8801)
        │  ext_proc
        ▼
Semantic Router (Go)
  ├─ Keyword / PII / Jailbreak classifiers
  ├─ Decision engine ("technical_support_decision", etc.)
  ├─ Semantic cache (BERT)
  └─ vLLM endpoint selection
        │
        ├─ vLLM: Qwen2.5-3B-Instruct   (:8000)
        ├─ vLLM: Ministral-3-3B        (:8001)
        └─ vLLM: DeepSeek-R1-Qwen-14B  (:8002)
```

Your application **always** calls Envoy with `model: "auto"`.  
Router decides which vLLM model + port to use per request.

---

## 2. Prerequisites

- vLLM installed and working (OpenAI-compatible server)
- Three models downloaded (example paths):
  - `~/models/Qwen2.5-3B-Instruct`
  - `~/models/Ministral-3-3B-Instruct-2512`
  - `~/models/DeepSeek-R1-Distill-Qwen-14B`
- `semantic-router` repo cloned and built (Go toolchain + `make`)
- `curl` and `jq` installed

This demo assumes:

- vLLM ports: `8000`, `8001`, `8002`
- Envoy+Router OpenAI endpoint: `http://localhost:8801/v1/...`
- Auth header: `Authorization: Bearer dev`

Adjust ports and auth to your environment as needed.

---

## 3. Start vLLM Servers

Start the three vLLM servers using a helper script `scripts/start-vllm-servers.sh`, which wraps the `vllm serve` commands and performs basic health checks.

Example:

```bash
cd ~/vllm-semantic-router-demo
./scripts/start-vllm-servers.sh
```

This will:

- Start Qwen2.5‑3B on port `8000`
- Start Ministral‑3‑3B‑Instruct‑2512 on port `8001`
- Start DeepSeek‑R1‑Distill‑Qwen‑14B on port `8002`
- Write logs to `~/logs/vllm-*.log`

Verify vLLM model IDs (router config uses these as keys):

```bash
curl -s http://localhost:8000/v1/models | jq
curl -s http://localhost:8001/v1/models | jq
curl -s http://localhost:8002/v1/models | jq
```

You should see `id` values like:

- `~/models/Qwen2.5-3B-Instruct`
- `~/models/Ministral-3-3B-Instruct-2512`
- `~/models/DeepSeek-R1-Distill-Qwen-14B`

---

## 4. Download Minimal Semantic Router Models

Semantic Router uses small ModernBERT / BERT models for:

- Intent / decision classification
- PII detection
- Jailbreak detection
- Semantic cache embeddings

From the `semantic-router` repo:

```bash
cd ~/semantic-router
CI_MINIMAL_MODELS=true make download-models
```

This fetches only the minimal set required for this demo.

---

## 5. Start Semantic Router and Envoy

From the `semantic-router` repo:

```bash
cd ~/semantic-router

# Router (uses the demo config from vllm-semantic-router-demo)
nohup make run-router CONFIG_FILE=~/vllm-semantic-router-demo/config.yaml \
  > ~/logs/semantic-router.log 2>&1 &

# Envoy (front-end OpenAI endpoint on :8801)
nohup make run-envoy \
  > ~/logs/envoy.log 2>&1 &
```

---

## 6. Run the Demo

In **terminal 1** (logs):

```bash
cd ~/vllm-semantic-router-demo
./scripts/watch_routing_logs.sh
```

This tails and colorizes:

- `[CLASS]`    – keyword classification  
- `[DECISION]` – decision engine result  
- `[ROUTING]`  – auto model selection  
- `[ENDPOINT]` – chosen vLLM endpoint  
- `[CACHE]`    – semantic cache hits  
- `[ENVOY]`    – Envoy headers (`x-selected-model`, `x-vsr-destination-endpoint`)

In **terminal 2** (interactive menu):

```bash
cd ~/vllm-semantic-router-demo
./scripts/auto_routing_menu.sh
```

You’ll see a colorized menu:

1. **Technical support**  → DeepSeek (reasoning on)  
2. **Product inquiry**    → Ministral  
3. **Account management** → Qwen  
4. **General inquiry**    → Qwen (default)  
5. **Repeat last prompt** → semantic cache demo  
6. **Account + PII test** → PII block (no model call)  
7. **Product jailbreak**  → Jailbreak block (no model call)  
`q` to quit.

---

## 7. What Each Option Demonstrates

| Option | Scenario                       | Expected Decision               | Backend Model                                      | Extras                              |
| ------ | ------------------------------ | --------------------------------| -------------------------------------------------- | ----------------------------------- |
| 1      | Troubleshooting timeout error  | `technical_support_decision`    | `/home/.../DeepSeek-R1-Distill-Qwen-14B` (8002)   | Reasoning on, cache, PII, jailbreak |
| 2      | Pricing / features for product | `product_inquiry_decision`      | `/home/.../Ministral-3-3B-Instruct-2512` (8001)   | Jailbreak, cache                    |
| 3      | Account recovery               | `account_management_decision`   | `/home/.../Qwen2.5-3B-Instruct` (8000)            | PII, jailbreak, cache               |
| 4      | General fun facts              | `general_inquiry_decision`      | `/home/.../Qwen2.5-3B-Instruct` (8000)            | Jailbreak, cache                    |
| 5      | Repeat last query              | same as last                    | same as last                                      | Shows `[CACHE] cache_hit`           |
| 6      | Account + credit card number   | `account_management_decision`   | **Blocked before model**                          | PII violation response              |
| 7      | Pricing + jailbreak request    | `product_inquiry_decision`      | **Blocked before model**                          | Jailbreak violation response        |

During a live demo, read the logs top-down:

1. `[CLASS]`    – which keyword rule fired  
2. `[DECISION]` – which decision was selected  
3. `[ROUTING]`  – which model ID was chosen  
4. `[ENDPOINT]` – which vLLM port  
5. `[CACHE]`    – whether a semantic cache hit occurred  

---

## 8. Links

- vLLM: https://github.com/vllm-project/vllm  
- Semantic Router: https://github.com/vllm-project/semantic-router  
