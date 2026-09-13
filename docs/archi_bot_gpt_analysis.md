Ось структурований аналіз документа згідно з вашим запитом:

---

# Аналіз бізнес-сесії ARCHI Bot з ChatGPT

## 1. КОРОТКЕ РЕЗЮМЕ

ARCHI Bot — це AI-оркестраційний шар для управління портфелем будівельних проектів, що інтегрується з n8n, Postgres та Telegram і продається архітектурно-будівельним компаніям по підписці. Основна ідея продукту — перетворити хаотичний ручний збір управлінської інформації власником компанії на швидкий, достовірний та керований процес. GPT провів аудит поточного DEMO, зосередившись на сценарії "Owner Morning Test": чи може власник за ранковою кавою за 30-60 секунд зрозуміти загальний стан компанії, виявити проблеми, отримати докази та сформулювати конкретні управлінські дії. Аудит виявив, що технічний каркас ARCHI сильний, але "Owner Morning Experience" ще не зібраний в єдину безперервну управлінську траєкторію. Головний висновок — необхідно зосередитися на доведенні до досконалості 10 ключових "Owner Questions" та забезпеченні прозорості даних, а не на розширенні функціоналу.

## 2. БІЛЬ КЛІЄНТА

GPT визначив наступні проблеми власників архітектурно-будівельних компаній, які ARCHI Bot має закривати:

*   **Відсутність швидкого огляду:** Власник не може за 30-60 секунд зрозуміти загальний стан портфеля проектів.
*   **Невизначеність пріоритетів:** Не розуміє, чи потрібно йому сьогодні щось робити, і куди саме дивитися.
*   **Складність отримання відповідей:** Важко природно перейти до конкретного питання та отримати відповідь із реальних структурованих даних.
*   **Відсутність довіри до даних:** Не розуміє, звідки взявся висновок, і не може "drill-down" до проекту/сигналу.
*   **Хаотичні комунікації:** Витрачає 20 хвилин на пошук по таблицях або змушений дзвонити "розкажи, що у нас там".
*   **Непрозорість фінансів:** Не може швидко зрозуміти фінансовий прогноз проекту, чи вистачить грошей на зарплату, runway команди, ризик касового розриву, виконання річного плану прибутку.
*   **Проблеми з дедлайнами:** Не бачить прострочених дедлайнів або тих, що під загрозою.
*   **Ризики від ключових клієнтів:** Не може швидко оцінити ризики, пов'язані з якірними клієнтами, або отримати останні домовленості.
*   **Відсутність конкретики в діях:** Не може сформулювати конкретний наступний дзвінок конкретній людині.

**Чи ARCHI Bot їх реально закриває (за оцінкою GPT):**

*   **PASS:** Власник заходить у Telegram, відкриває ARCHI (MiniApp), може drill-down у проект, бачить фінансовий прогноз проекту (рентабельність, прибуток, ETC, CPI, SPI).
*   **PARTIAL:** Бачить стан портфеля, розуміє "все нормально чи ні?" (є групи/метрики, але не зведено до головного рішення), розуміє, куди дивитися (є групування проектів), бачить прострочені дедлайни (є EVM логіка, але сценарій не підтверджено), може запитати "де може запалати?" (якість сценарію не доведена), може отримати останні домовленості (meeting flow існує), може пройти від питання до доказу (дані/картки є, але traceability не доведено), відповідь веде до конкретної людини (routing не повний).
*   **FAIL:** Не бачить контуру "чи вистачить грошей на зарплату", "runway команди", "ризик касового розриву", "виконання річного плану прибутку", "питання про якірного клієнта".

## 3. КІЛЕР-ФІЧІ

GPT визначив наступні технічні компоненти ARCHI, які є основою для кілер-фіч:

