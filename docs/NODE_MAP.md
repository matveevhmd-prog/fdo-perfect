# ARCHI — карта вузлів core workflow (згенеровано)

> **Не редагувати руками.** Джерело — `workflows/DEMO_Archi_Agent_Core.json`; генератор — `scripts/gen_node_map.py` (`CLAUDE.md` п. 14, рішення 6).
> Workflow `CKwCsGIwyw9feCY5`, `versionId eb66775d-28dc-476c-85ad-eb7cbcfcccb6`, вузлів: 179, груп за префіксом: 11.

## Типи вузлів

| Тип | Кількість |
|---|---|
| `postgres` | 47 |
| `code` | 37 |
| `telegram` | 36 |
| `if` | 20 |
| `respondToWebhook` | 8 |
| `webhook` | 5 |
| `set` | 4 |
| `memoryPostgresChat` | 3 |
| `agent` | 3 |
| `switch` | 3 |
| `executeWorkflow` | 3 |
| `httpRequest` | 2 |
| `openAi` | 2 |
| `extractFromFile` | 2 |
| `telegramTrigger` | 1 |
| `lmChatOpenAi` | 1 |
| `cron` | 1 |
| `convertToFile` | 1 |

## AN (3)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| AN: Attach Block | `code` | Build MiniApp Data | Is Chat Request? |
| AN: Patch HTML | `code` | Build MiniApp HTML | Respond MiniApp HTML |
| AN: Split Stage Rows | `code` | Fetch Project Metrics (Chat), Fetch Project Metrics (MiniApp) | Build MiniApp Data |

## Doc Intake (16)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| Doc Intake: Attach File Fields | `code` | Doc Intake: Download File | Doc Intake: Run Document Intake |
| Doc Intake: Branch File Or Link? | `if` | Doc Intake: Is Contract Content? | [0] Doc Intake: Extract File Id, [1] Doc Intake: Extract Drive Link |
| Doc Intake: Download File | `telegram` | Doc Intake: Extract File Id | Doc Intake: Attach File Fields |
| Doc Intake: Extract Drive Link | `code` | Doc Intake: Branch File Or Link? | Doc Intake: Write Link URL |
| Doc Intake: Extract File Id | `code` | Doc Intake: Branch File Or Link? | Doc Intake: Download File |
| Doc Intake: Extract Set Project | `code` | Doc Intake: Is Set Command? | Doc Intake: Write Mode |
| Doc Intake: Is Contract Content? | `if` | Telegram Trigger | Doc Intake: Branch File Or Link? |
| Doc Intake: Is Set Command? | `if` | Telegram Trigger | Doc Intake: Extract Set Project |
| Doc Intake: Reset Mode After File | `postgres` | Doc Intake: Send File Confirmation | — |
| Doc Intake: Reset Mode After Link | `postgres` | Doc Intake: Send Link Confirmation | — |
| Doc Intake: Run Document Intake | `executeWorkflow` | Doc Intake: Attach File Fields | Doc Intake: Send File Confirmation |
| Doc Intake: Send File Confirmation | `telegram` | Doc Intake: Run Document Intake | Doc Intake: Reset Mode After File |
| Doc Intake: Send Link Confirmation | `telegram` | Doc Intake: Write Link URL | Doc Intake: Reset Mode After Link |
| Doc Intake: Send Set Confirmation | `telegram` | Doc Intake: Write Mode | — |
| Doc Intake: Write Link URL | `postgres` | Doc Intake: Extract Drive Link | Doc Intake: Send Link Confirmation |
| Doc Intake: Write Mode | `postgres` | Doc Intake: Extract Set Project | Doc Intake: Send Set Confirmation |

