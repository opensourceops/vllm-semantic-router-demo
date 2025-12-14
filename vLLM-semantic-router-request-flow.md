# 🚀 vLLM Semantic Router: Request Flow

This document visualizes the complete request lifecycle, from initial client request to final response, including intelligent routing, security checks, and model selection.

```mermaid
flowchart TD
    A[Client Request] --> B[Envoy Proxy]
    B --> C[Semantic Router]
    C --> D[Classification]
    D --> E[Decision Engine]
    E --> F[Security Checks]
    F --> G[Model Selection]
    G --> H[vLLM Execution]
    H --> I[Response Handling]
    I --> J[Client]
    
    style A fill:#4CAF50,color:white
    style B fill:#2196F3,color:white
    style C fill:#9C27B0,color:white
    style J fill:#4CAF50,color:white
```

## 🔄 Request Lifecycle

## 1️⃣ Client Request → Envoy Proxy

```mermaid
sequenceDiagram
    participant C as Client
    participant E as Envoy (:8801)
    participant R as Semantic Router
    
    C->>E: POST /v1/chat/completions
    Note over C,E: { "model": "auto", "messages": [...] }
    E->>R: Forward via ext_proc (gRPC)
    R-->>E: Process request
```

## 2️⃣ Request Processing Pipeline

### Classification & Routing

```mermaid
flowchart TD
    A[Parse Request] --> B[Extract Prompt]
    B --> C[ModernBERT Classifier]
    C --> D{Intent?}
    D -->|technical_support| E[Technical Support]
    D -->|product_inquiry| F[Product Inquiry]
    D -->|account_management| G[Account Management]
    D -->|general_inquiry| H[General Inquiry]
    
    style C fill:#FFC107,color:black
    style D fill:#9C27B0,color:white
```

**Classification Process**:
- ModernBERT analyzes the prompt
- Matches against predefined categories
- Logs: `[CLASS] matched rule "technical_support"`

        ↓

## 3️⃣ Decision Engine & Security Layer

### Decision Flow

```mermaid
graph TD
    A[Decision Engine] --> B{Select Highest Priority}
    B --> C[Technical Support]
    B --> D[Product Inquiry]
    B --> E[Account Management]
    B --> F[Default Model]
    
    C --> G[System Prompt]
    D --> G
    E --> G
    F --> G
    
    G --> H[Security Checks]
    H --> I[PII Detection]
    H --> J[Jailbreak Detection]
    H --> K[Semantic Cache]
    
    style A fill:#673AB7,color:white
    style I fill:#F44336,color:white
    style J fill:#F44336,color:white
    style K fill:#4CAF50,color:white
```

### Security & Caching Pipeline

```mermaid
flowchart LR
    A[System Prompt] --> B[PII Check]
    B -->|Block if PII| C[Error Response]
    B -->|No PII| D[Jailbreak Check]
    D -->|Block if Jailbreak| C
    D -->|Safe| E[Check Cache]
    E -->|Cache Hit| F[Return Cached Response]
    E -->|Cache Miss| G[Continue to Model Selection]
    
    style C fill:#FF5252,color:white
    style F fill:#4CAF50,color:white
    style G fill:#2196F3,color:white
```

**Security Features**:
- **PII Detection**: Blocks sensitive data exposure
- **Jailbreak Protection**: Prevents prompt injection
- **Semantic Caching**: Improves response time for similar queries

        ↓ (cache miss, no block)

## 4️⃣ Model & Endpoint Selection

### Auto Model Selection

```mermaid
flowchart LR
    A['model=auto'] --> B[Select from modelRefs]
    B --> C[Check model_config]
    C --> D[Get reasoning_family]
    C --> E[Get preferred_endpoints]
    D --> F[Select Best Model]
    E --> F
    
    style A fill:#4CAF50,color:white
    style F fill:#2196F3,color:white
```

### Endpoint Routing

```mermaid
flowchart LR
    A[Selected Model] --> B{Match Endpoint}
    B -->|deepseek| C[127.0.0.1:8002]
    B -->|ministral| D[127.0.0.1:8001]
    B -->|qwen| E[127.0.0.1:8000]
    
    style A fill:#2196F3,color:white
    style B fill:#9C27B0,color:white
```

## 5️⃣ Execution & Response

### vLLM Processing

```mermaid
sequenceDiagram
    participant E as Envoy
    participant V as vLLM (GPU)
    participant C as Client
    
    E->>V: POST /v1/chat/completions
    Note over E,V: Model: /path/to/selected/model
    V-->>E: OpenAI-style response
    E->>C: Return response
    
    Note over V: GPU-accelerated
    Note over E: Envoy + Semantic Router handle routing & policy
```

### Response Flow

```mermaid
gantt
    title Request Lifecycle Timeline
    dateFormat  HH:mm:ss.SSS
    
    section Request
    Client → Envoy      :a1, 00:00:00.000, 100ms
    Envoy Processing    :a2, after a1, 100ms
    
    section Processing
    Classification      :a3, after a2, 100ms
    Security Checks     :a4, after a3, 150ms
    Model Selection     :a5, after a4, 50ms
    
    section Response
    vLLM Execution      :a6, after a5, 1500ms
    Cache Storage       :a7, after a6, 100ms
    Response to Client  :a8, after a7, 100ms
```

## 🌐 Client Perspective

From the application's point of view:

```mermaid
flowchart LR
    A[Client] -->|'model=auto'| B[Semantic Router]
    B --> C[Intelligent Routing]
    C --> D[Security Layer]
    D --> E[Optimized vLLM]
    E --> F[Response]
    
    style A fill:#4CAF50,color:white
    style F fill:#4CAF50,color:white
    style C fill:#2196F3,color:white
    style D fill:#9C27B0,color:white
```

**Key Benefits**:
- Simplified client integration (just use `model: "auto"`)
- Automatic optimization of model selection
- Built-in security and caching
- Transparent routing logic