*   **Telegram entry point:** Власник відкриває ARCHI прямо в Telegram, без додаткових логінів чи переходу на окремі сайти. **Чому продавана:** Максимально низький поріг входу, звичне середовище для швидкого доступу до інформації.
*   **MiniApp / Owner View:** Інтерактивний дашборд у Telegram, що надає агрегований огляд портфеля. **Чому продавана:** Зручний та швидкий доступ до ключових метрик та статусів.
*   **Google Sheets як DEMO Flat / Postgres state:** Гнучке джерело даних для DEMO, що дозволяє швидко інтегрувати дані. **Чому продавана:** Демонструє можливість роботи з різними джерелами даних, включаючи прості та поширені.
*   **Project cards:** Деталізовані картки по кожному проекту з ключовими показниками. **Чому продавана:** Дозволяє швидко зануритися в деталі конкретного проекту.
*   **EVM (Earned Value Management), CPI (Cost Performance Index), SPI (Schedule Performance Index), profitability, ETC (Estimate To Complete):** Набір FDO-метрик для оцінки ефективності та прогнозування проектів. **Чому продавана:** Надає глибоку аналітику для раннього виявлення відхилень та прогнозування.
*   **Weekly reporting / Meeting capture:** Механізми для збору регулярних звітів та фіксації домовленостей з нарад. **Чому продавана:** Забезпечує актуальність даних та прозорість комунікацій.
*   **AI layer:** Шар штучного інтелекту для інтерпретації даних та формування відповідей. **Чому продавана:** Перетворює сирі дані на зрозумілі управлінські висновки.
*   **Structured workflow:** Забезпечує логічний потік даних та процесів. **Чому продавана:** Гарантує надійність та послідовність роботи системи.

**Сценарій «ранкового дайджесту» в Telegram:**

Власник архітектурної/будівельної компанії за ранковою кавою відкриває Telegram, натискає кнопку ARCHI Bot і одразу бачить ключові метрики по проектах.

**Як має виглядати перша демо-версія (Owner Morning Home):**

*   **Блок 1. Головна відповідь:**
    *   🟢 / 🟡 / 🔴 Стан компанії зараз.
    *   Одна фраза: "Сьогодні втручання власника не потрібне" або "Є 2 питання, де сьогодні потрібна ваша увага".
*   **Блок 2. «Що мені потрібно знати?»:**
    *   3–5 головних сигналів (наприклад: "🟡 Ризик зниження прибутку по 2 проектах", "🔴 По проекту Altera є невирішена проблема").
    *   Кожен сигнал: натиснув → чому → дані → прогноз → контекст → куди йти далі.
*   **Блок 3. «Що я можу запитати?»:**
    *   Перелік передвстановлених питань (див. розділ 4).

## 4. ПЕРЕЛІК ПЕРЕДВСТАНОВЛЕНИХ ПИТАНЬ до бота

**ARCHI — OWNER MORNING TEST V1 🔒 LOCKED Q1–Q10**

1.  **🧭 Що в нас зараз відбувається?**
2.  **🔥 Де може запалати?**
3.  **🎯 Чи потрібно мені зараз щось робити?**
4.  **💰 Чи є гроші на зарплату?**
5.  **🌊 Чи є небезпека касового розриву?**
6.  **👥 На який час у команди є робота?**
7.  **📈 Чи виконуємо ми річний план по прибутку?**
8.  **⏰ Чи є пройобані або небезпечні дедлайни?**
9.  **⚠️ За що нам може прилетіти від ключового / якірного замовника?**
10. **🗣️ Що ми / PM пообіцяли замовнику на останній нараді?**

## 5. ПОЗИЦІОНУВАННЯ / АРГУМЕНТИ ПРОДАЖУ

**Тези позиціонування:**

*   **ARCHI — це не просто дашборд з метриками, а "Owner Management Interface" / "Owner Conversation Layer".** Він перетворює хаотичний управлінський запит ("Що у нас там?") на конкретне управлінське питання або усвідомлене рішення не втручатися.
*   **ARCHI створює "Shared Reality" та "Commercial Truth".** Він базується на реальних структурованих даних, а не на припущеннях чи інтуїції.
*   **ARCHI забезпечує "безперервну управлінську траєкторію".** Від загального стану компанії до конкретної управлінської дії.
*   **ARCHI — це "FDO-оркестраційний шар".** Він інтегрує фінансові, операційні та delivery дані для цілісної картини.

**Цільова аудиторія:**

*   Власники архітектурно-будівельних компаній, які хочуть отримати швидкий, достовірний та керований огляд свого бізнесу та проектів.

**Аргументи продажу:**