## Import (16)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| Import: Agent | `agent` | Import: Build Prompt, Import: Postgres Chat Memory, WR: OpenAI Chat Model | Import: Parse Agent Output |
| Import: Build Prompt | `code` | WR: Route | Import: Agent |
| Import: Clear Draft After Final | `postgres` | Import: Send Final Confirmation | — |
| Import: Insert Money Rows | `postgres` | Import: Split Money Rows | — |
| Import: Insert Time Rows | `postgres` | Import: Split Time Rows | — |
| Import: Is Final? | `if` | Import: Parse Agent Output | [0] Import: Split Time Rows, [0] Import: Split Money Rows, [0] Import: Send Final Confirmation, [1] Import: Send Draft Reply |
| Import: Parse Agent Output | `code` | Import: Agent | Import: Is Final? |
| Import: Postgres Chat Memory | `memoryPostgresChat` | — | Import: Agent (ai_memory) |
| Import: Reset Draft | `postgres` | WR: Route | Import: Send Reset Confirmation |
| Import: Send Draft Reply | `telegram` | Import: Is Final? | — |
| Import: Send Final Confirmation | `telegram` | Import: Is Final? | Import: Clear Draft After Final |
| Import: Send Project Confirmation | `telegram` | Import: Write Project Mode | — |
| Import: Send Reset Confirmation | `telegram` | Import: Reset Draft | — |
| Import: Split Money Rows | `code` | Import: Is Final? | Import: Insert Money Rows |
| Import: Split Time Rows | `code` | Import: Is Final? | Import: Insert Time Rows |
| Import: Write Project Mode | `postgres` | WR: Route | Import: Send Project Confirmation |

## K (7)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| K: Ingest Commit | `executeWorkflow` | WR: Route | K: Reset Mode |
| K: Ingest Preview | `executeWorkflow` | WR: Route | K: Save Mode |
| K: Reset Mode | `postgres` | K: Ingest Commit | K: Send Commit Result |
| K: Save Mode | `postgres` | K: Ingest Preview | K: Send Preview |
| K: Send Commit Result | `telegram` | K: Reset Mode | — |
| K: Send Hint | `telegram` | WR: Route | — |
| K: Send Preview | `telegram` | K: Save Mode | — |

## KP Log (5)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| KP Log: Extract Count | `code` | KP Log: Is Count Command? | KP Log: Insert Row |
| KP Log: Fetch Month Total | `postgres` | KP Log: Insert Row | KP Log: Send Confirmation |
| KP Log: Insert Row | `postgres` | KP Log: Extract Count | KP Log: Fetch Month Total |
| KP Log: Is Count Command? | `if` | Telegram Trigger | KP Log: Extract Count |
| KP Log: Send Confirmation | `telegram` | KP Log: Fetch Month Total | — |

## M (3)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| M: Build Project Keyboard | `code` | M: Fetch Project List | M: Send Project Picker |
| M: Fetch Project List | `postgres` | WR: Route | M: Build Project Keyboard |
| M: Send Project Picker | `httpRequest` | M: Build Project Keyboard | — |

## Meeting (14)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| Meeting: Agent | `agent` | Meeting: Build Prompt, Meeting: Postgres Chat Memory, WR: OpenAI Chat Model | Meeting: Parse Agent Output |
| Meeting: Build Prompt | `code` | WR: Route | Meeting: Agent |
| Meeting: Clear Draft After Final | `postgres` | Meeting: Send Confirmation | — |
| Meeting: Insert Rows | `postgres` | Meeting: Split Items | — |
| Meeting: Is Final? | `if` | Meeting: Parse Agent Output | [0] Meeting: Split Items, [0] Meeting: Send Confirmation, [1] Meeting: Send Draft Reply |
| Meeting: Parse Agent Output | `code` | Meeting: Agent | Meeting: Is Final? |
| Meeting: Postgres Chat Memory | `memoryPostgresChat` | — | Meeting: Agent (ai_memory) |
| Meeting: Reset Draft | `postgres` | WR: Route | Meeting: Send Reset Confirmation |
| Meeting: Send Confirmation | `telegram` | Meeting: Is Final? | Meeting: Clear Draft After Final |
| Meeting: Send Draft Reply | `telegram` | Meeting: Is Final? | — |
| Meeting: Send Project Confirmation | `telegram` | Meeting: Write Project Mode | — |
| Meeting: Send Reset Confirmation | `telegram` | Meeting: Reset Draft | — |
| Meeting: Split Items | `code` | Meeting: Is Final? | Meeting: Insert Rows |
| Meeting: Write Project Mode | `postgres` | WR: Route | Meeting: Send Project Confirmation |

