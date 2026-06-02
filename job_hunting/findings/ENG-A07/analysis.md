# ENG-A07 — Revolut · Mid/Senior Software Engineer (Java)

## Company

- Founded 2015, HQ London. CEO Nik Storonsky, CTO Vlad Yatsenko.
- 70m+ retail customers, $75bn valuation, 160+ countries, 13k+ employees, 1k+ engineers.
- Products: payments, banking, FX, crypto, investing, insurance, credit, savings, B2B.
- Engineering culture: startup-within-Revolut, eXtreme Programming influence, rigorous CI/code review, high quality + fast delivery.
- Cloud: **Google Cloud Platform** (not AWS).

---

## Interview process (4 stages)

| Stage | Format | Duration | Focus |
|---|---|---|---|
| 1 — Introductory call | Video (Google Meet) | 30 min | HR intro + experience + basic technical probe |
| 2 — Build It | Live coding in IDE | 1 hour | Java fundamentals, concurrency, testable code + technical conversation |
| 3 — Design It | System design | 1 hour | Architecture from scratch, trade-offs, scalability |
| 4 — Team Fit | Behavioural | 30 min | STAR stories, values alignment |
| — | Offer | — | Compensation package |

**Current stage: Stage 1 (screening call)**

---

## Their actual tech stack

- **Language:** Java
- **Storage:** PostgreSQL via jOOQ, Redis
- **Messaging:** Event-driven architecture
- **Cloud:** Google Cloud Platform
- **Principles:** CQRS, SOLID, SOA, OOP, DDD, TDD, REST
- **Infrastructure:** Microservices, Kubernetes, Docker, Ansible, TeamCity, Terraform
- **Testing:** JUnit, Mockito, Spock, assertj
- **Other frameworks:** SparkJava (REST APIs), JOOQ (Postgres), Flyway (migrations)

---

## Decisions

### Minimal stack for screening call (Stage 1)

Only surface these 8 topics — everything else stays off the table.

| Technology | Reason to keep |
|---|---|
| Java | Core, non-negotiable |
| Spring Boot | Primary framework; SparkJava knowledge transfers |
| PostgreSQL | Real depth, they use it |
| Kafka / event-driven | 50k/sec numbers to defend |
| Microservices + DDD | Explicitly valued; monolith decomposition story |
| Kubernetes + Docker | Infrastructure basics, safe to claim |
| JUnit + Mockito | Their test stack; TDD stories available |
| Redis | In their stack; ElastiCache (Redis) experience |

**Suppressed for Stage 1:**
- AWS (they use GCP — don't open the door)
- JPA / Hibernate (they use jOOQ — avoid ORM debate)
- Terraform, GitHub Actions, Jenkins (off-topic for Stage 1)
- GraphQL, SOAP, TypeScript, React (irrelevant)
- LangChain, RAG, AI tooling (wrong role)
- Spock, assertj, Flyway (not in profile — don't claim)

---

## Profile strengths for this role

- **Sber** — Java backend at Russia's largest bank; exact domain match (high-volume transactional, strict consistency)
- **EPAM** — 50k+ events/sec Kafka, monolith decomposition + DDD, mentoring, TDD from zero
- Banking domain knowledge — financial systems, data integrity, auditability

## Gaps

- jOOQ (they use it; profile has JPA/Hibernate) — don't raise, don't deny
- GCP (profile is AWS) — don't claim cloud depth
- Spock, assertj, Flyway — not in profile
- TeamCity, Ansible — not in profile

---

## Revolut values (relevant for Stage 4 but good to know now)

- **Never Settle** — push, rethink, 10x ambition
- **Dream Team** — lean, diverse, brilliant go-getters
- **Think Deeper** — logic over opinion, data-driven, dive to atoms
- **Get It Done** — execution over ideas, sweat and stretch
- **Deliver WOW** — customer-first, attention to every detail