*   **Економія часу та нервів:** Власник за 30-60 секунд розуміє стан компанії, не витрачаючи години на збір інформації.
*   **Раннє виявлення проблем:** ARCHI показує, "де може запалати", до того, як проблема стане кризою, використовуючи прогнозні FDO-метрики.
*   **Достовірність та довіра:** Кожна відповідь ARCHI має "Evidence Trail" – власник може перевірити, звідки взявся висновок, і провалитися до першоджерела даних.
*   **Конкретні дії:** ARCHI не просто показує проблеми, а допомагає сформулювати, що робити далі, з ким говорити і про що.
*   **Зручність використання:** Інтерфейс у Telegram (MiniApp) та передвстановлені питання роблять систему інтуїтивно зрозумілою, навіть для тих, хто не звик до складних аналітичних інструментів.

**Заперечення клієнтів та як їх закривати:**

*   **"О, ще один дашборд з метриками."**
    *   **Закриття:** "ARCHI — це не дашборд. Це ваш ранковий помічник, який за 30 секунд відповідає на головне питання: 'Чи потрібно мені сьогодні щось робити?' Він не змушує вас інтерпретувати цифри, а дає готовий вердикт і показує, куди дивитися далі."
*   **"У нас вже є Excel / інша система."**
    *   **Закриття:** "ARCHI не замінює ваші існуючі системи. Він інтегрується з ними, збирає дані та перетворює їх на зрозумілі управлінські висновки. Він — ваш персональний 'перекладач' з мови цифр на мову управлінських рішень."
*   **"AI — це не надійно, він може вигадувати."**
    *   **Закриття:** "ARCHI не вигадує. AI використовується для пояснення та навігації, але всі ключові висновки базуються на детермінованих FDO-розрахунках та реальних даних. Ви завжди можете перевірити, звідки ARCHI взяв кожну цифру."
*   **"Це складно налаштовувати."**
    *   **Закриття:** "Для першого клієнта ми адаптуємо ARCHI під ваші існуючі джерела даних та методологію. Наша мета — не змусити вас перебудовувати всю IT-інфраструктуру, а підключитися до вашої реальності та надати цінність максимально швидко."

## 6. ТЕХНІЧНІ/КОДОВІ РІШЕННЯ, що обговорювались

**6.1. NODE-BY-NODE IMPLEMENTATION BACKLOG V1 (загальний опис)**

*   **PHASE 0. НЕ ЛАМАТИ ТЕ, ЩО ВЖЕ ПРАЦЮЄ:**
    *   **EXISTING — залишити:** `Telegram Trigger`, `WR: Ensure Mode Table`, `WR: Read Mode`, `WR: Determine Route`, `Owner View chain` (`MiniApp Page Webhook`, `Build MiniApp HTML`, `Respond MiniApp HTML`, `MiniApp Data Webhook`, `Validate InitData`, `Is Valid InitData`, `Read DEMO Flat`, `Read Weekly Log`, `Build MiniApp Data`, `Respond MiniApp Data`).
*   **PHASE 1. P0 — OWNER MORNING SUMMARY:**
    *   **NODE:** `Build MiniApp Data`
    *   **STATUS:** `MODIFY` — головний P0 node.
    *   **Що додати:** У фінальний JSON payload блок `owner_morning` з полями `status`, `headline`, `action_required`, `action_text`, `top_signals`.
    *   **НОВА логіка:** Детерміновано збирати FDO signals, визначати `severity`, сортувати, вибирати Top 3–5, визначати загальний `Owner Status` (`RED`, `YELLOW`, `GREEN`, `UNKNOWN`).
*   **PHASE 2. P0 — SIGNAL OBJECT:**
    *   **ADD:** `Build Owner Signals` (окремий Code node).
    *   **Input:** `DEMO Flat`, `Weekly Log`, фінансові дані, `Meeting data`.
    *   **Output:** Єдиний формат сигналу (`signal_id`, `severity`, `type`, `entity_type`, `entity_id`, `title`, `why`, `impact`, `evidence`, `source`, `freshness`).
*   **PHASE 3. P0 — DATA FRESHNESS:**
    *   **ADD:** `Owner: Build Freshness` (окремий Code node).
    *   **Output:** Об'єкт з `source`, `last_updated_at`, `data_period`, `status` (`fresh|outdated|missing`).
    *   **Джерела V1:** `DEMO_FLAT`, `WEEKLY_LOG`, `TIME_LOG`, `MONEY_LOG`, `MEETING_LOG`.
    *   **Важливо:** `Telegram InitData freshness` ≠ `Data Freshness`.
