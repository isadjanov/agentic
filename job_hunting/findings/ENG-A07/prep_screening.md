# ENG-A07 — Revolut · Stage 1 Screening Prep

**Format:** 30 min video call (Google Meet)
**Agenda:** HR intro (10 min) → background + scenario-based technical questions (10–15 min) → Q&A (5–7 min)

---

## Time budget

| Segment | Your allocation |
|---|---|
| Why Revolut | 45 sec max — then stop |
| Background walk-through | 90 sec max — then stop |
| Each technical answer | 2–3 min — include one concrete example |
| Each STAR story | 2–2.5 min — STAR beats + closing line |
| Your questions | 2 questions, 30 sec each |

If you go over on any answer, the recruiter will cut you. Better to stop yourself and offer to go deeper if they want.

---

## 1. Why Revolut

> "I've spent five years building Java backend systems at EPAM — microservices, Kafka, high-throughput pipelines — and before that at Sber, Russia's largest bank, where financial correctness and strict consistency were non-negotiable. Revolut is 70 million customers, 160 countries, transactions moving at a scale where every design decision has real financial consequences. That's the intersection of serious engineering and hard domain problems I want to work on."

**45 seconds. Stop after that sentence. Do not add more.**

---

## 2. Background walk-through (90 sec)

> "I'm a Java backend engineer. Currently Lead Developer at EPAM — five years building distributed systems for enterprise clients: microservices, Kafka event-driven pipelines, PostgreSQL, Kubernetes, DDD. Before EPAM, I was at Sber building Java/Spring Boot services for core banking — transactional systems, strict data integrity, financial domain.
>
> I came to engineering from consulting and entrepreneurship. Made a deliberate decision to cross that boundary — taught myself CS from scratch, went through Sberbank's Java school, and built from there. Seven years of deliberate effort. That's the arc."

**Do NOT volunteer the full career chronology — Deloitte, VW, BDO — unless asked.**
If asked: "I spent about a decade in consulting and then built my own firm before making the switch to engineering. Happy to go into it if it's useful."

---

## 3. Technical questions — by topic

Revolut's introductory call explicitly covers **"fundamental topics required for this role."** Their own tech summary for Stage 1 lists: Java, PostgreSQL/jOOQ, Redis, CQRS, SOLID, DDD, TDD, REST, Microservices, Kubernetes, Docker, event-driven architecture.

---

### CQRS (listed first in their stack — expect this)

**What it is:**
Command Query Responsibility Segregation — separate the write model (commands that change state) from the read model (queries that return data). Commands go through domain logic and emit events; the read model is a denormalised projection optimised for queries.

**When to use it:**
When read and write load patterns differ significantly, or when the domain is complex enough that a single model is a compromise for both. Classic fit: payment processing (write = strict consistency, audit trail; read = fast balance lookups, transaction history).

**Trade-offs:**
Eventual consistency between write and read models. Added complexity — you now maintain two models and the projection logic. Not appropriate for simple CRUD.

**Your anchor:** Monolith decomposition at EPAM used domain-driven boundaries that naturally map to CQRS: command side owned by the domain service, read side as a separate projection. $300K+ impact.

---

### Idempotency (critical for payments — will come up)

**What it is:**
An operation is idempotent if applying it multiple times produces the same result as applying it once. In payments: a payment request must be processed exactly once even if retried.

**How you implement it:**
- Client generates a unique `idempotency-key` per request (UUID)
- Server stores `(idempotency-key → result)` in a durable store (Redis or DB) before processing
- On retry with the same key: return the stored result, do not reprocess
- Key must be scoped to the operation type and user

**Edge cases to know:**
- What if the server crashes after processing but before storing the result? → At-least-once delivery + idempotent consumers
- What if the idempotency key expires? → Define TTL based on retry window

**Your anchor:** Kafka consumer design at EPAM — distributed consumers with thread-safe state management at 50k/sec. Deduplication was a design constraint.

---

### Java & Concurrency

Questions likely at screening level:

- **`synchronized` vs `ReentrantLock`**: `synchronized` is simpler, built into the language, tied to the object monitor. `ReentrantLock` gives you tryLock (non-blocking attempt), timeout, interruptible locking, and fairness policy. Use `ReentrantLock` when you need more control.
- **`volatile`**: Guarantees visibility — writes are immediately visible to other threads. Does NOT guarantee atomicity of compound operations (read-modify-write still needs synchronisation).
- **`ConcurrentHashMap`**: Segment-level locking (Java 8+: CAS + synchronized on bucket level). `HashMap` is not thread-safe at all. `Hashtable` is fully synchronised but coarse-grained.
- **Race condition**: Two threads access shared mutable state concurrently and the outcome depends on timing. Prevent with synchronisation, atomic variables, or immutability.
- **Java Memory Model**: Defines when writes by one thread are visible to another. `happens-before` relationship — established by synchronisation, volatile writes, thread start/join.

