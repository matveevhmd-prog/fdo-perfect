import { workflow, node, trigger, newCredential, expr } from '@n8n/workflow-sdk';

// ARCHI: Error Alert (JZ5htUtbMaWTagoC), DR-14, 05.11.2026. Error Workflow для core і Morning Brief.
// Після створення credential Alert Operator вручну виставлено на «Telegram account 4» (jDGC5deJSU6Bjk2J): автопідстановка бере інший бот.
const errorTrigger = trigger({
  type: 'n8n-nodes-base.errorTrigger',
  version: 1,
  config: { name: 'Error Trigger', output: [{ workflow: { id: 'CKwCsGIwyw9feCY5', name: 'DEMO Archi Agent' }, execution: { id: '1', mode: 'webhook', lastNodeExecuted: 'Call Anthropic', error: { message: 'example' } } }] }
});

const alertOperator = node({
  type: 'n8n-nodes-base.telegram',
  version: 1.2,
  config: {
    name: 'Alert Operator',
    parameters: {
      resource: 'message',
      operation: 'sendMessage',
      chatId: '304884647',
      text: expr('{{ "🔴 ARCHI: збій виконання\\n\\n• Workflow: " + ($json.workflow ? $json.workflow.name : "—") + "\\n• Вузол: " + ($json.execution && $json.execution.lastNodeExecuted ? $json.execution.lastNodeExecuted : "—") + "\\n• Помилка: " + (($json.execution && $json.execution.error && $json.execution.error.message) ? String($json.execution.error.message).slice(0, 300) : "—") + "\\n• Виконання: " + ($json.execution ? $json.execution.id : "—") }}'),
      additionalFields: { appendAttribution: false }
    },
    credentials: { telegramApi: newCredential('Telegram account 4') },
    output: [{ ok: true }]
  }
});

export default workflow('archi-error-alert', 'ARCHI: Error Alert')
  .add(errorTrigger)
  .to(alertOperator);