*   **PHASE 4. P0 — Q1 («Що в нас зараз відбувається?»):**
    *   **IMPLEMENTATION:** `Build Owner Signals` → `Owner: Build Morning Summary` → `Build MiniApp Data`.
    *   **ADD NODE:** `Owner: Build Morning Summary`.
    *   **Input:** Всі сигнали.
    *   **Output:** Об'єкт з `status`, `headline`, `action_required`, `top_signals`.
*   **PHASE 5. P0 — Q2 («Де може запалати?»):**
    *   **ADD:** `Owner: Rank Risks`.
    *   **Input:** Існуючі FDO signals.
    *   **Output:** Об'єкт з `top_risks` (відсортовані за `severity`, `potential impact`, `time horizon`).
*   **PHASE 6. P0 — PRESET Q1–Q10:**
    *   **MODIFY:** `Build MiniApp HTML`.
    *   Додати окремий блок `Owner Questions` на першому екрані з кнопками для 10 LOCKED питань.
*   **PHASE 7. P0 — OWNER QUESTION API:**
    *   **ADD:** `Owner Question Webhook`.
    *   **Input:** `question_id`, `entity_context`, `follow_up`.
    *   **ADD:** `Owner: Question Router` (розгалуження на відповідні Engine для кожного Q).
*   **PHASE 8. Q4 — WORK HORIZON («На який час у команди є робота?»):**
    *   **ADD:** `Owner: Work Horizon Engine`.
    *   **Input:** `Залишок_прогноз`, `ETC`, структура команди / доступна виробнича потужність.
    *   **Output:** `answer`, `work_horizon`, `basis`, `evidence`.
*   **PHASE 9. Q3 + Q5 — FINANCIAL ENGINE («Чи є гроші на зарплату?», «Чи є небезпека касового розриву?»):**
    *   **ADD:** `Finance: Read Money Data` (джерела: `oneB Finance API`, `Money_Log`, `Client XLSX/CSV import`, `Bank export`).
    *   **ADD:** `Finance: Normalize Cash Data` (канонічні поля: `date`, `amount`, `direction`, `category`, `project_id`, `client`, `expected_date`, `actual_date`, `confidence`, `source`).
    *   **ADD:** `Finance: Cash Forecast` (output: `current_cash`, `forecast`, `first_negative_date`, `maximum_gap`, `drivers`).
    *   **ADD:** `Owner: Salary Safety Engine` (output: `YES/NO/UNKNOWN` з деталями).
    *   **ADD:** `Owner: Cash Gap Engine` (output: `Є/Немає/Недостатньо даних` з деталями).
*   **PHASE 10. Q6 — ANNUAL PROFIT («Чи виконуємо ми річний план по прибутку?»):**
    *   **ADD:** `Owner: Annual Profit Engine` (output: `plan`, `actual`, `forecast`, `variance`, `drivers`).
*   **PHASE 11. Q7 — DEADLINE ENGINE («Чи є пройобані / під загрозою дедлайни?»):**
    *   **ADD:** `Owner: Deadline Risk Engine` (output: `project`, `deadline`, `status`, `forecast`, `why`, `evidence`).
*   **PHASE 12. Q8 — ANCHOR CLIENT ENGINE («За що мені може прилетіти від якірного замовника?»):**
    *   **CLIENT CONFIG REQUIRED:** Поля `client_id`, `client_name`, `portfolio_share`, `anchor_flag`.
    *   **ADD:** `Owner: Client Risk Engine` (output: `CLIENT`, `DEPENDENCY`, `CURRENT RISKS`, `OPEN COMMITMENTS`, `LATEST CLIENT CONTEXT`).
*   **PHASE 13. Q9 — MEETING COMMITMENTS («Що PM пообіцяв замовнику на останньому мітінгу?»):**
    *   **ADD:** `Owner: Read Latest Relevant Meeting` (input: `project_id` OR `client_id`; output: `latest meeting`, `decisions`, `commitments`, `responsible`, `deadline`).