**Your anchor:** Thread safety in Kafka consumer design — 50k/sec with backpressure across distributed consumers.

---

### Kafka & Event-driven

- **Message ordering**: Guaranteed within a partition. If ordering matters across a topic, use a single partition or a partition key that groups related messages (e.g. user ID, account ID).
- **Consumer group rebalancing**: Triggered when a consumer joins/leaves or a partition is added. During rebalance, consumption stops. Minimise by using `CooperativeStickyAssignor` (incremental rebalance), keeping consumers healthy, and avoiding long processing times.
- **Exactly-once semantics**: Kafka supports EOS via idempotent producers + transactions. Producer assigns sequence numbers per partition; broker deduplicates. Transactional APIs allow atomic write across multiple partitions.
- **Backpressure**: If consumers are slower than producers, partitions lag. Handle by: scaling consumer group, batching, async processing with bounded queues, or reducing producer rate.

**Your anchor:** 50k+ events/sec at sub-100ms P99 with backpressure handling across distributed consumers.

---

### PostgreSQL & Consistency

- **Isolation levels**: Read Uncommitted (dirty reads), Read Committed (no dirty reads — Postgres default), Repeatable Read (no non-repeatable reads), Serializable (no phantom reads, full isolation). Each prevents a class of anomalies; higher levels have higher locking cost.
- **Optimistic vs Pessimistic locking**: Optimistic — read, compute, write with version check (fail if version changed). Good for low-contention. Pessimistic — lock on read (`SELECT FOR UPDATE`). Good for high-contention or when conflicts are expensive.
- **Deadlock**: Two transactions each hold a lock the other needs. Postgres detects and kills one. Prevent by always acquiring locks in the same order across transactions.
- **N+1**: Loading a list of N entities and then issuing N queries for related data. Solve with JOIN, `IN` clause, or batch loading.
- **Covering index**: Index that includes all columns needed by a query — allows index-only scan, no heap access.

**Your anchor:** Owned PostgreSQL schema design at Sber (banking) and EPAM. Resolved N+1 via JPA/Hibernate profiling.

---

### Architecture & DDD

- **Bounded context**: A logical boundary within which a domain model is internally consistent. The same term can mean different things in different contexts (e.g. "account" in payments vs "account" in identity). Services map to bounded contexts.
- **Distributed transactions**: Two options — 2PC (synchronous, locks resources, fragile in distributed systems) or Saga (sequence of local transactions with compensating actions on failure). Sagas are the standard for microservices.
- **Eventual consistency**: Acceptable when: the cost of inconsistency is low, the window is short, and there's a reconciliation mechanism. Not acceptable for: money movement, balance reads after writes the user just made.

**Your anchor:** Decomposed monolith at EPAM — 3 bounded domains, independently deployable services, $300K+ impact.

---

### Testing & Reliability

- **Test pyramid**: Unit (fast, isolated, many) → Integration (slower, tests real dependencies, fewer) → E2E (slowest, full system, minimal). Revolut uses JUnit + Mockito + Spock + assertj.
- **Circuit breaker**: Stops calling a failing downstream service after a threshold of failures. States: Closed (normal), Open (fail fast), Half-Open (probe recovery). Prevents cascading failures.
- **Zero-downtime deployment**: Blue/green (two environments, switch traffic) or rolling update (replace instances gradually). Requires: backwards-compatible API changes, database migrations that support both old and new code simultaneously.
- **Observability**: Logs (what happened), metrics (how the system is behaving), traces (how a request flowed). In production: know your SLIs (latency, error rate, throughput) and alert on SLOs.

**Your anchor:** TDD from zero across 3+ products, three-tier pyramid, cut post-release defects within one quarter.

---

## 4. How to handle unknowns (Think Deeper — do this)

Revolut's value: *"We dive deep until we get to atoms. If we don't know something — we bet, collect the data, and reiterate."*