## WR (62)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| WR: Agent | `agent` | WR: Build WR Prompt, WR: OpenAI Chat Model, WR: Postgres Chat Memory | WR: Parse Agent Output |
| WR: Analyze Image | `openAi` | WR: Download Photo | WR: Normalize Vision |
| WR: Build Status Text | `code` | WR: Fetch Report Status | WR: Send Status |
| WR: Build WR Prompt | `code` | WR: Final Has Data? | WR: Agent |
| WR: Clear Draft After Final | `postgres` | WR: Send Final Report | — |
| WR: Detect Doc Type | `switch` | WR: Download Document | [0] WR: Extract PDF Text, [2] WR: Extract TXT Text, [2] WR: Send Unsupported Format |
| WR: Determine Route | `code` | WR: Read Mode | Is Parallel Cmd? |
| WR: Download Audio | `telegram` | WR: Is Audio or Photo? | WR: Transcribe |
| WR: Download Document | `telegram` | WR: Is Audio or Photo? | WR: Detect Doc Type |
| WR: Download Photo | `telegram` | WR: Is Audio or Photo? | WR: Analyze Image |
| WR: Ensure Mode Table | `postgres` | Telegram Trigger | WR: Read Mode |
| WR: Ensure Plan Table | `postgres` | WR: Fetch Payment Schedule | WR: Fetch This Week Plan |
| WR: Extract PDF Text | `extractFromFile` | WR: Detect Doc Type | WR: Normalize Document |
| WR: Extract TXT Text | `extractFromFile` | WR: Detect Doc Type | WR: Normalize Document |
| WR: Fetch Inbox | `postgres` | WR: Fetch Money Log Acts | WR: Final Has Data? |
| WR: Fetch Money Log Acts | `postgres` | WR: Fetch Project Metrics Static | WR: Fetch Inbox |
| WR: Fetch Payment Schedule | `postgres` | WR: Route | WR: Ensure Plan Table |
| WR: Fetch Plan For Project Confirm | `postgres` | WR: Write Project Mode | WR: Format Plan For Project Confirm |
| WR: Fetch Project Metrics Static | `postgres` | WR: Fetch This Week Plan | WR: Fetch Money Log Acts |
| WR: Fetch Report Status | `postgres` | WR: Route | WR: Build Status Text |
| WR: Fetch Report Today | `postgres` | WR: Is Final?, WR: Save Weekly Snapshot | WR: Render Report |
| WR: Fetch This Week Plan | `postgres` | WR: Ensure Plan Table | WR: Fetch Project Metrics Static |
| WR: Final Has Data? | `if` | WR: Fetch Inbox | [0] WR: Send Final No Data, [1] WR: Build WR Prompt |
| WR: Format Plan For Project Confirm | `code` | WR: Fetch Plan For Project Confirm | WR: Send Project Confirmation |
| WR: Hard Logic Engine | `code` | WR: Normalize Audio, WR: Normalize Document, WR: Normalize Text, WR: Normalize Vision | WR: Route |
| WR: Inbox Add | `postgres` | WR: Route | WR: Send Inbox Ack |
| WR: Inbox Consume | `postgres` | WR: Parse Agent Output | — |
| WR: Is Audio or Photo? | `switch` | WR: Is WR Flow? | [0] WR: Download Audio, [1] WR: Download Photo, [2] WR: Normalize Text, [3] WR: Download Document |
| WR: Is Final (Render)? | `if` | WR: Render Report | [0] WR: Send Final Report, [1] WR: Send Draft Reply |
| WR: Is Final? | `if` | WR: Parse Agent Output | [0] WR: Merge Carryover, [0] WR: Save Weekly Snapshot, [1] WR: Fetch Report Today |
| WR: Is WR Flow? | `if` | Is Parallel Cmd? | [0] WR: Is Audio or Photo?, [1] Is Status Command? |
| WR: Merge Carryover | `code` | WR: Is Final? | WR: Split New Plan Items |
| WR: Normalize Audio | `set` | WR: Transcribe | WR: Hard Logic Engine |
| WR: Normalize Document | `set` | WR: Extract PDF Text, WR: Extract TXT Text | WR: Hard Logic Engine |
| WR: Normalize Text | `set` | WR: Is Audio or Photo? | WR: Hard Logic Engine |
| WR: Normalize Vision | `set` | WR: Analyze Image | WR: Hard Logic Engine |
| WR: OpenAI Chat Model | `lmChatOpenAi` | — | WR: Agent (ai_languageModel), Import: Agent (ai_languageModel), Meeting: Agent (ai_languageModel) |
| WR: Parse Agent Output | `code` | WR: Agent | WR: Is Final?, WR: Inbox Consume |
| WR: Postgres Chat Memory | `memoryPostgresChat` | — | WR: Agent (ai_memory) |
| WR: Read Mode | `postgres` | WR: Ensure Mode Table | WR: Determine Route |
| WR: Render Report | `code` | WR: Fetch Report Today | WR: Is Final (Render)? |
| WR: Reset Draft | `postgres` | WR: Route | WR: Send Reset Confirmation |
| WR: Reset Mode | `postgres` | WR: Route | WR: Send Clear Confirmation |
| WR: Route | `switch` | WR: Hard Logic Engine | [0] WR: Reset Mode, [1] WR: Send Need Project, [2] WR: Write Project Mode, [3] WR: Fetch Report Status, [4] WR: Write Reference Mode, [5] WR: Fetch Payment Schedule, [6] Import: Write Project Mode, [7] Import: Build Prompt, [8] Meeting: Write Project Mode, [9] Meeting: Build Prompt, [10] WR: Reset Draft, [11] Import: Reset Draft, [12] Meeting: Reset Draft, [13] K: Ingest Preview, [14] K: Ingest Commit, [15] K: Send Hint, [16] M: Fetch Project List, [17] WR: Inbox Add |
| WR: Save Next Week Plan | `postgres` | WR: Split New Plan Items | — |
| WR: Save Weekly Snapshot | `postgres` | WR: Is Final? | WR: Fetch Report Today |
| WR: Schedule Reminder (Fri 10:00) | `cron` | — | — |
| WR: Send Clear Confirmation | `telegram` | WR: Reset Mode | — |
| WR: Send Draft Reply | `telegram` | WR: Is Final (Render)? | — |
| WR: Send Final No Data | `telegram` | WR: Final Has Data? | — |
| WR: Send Final Report | `telegram` | WR: Is Final (Render)? | WR: Clear Draft After Final |
| WR: Send Inbox Ack | `telegram` | WR: Inbox Add | — |
| WR: Send Need Project | `telegram` | WR: Route | — |
| WR: Send Project Confirmation | `telegram` | WR: Format Plan For Project Confirm | — |
| WR: Send Reference Stub | `telegram` | WR: Write Reference Mode | — |
| WR: Send Reset Confirmation | `telegram` | WR: Reset Draft | — |
| WR: Send Status | `telegram` | WR: Build Status Text | — |
| WR: Send Unsupported Format | `telegram` | WR: Detect Doc Type | — |
| WR: Split New Plan Items | `code` | WR: Merge Carryover | WR: Save Next Week Plan |
| WR: Transcribe | `openAi` | WR: Download Audio | WR: Normalize Audio |
| WR: Write Project Mode | `postgres` | WR: Route | WR: Fetch Plan For Project Confirm |
| WR: Write Reference Mode | `postgres` | WR: Route | WR: Send Reference Stub |