*   **PHASE 14. Q10 — EVENT EXPLANATION («Чому не відбулася важлива домовленість / подія?»):**
    *   **ADD:** `Owner: Explain Event` (input: `event`, `project/client context`; output: `Що сталося`, `Чому`, `На підставі яких даних`, `Що власнику перевірити далі`).
*   **PHASE 15. CHAT ARCHI — ПРАВИЛЬНЕ ПІДКЛЮЧЕННЯ:**
    *   **MODIFY:** Існуючий `Chat ARCHI` workflow (`Read DEMO Flat (Chat)` → `Build Request Body` → `Call Anthropic` → `Send Reply`).
    *   **Головна правка:** Chat має отримувати той самий `Signal Model`, `Financial Calculations`, `Meeting Evidence`, `Freshness Model`, а не бути окремою "інтелектуальною реальністю".

**6.2. Код для вставки в Build MiniApp Data (перед `const data = {`)**

```javascript
// ============================================================
// ARCHI — OWNER MORNING ENGINE V1
// Deterministic. No AI. Built only from existing FDO signals.
// ============================================================
function severityRank(severity) {
  if (severity === 'RED') return 3;
  if (severity === 'YELLOW') return 2;
  if (severity === 'GREEN') return 1;
  return 0;
}

function normalizeProjectId(p) {
  if (!p) return null;
  return String(
    p.id ||
    p.projectId ||
    p.ProjectID ||
    p.project_id ||
    ''
  ).trim() || null;
}

function projectName(p) {
  if (!p) return '';
  return String(
    p.name ||
    p.projectName ||
    p['Назва проекту'] ||
    p['Назва'] ||
    normalizeProjectId(p) ||
    ''
  ).trim();
}

function getProjectsFromGroup(groupContainer, groupId) {
  if (!groupContainer) return [];
  const arr = groupContainer[groupId];
  if (!Array.isArray(arr)) return [];
  return arr;
}

function uniqueProjectIds(list) {
  const seen = new Set();
  return list.filter(function (id) {
    if (!id || seen.has(id)) return false;
    seen.add(id);
    return true;
  });
}

function findProjectById(id) {
  return projects.find(function (p) {
    return normalizeProjectId(p) === id;
  }) || null;
}

function buildSignal(options) {
  return {
    id: options.id,
    severity: options.severity,
    title: options.title,
    reason: options.reason,
    metric: options.metric || null,
    currentValue: options.currentValue || null,
    expectedValue: options.expectedValue || null,
    sourceView: options.sourceView,
    projectIds: uniqueProjectIds(options.projectIds || [])
  };
}

const ownerSignals = [];


// ============================================================
// 1. RENTABILITY
// Uses existing rentGroupProjects
// ============================================================
const rentCriticalProjects =
  getProjectsFromGroup(rentGroupProjects, 'critical');
const rentAttentionProjects =
  getProjectsFromGroup(rentGroupProjects, 'attention');

if (rentCriticalProjects.length > 0) {
  ownerSignals.push(
    buildSignal({
      id: 'RENT_CRITICAL',
      severity: 'RED',
      title: 'Рентабельність',
      reason:
        'Є проєкти з критичним відхиленням прогнозної рентабельності.',
      metric: 'rentability',
      sourceView: 'rent',
      projectIds: rentCriticalProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}
if (
  rentCriticalProjects.length === 0 &&
  rentAttentionProjects.length > 0
) {
  ownerSignals.push(
    buildSignal({
      id: 'RENT_ATTENTION',
      severity: 'YELLOW',
      title: 'Рентабельність',
      reason:
        'Є проєкти, де прогнозна рентабельність потребує уваги.',
      metric: 'rentability',
      sourceView: 'rent',
      projectIds: rentAttentionProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}


// ============================================================
// 2. VOLUME
// Uses existing volumeGroups
// ============================================================
const volumeCriticalProjects =
  getProjectsFromGroup(volumeGroups, 'critical');
const volumeAttentionProjects =
  getProjectsFromGroup(volumeGroups, 'attention');

if (volumeCriticalProjects.length > 0) {
  ownerSignals.push(
    buildSignal({
      id: 'VOLUME_CRITICAL',
      severity: 'RED',
      title: 'Обсяг робіт',
      reason:
        'Є критичні розриви між необхідним та фактичним обсягом робіт.',
      metric: 'volume',
      sourceView: 'volume',
      projectIds: volumeCriticalProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}
if (
  volumeCriticalProjects.length === 0 &&
  volumeAttentionProjects.length > 0
) {
  ownerSignals.push(
    buildSignal({
      id: 'VOLUME_ATTENTION',
      severity: 'YELLOW',
      title: 'Обсяг робіт',
      reason:
        'Є проєкти з розривом обсягу робіт, які потребують уваги.',
      metric: 'volume',
      sourceView: 'volume',
      projectIds: volumeAttentionProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}


// ============================================================
// 3. ETC / REAL REMAINING WORKLOAD
// Uses existing ETC methodology.
// No separate invented "workload" metric.
// ============================================================
const etcCriticalProjects =
  getProjectsFromGroup(etcGroups, 'critical');
const etcAttentionProjects =
  getProjectsFromGroup(etcGroups, 'attention');

if (etcCriticalProjects.length > 0) {
  ownerSignals.push(
    buildSignal({
      id: 'ETC_CRITICAL',
      severity: 'RED',
      title: 'Залишок робіт',
      reason:
        'Є проєкти з критичним перевищенням прогнозного часу до завершення.',
      metric: 'ETC',
      sourceView: 'etc',
      projectIds: etcCriticalProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}
if (
  etcCriticalProjects.length === 0 &&
  etcAttentionProjects.length > 0
) {
  ownerSignals.push(
    buildSignal({
      id: 'ETC_ATTENTION',
      severity: 'YELLOW',
      title: 'Залишок робіт',
      reason:
        'Є проєкти, де прогноз залишку робіт потребує уваги.',
      metric: 'ETC',
      sourceView: 'etc',
      projectIds: etcAttentionProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}


// ============================================================
// 4. EVM
// Uses existing evmGroups
// ============================================================
const evmCriticalProjects =
  getProjectsFromGroup(evmGroups, 'critical');
const evmAttentionProjects =
  getProjectsFromGroup(evmGroups, 'attention');

if (evmCriticalProjects.length > 0) {
  ownerSignals.push(
    buildSignal({
      id: 'EVM_CRITICAL',
      severity: 'RED',
      title: 'Виконання проєктів',
      reason:
        'Є проєкти з критичним EVM-сигналом.',
      metric: 'EVM',
      sourceView: 'evm',
      projectIds: evmCriticalProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}
if (
  evmCriticalProjects.length === 0 &&
  evmAttentionProjects.length > 0
) {
  ownerSignals.push(
    buildSignal({
      id: 'EVM_ATTENTION',
      severity: 'YELLOW',
      title: 'Виконання проєктів',
      reason:
        'Є EVM-сигнали, які потребують уваги.',
      metric: 'EVM',
      sourceView: 'evm',
      projectIds: evmAttentionProjects
        .map(normalizeProjectId)
        .filter(Boolean)
    })
  );
}


// ============================================================
// SORT SIGNALS
// ============================================================
ownerSignals.sort(function (a, b) {
  return severityRank(b.severity) - severityRank(a.severity);
});


// ============================================================
// PROJECT ATTENTION MAP
// One project may have several independent FDO signals.
// ============================================================
const attentionMap = {};
function addProjectAttention(projectId, signal) {
  if (!projectId) return;
  if (!attentionMap[projectId]) {
    const project = findProjectById(projectId);
    attentionMap[projectId] = {
      id: projectId,
      name: project ? projectName(project) : projectId,
      score: 0,
      severity: 'GREEN',
      signals: []
    };
  }
  const entry = attentionMap[projectId];
  entry.signals.push({
    signalId: signal.id,
    title: signal.title,
    reason: signal.reason,
    severity: signal.severity,
    sourceView: signal.sourceView
  });
  entry.score += severityRank(signal.severity);
  if (
    severityRank(signal.severity) >
    severityRank(entry.severity)
  ) {
    entry.severity = signal.severity;
  }
}
ownerSignals.forEach(function (signal) {
  signal.projectIds.forEach(function (projectId) {
    addProjectAttention(projectId, signal);
  });
});
const projectsNeedAttention = Object.values(attentionMap)
  .sort(function (a, b) {
    const severityDiff =
      severityRank(b.severity) -
      severityRank(a.severity);
    if (severityDiff !== 0) return severityDiff;
    return b.score - a.score;
  });


// ============================================================
// OVERALL OWNER STATUS
// ============================================================
const redSignals = ownerSignals.filter(function (s) {
  return s.severity === 'RED';
});
const yellowSignals = ownerSignals.filter(function (s) {
  return s.severity === 'YELLOW';
});

let overallStatus = 'GREEN';
let headline = 'Ситуація контрольована';
let summary =
  'За наявними даними ARCHI не бачить критичних сигналів, які потребують вашого втручання.';
let actionRequired = false;

if (redSignals.length > 0) {
  overallStatus = 'RED';
  headline =
    'Є питання, які потребують вашої уваги';
  summary =
    'ARCHI бачить ' +
    redSignals.length +
    ' критичних сигналів у портфелі. Почніть з проєктів із найвищим рівнем ризику.';
  actionRequired = true;
} else if (yellowSignals.length > 0) {
  overallStatus = 'YELLOW';
  headline =
    'Є точки, за якими варто стежити';
  summary =
    'Критичних сигналів немає, але ARCHI бачить ' +
    yellowSignals.length +
    ' зон(и), які потребують уваги та контролю.';
}


// ============================================================
// DATA FRESHNESS
//
// IMPORTANT:
// Current DEMO Flat does not provide a confirmed canonical
// data-as-of field inside the retrieved Build MiniApp Data code.
//
// Therefore:
// generatedAt = known
// dataAsOf = unknown
//
// Do NOT fake today's date as data freshness.
// ============================================================
const generatedAt = new Date().toISOString();
const freshness = {
  generatedAt: generatedAt,
  dataAsOf: null,
  status: 'UNKNOWN',
  message:
    'Дата фактичної актуальності вихідних даних у DEMO не підтверджена.'
};


// ============================================================
// FINAL OWNER MORNING OBJECT
// ============================================================
const ownerMorning = {
  overallStatus: overallStatus,
  headline: headline,
  summary: summary,
  actionRequired: actionRequired,
  attentionCount: projectsNeedAttention.length,
  criticalSignalCount: redSignals.length,
  warningSignalCount: yellowSignals.length,
  topSignals: ownerSignals.slice(0, 5),
  projectsNeedAttention:
    projectsNeedAttention.slice(0, 10),
  freshness: freshness
};
```