If you don't know something:
1. **Name what you do know**: "I haven't used jOOQ specifically, but I've worked extensively with PostgreSQL and understand the trade-offs between type-safe SQL builders and ORM frameworks."
2. **Reason through it**: "Based on what I know about SQL query building, I'd expect jOOQ to give you more explicit control over query shape than Hibernate — which matters in high-throughput financial systems where query plans are critical."
3. **Don't bluff. Don't apologise.** State the boundary clearly, then reason past it.

**Specific gap to prep:**
- **jOOQ**: "I've used JPA/Hibernate extensively. I understand jOOQ is a type-safe SQL DSL — trades the ORM abstraction for explicit SQL control. I can see why that makes sense in a high-throughput financial backend where query predictability matters."
- **GCP**: "My cloud background is AWS. The concepts transfer — managed Kubernetes, object storage, managed databases, pub/sub. Happy to ramp on GCP specifics."

---

## 5. STAR stories for Stage 1

The screening will probe at least one scenario. Most likely trigger: *"Tell me about a time you had significant technical impact"* or *"Tell me about a challenge."* Secondary trigger: *"Why did you transition into engineering?"*

---

### Story A — Architecture & Influence (primary)
**Use for:** Technical challenge, ownership, impact, influencing without authority
**Hook:** *"At EPAM I joined a project where the business logic was built on static classes — it had made early development fast, but by the time I arrived the domain boundaries had collapsed and technical debt was spreading. I had no authority to mandate a change. The original architect was still on the team."*
**Key beats:**
- Saw the problem clearly, couldn't ignore it
- Tried direct approach → hit emotional wall (identity tied to the architecture)
- Changed approach: built a structured analytical report with codebase evidence, proposed DDD evolution framed as natural next step, not criticism
- Presented to full team with explicit invitation to criticise
- Result: original architect became a participant; technical debt backlog created; clear domain boundaries for all new development
**Closing line:** *"A situation that started as conflict ended as alignment. Technical correctness isn't enough — you have to understand the human dynamics and give people a role in the solution."*
**Revolut values:** Think Deeper + Get It Done

---

### Story B — Scale & Delivery
**Use for:** High-load systems, Kafka, performance, delivery under pressure
**Hook:** *"At EPAM I designed and delivered event-driven microservices processing financial data — the requirement was 50,000 events per second at sub-100ms P99."*
**Key beats:**
- Designed consumer group topology and partition strategy
- Built backpressure controls and thread-safe state management
- Sustained throughput under variable load on Kubernetes
- Sub-100ms P99 maintained in production
**Closing line:** *"The key was designing for failure from the start — not just for the happy path."*
**Revolut values:** Never Settle + Get It Done

---

### Story C — Never Settle (use if asked about career transition or learning)
**Use for:** "Why did you switch to engineering?", "Tell me about a time you took on something outside your expertise"
**Hook:** *"After a decade in consulting and entrepreneurship, I hit a wall I couldn't talk my way around — I could define what needed to be built but I couldn't build it myself. I decided that needed to change."*
**Key beats:**
- Taught myself CS via Harvard CS50 while running consulting firm full time — no safety net, just evenings
- Found Sberbank's Java school in Moscow — 150km from where I worked at Volkswagen
- Negotiated half-day schedule, traveled every other day, returned at 1am
- Finished the school → Sberbank didn't offer a job
- Spent a month cold-calling their managers asking for any open-source foothold
- Got the offer. Joined as Java developer. Moved to EPAM five years later.
**Closing line:** *"The whole transition took seven years of compounding, deliberate effort. I don't dabble — when I decide to go somewhere, I go all the way."*
**Revolut values:** Never Settle

---

## 6. Questions to ask them

Ask exactly 2. Slot into the Q&A at the end.

1. **"Which product team is this role being recruited for — or is placement decided after the process?"**
   *(Tells you what domain to prep for Stages 2–3. Card Payments, Retail, and Technology teams all have different technical focus.)*

2. **"For the Build It round — is the live coding problem typically a pure algorithm or closer to a real-world domain scenario?"**
   *(Tells you exactly how to prepare: LeetCode-style vs domain modelling.)*

---

## 7. Things NOT to raise

- AWS in any depth (they use GCP — saying "I have strong AWS background" opens a gap conversation)
- JPA/Hibernate as your primary strength (they use jOOQ — don't invite the comparison)
- AI/LangChain/RAG tooling (wrong role)
- Full career history before Sber (unless asked — it dilutes the engineering narrative)
- Salary, remote preferences, or visa (Stage 1 is not the time)
- Spring Boot as a potential mismatch (they use SparkJava — don't raise it; your Java knowledge transfers)
