// Desktop notifications for DeepSeek Harness (Linux, via notify-send):
// task finished, failed or blocked, and approval requests.
// Top-level sessions only: subagent turns are ignored.
import { execFile } from 'node:child_process'
import { existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

export const name = 'dsh-notify'

const FR = /^fr/i.test(process.env.LC_ALL || process.env.LC_MESSAGES || process.env.LANG || '')
const T = FR
  ? { done: 'Tâche terminée', error: 'Erreur', blocked: 'Tâche bloquée', stopped: 'Tâche arrêtée', approval: 'Validation requise', session: 'Session dsh', failed: 'échec' }
  : { done: 'Task finished', error: 'Error', blocked: 'Task blocked', stopped: 'Task stopped', approval: 'Approval required', session: 'dsh session', failed: 'failed' }

const ICON = [join(homedir(), '.local/share/icons/hicolor/512x512/apps/dsh-desktop.png')].find(existsSync) ?? 'dialog-information'
const titles = new Map()

function notify(summary, body, urgency = 'normal') {
  execFile('notify-send', ['-a', 'DSH', '-i', ICON, '-u', urgency, summary, body], () => {})
}

export function apply(ctx) {
  ctx.on('session/event', (session, event) => {
    const header = session?.header
    if (header?.origin === 'subagent' || (header?.delegationDepth ?? 0) > 0) return
    const id = session.id
    if (event.type === 'session/title') { titles.set(id, event.data.title); return }
    const title = titles.get(id) ?? T.session
    if (event.type === 'approval/asked') {
      notify(T.approval, `${title} — ${event.data.toolName}${event.data.reason ? `: ${event.data.reason}` : ''}`, 'critical')
    } else if (event.type === 'turn/end') {
      const kind = event.data.reason?.kind
      if (kind === 'completed') notify(T.done, title)
      else if (kind === 'error') notify(T.error, `${title} — ${event.data.reason.error?.message ?? T.failed}`, 'critical')
      else if (kind === 'blocked') notify(T.blocked, title, 'critical')
      else if (kind && kind !== 'aborted') notify(T.stopped, `${title} (${kind})`)
    }
  })
}