**6.3. Заміна фінального `const data = { ... }` блоку в Build MiniApp Data:**

```javascript
const data = {
  generatedAt: generatedAt,
  asOf:
    new Date().toLocaleDateString('uk-UA') +
    ' (DEMO Flat, ' +
    projects.length +
    ' проектів)',
  ownerMorning: ownerMorning,
  projects: projects,
  totalContract: totalContract,
  totalContractFmt: fmtUAH(totalContract),
  views: views
};
return [{ json: data }];
```

**6.4. Зміни в Build MiniApp HTML:**

*   **Ініціалізація стану:** Додати `state.view = 'morning'` при старті MiniApp.
*   **Нова функція `renderMorning()`:** Вставити HTML-структуру для "Owner Morning Summary" (заголовки, статус, сигнали, проекти, freshness).
*   **Зміна стартового маршруту:** Замість `renderDashboard()` викликати `renderMorning()`.
*   **Кнопка повернення:** Додати кнопку `<button onclick="showMorning()">☀️ Owner Morning</button>` для повернення на екран "Owner Morning".

## 7. ПРОТИРІЧЧЯ ТА ПРОГАЛИНИ в баченні GPT

GPT виявив і сам виправив кілька своїх помилок та прогалин у баченні:

*   **Початкова помилка фокусу:** Спочатку GPT оцінював DEMO як "концепт Owner View", а не як конкретний продукт, що має пройти "Owner Morning Test". Також оцінював методологію, а не реалізований DEMO-код.
*   **Спрощена атака на FDO:** Зауваження про "ризик №4" ("формально все добре, а реально проект летить у прірву") було слабким, оскільки система ARCHI вже має логіку раннього виявлення відхилень через FDO-метрики та регулярний управлінський цикл.
*   **"Вітрина метрик":** GPT визначив, що поточний "Owner View" занадто схожий на "вітрину метрик", а не на цілісну управлінську навігацію.
*   **Недостатня прозорість фінансового контуру:** Спочатку GPT помилково вважав, що в DEMO відсутній company-level financial forecast, тоді як методологія FDO передбачає інтеграцію з oneBfinance або адаптованими фінансовими моделями клієнта. Пізніше він скоригував це, визнавши наявність Money_Log та потенціал для фінансових розрахунків.
*   **Неправильна інтерпретація ETC/Workload:** GPT спочатку припустив, що для "workload runway" потрібен окремий HR-модуль, тоді як у методології FDO "Залишок_прогноз" (ETC) вже є коректною метрикою реального майбутнього завантаження команди.
*   **Ризик "Garbage In / Green Out":** GPT виявив, що якщо Money Lock буде приймати "будь-який Excel" без належної валідації та нормалізації, ARCHI не зможе чесно давати впевнені фінансові відповіді.
*   **"Класична помилка консультанта":** GPT сам визнав, що замість закриття scope, він продовжував його аналізувати та генерувати нові ідеї, що затягувало процес.
*   **Змішування "аудиту продукту" з "генерацією нових думок":** Аудитор повинен завершувати роботу вердиктом, а не новими абзацами чи ідеями.
*   **Недостатнє розуміння архітектури ARCHI/FDO:** GPT визнав, що спочатку штучно розрізав питання на ізольовані функції, тоді як у методології ARCHI/FDO вони пов'язані через єдину структуру проектної/контрактної реальності (кошторис, графіки платежів/документації, ETC).