## WR-Render (2)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| WR-Render: Is Valid InitData | `if` | WR-Render: Validate InitData | [0] Fetch All Project Metrics, [1] Respond Weekly Render Unauthorized |
| WR-Render: Validate InitData | `code` | Weekly Render Data Webhook | WR-Render: Is Valid InitData |

## Xlsx (4)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| Xlsx: Build Rows | `code` | Fetch All Weekly Snapshots | Xlsx: Convert To File |
| Xlsx: Convert To File | `convertToFile` | Xlsx: Build Rows | Respond Xlsx File |
| Xlsx: Is Valid InitData | `if` | Xlsx: Validate InitData | [0] Fetch All Weekly Snapshots, [1] Respond Xlsx Unauthorized |
| Xlsx: Validate InitData | `code` | Xlsx Export Webhook | Xlsx: Is Valid InitData |

## (без префікса) (47)

| Вузол | Тип | Звідки | Куди |
|---|---|---|---|
| Attach Meeting Log | `code` | Fetch Meeting Log (Chat) | Build Request Body |
| Build MiniApp Data | `code` | AN: Split Stage Rows | AN: Attach Block |
| Build MiniApp HTML | `code` | MiniApp Page Webhook | AN: Patch HTML |
| Build Request Body | `code` | Attach Meeting Log | Call Anthropic |
| Build Status Text | `code` | Fetch Status Metrics | Send Status Reply |
| Build Weekly Render Data | `code` | Fetch Weekly Snapshots For Grid | Respond Weekly Render Data |
| Build Weekly Render HTML | `code` | Weekly Render Page Webhook | Respond Weekly Render HTML |
| Call Anthropic | `httpRequest` | Build Request Body | Sanitize Reply |
| Fetch All Project Metrics | `postgres` | WR-Render: Is Valid InitData | Fetch Weekly Snapshots For Grid |
| Fetch All Weekly Snapshots | `postgres` | Xlsx: Is Valid InitData | Xlsx: Build Rows |
| Fetch KP Log Sum (Chat) | `postgres` | Is Owner View Request? | Fetch Project Metrics (Chat) |
| Fetch KP Log Sum (MiniApp) | `postgres` | Is Valid InitData | Fetch Project Metrics (MiniApp) |
| Fetch Meeting Log (Chat) | `postgres` | Is Chat Request? | Attach Meeting Log |
| Fetch Project Metrics (Chat) | `postgres` | Fetch KP Log Sum (Chat) | AN: Split Stage Rows |
| Fetch Project Metrics (MiniApp) | `postgres` | Fetch KP Log Sum (MiniApp) | AN: Split Stage Rows |
| Fetch Status Metrics | `postgres` | Is Status Command? | Build Status Text |
| Fetch Weekly Snapshots For Grid | `postgres` | Fetch All Project Metrics | Build Weekly Render Data |
| Is Chat Request? | `if` | AN: Attach Block | [0] Fetch Meeting Log (Chat), [1] Respond MiniApp Data |
| Is Fixed Question? | `if` | Sanitize Reply | [0] Send Reply (Questions), [1] Send Reply |
| Is Owner View Request? | `if` | Is Questions Menu? | [0] Send MiniApp Open Button, [1] Fetch KP Log Sum (Chat) |
| Is Parallel Cmd? | `if` | WR: Determine Route | [1] WR: Is WR Flow? |
| Is Questions Menu? | `if` | Is Weekly Render Request? | [0] Send Questions Menu, [1] Is Owner View Request? |
| Is Status Command? | `if` | WR: Is WR Flow? | [0] Fetch Status Metrics, [1] Is Weekly Render Request? |
| Is Valid InitData | `if` | Validate InitData | [0] Fetch KP Log Sum (MiniApp), [1] Respond Unauthorized |
| Is Weekly Render Request? | `if` | Is Status Command? | [0] Send Weekly Render Button, [1] Is Questions Menu? |
| MiniApp Data Webhook | `webhook` | — | Validate InitData |
| MiniApp Page Webhook | `webhook` | — | Build MiniApp HTML |
| Respond MiniApp Data | `respondToWebhook` | Is Chat Request? | — |
| Respond MiniApp HTML | `respondToWebhook` | AN: Patch HTML | — |
| Respond Unauthorized | `respondToWebhook` | Is Valid InitData | — |
| Respond Weekly Render Data | `respondToWebhook` | Build Weekly Render Data | — |
| Respond Weekly Render HTML | `respondToWebhook` | Build Weekly Render HTML | — |
| Respond Weekly Render Unauthorized | `respondToWebhook` | WR-Render: Is Valid InitData | — |
| Respond Xlsx File | `respondToWebhook` | Xlsx: Convert To File | — |
| Respond Xlsx Unauthorized | `respondToWebhook` | Xlsx: Is Valid InitData | — |
| Sanitize Reply | `code` | Call Anthropic | Is Fixed Question? |
| Send MiniApp Open Button | `telegram` | Is Owner View Request? | — |
| Send Questions Menu | `telegram` | Is Questions Menu? | — |
| Send Reply | `telegram` | Is Fixed Question? | — |
| Send Reply (Questions) | `telegram` | Is Fixed Question? | — |
| Send Status Reply | `telegram` | Build Status Text | — |
| Send Weekly Render Button | `telegram` | Is Weekly Render Request? | — |
| Telegram Trigger | `telegramTrigger` | — | WR: Ensure Mode Table, Doc Intake: Is Set Command?, Doc Intake: Is Contract Content?, KP Log: Is Count Command? |
| Validate InitData | `code` | MiniApp Data Webhook | Is Valid InitData |
| Weekly Render Data Webhook | `webhook` | — | WR-Render: Validate InitData |
| Weekly Render Page Webhook | `webhook` | — | Build Weekly Render HTML |
| Xlsx Export Webhook | `webhook` | — | Xlsx: Validate InitData |