## 8. ГЛОСАРІЙ нових термінів GPT

*   **Owner Morning Test:** Сценарій тестування продукту, що імітує ранковий сеанс роботи власника компанії з ARCHI Bot для швидкого отримання управлінської картини та прийняття рішень.
*   **Owner Morning Home:** Перший екран MiniApp, який власник бачить вранці, що містить агрегований статус компанії, ключові сигнали та передвстановлені питання.
*   **Owner Morning Summary:** Детермінований блок на першому екрані, що надає загальний вердикт про стан компанії (🟢/🟡/🔴), заголовок та короткий опис.
*   **Owner Verdict:** Пряма, однозначна відповідь ARCHI на питання власника про загальний стан компанії або конкретну проблему.
*   **Owner Risk Queue:** Пріоритезований список ризиків, зібраний з усіх FDO-сигналів, що показує власнику найбільш важливі точки уваги.
*   **Owner Attention Layer:** Надбудова над існуючими FDO-сигналами, яка збирає їх і правильно показує власнику, що потребує його уваги.
*   **Owner Question Router:** Вузол у n8n workflow, який приймає запит від передвстановленого питання власника і направляє його до відповідного "Engine" для формування відповіді.
*   **Owner Action Routing:** Логіка, яка після виявлення сигналу допомагає власнику зрозуміти, чи потрібна його дія, і якщо так, то кому дзвонити і про що питати.
*   **Owner Management Interface / Owner Conversation Layer:** Концепція ARCHI як інструменту, що дозволяє власнику вести діалог з компанією через дані, а не просто переглядати метрики.
*   **Owner Morning Test Specification / Build Spec / Development Package:** Конкретні артефакти, що фіксують вимоги, scope та план реалізації ARCHI DEMO V1.
*   **Money Lock:** Процес імпорту, нормалізації та валідації фінансових даних з різних джерел (Excel, банківські виписки, API) у канонічну фінансову модель ARCHI.
*   **Garbage In / Green Out:** Ризик, коли система приймає неякісні або неповні вхідні дані, але видає впевнені (і потенційно хибні) позитивні висновки.
*   **Frankenstein:** Метафора для опису системи, що складається з розрізнених, неінтегрованих компонентів, які не працюють як єдине ціле.
*   **Evidence Trail:** Шлях від висновку ARCHI до конкретних даних, джерел та дати актуальності, що забезпечує довіру до системи.
*   **FDO (Financial-Delivery-Operations):** (Існуючий термін, але GPT підкреслює його центральну роль) Методологія, що інтегрує фінансові, delivery та операційні дані для комплексного управління проектами.