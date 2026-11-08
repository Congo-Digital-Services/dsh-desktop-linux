// Desktop notifications for DeepSeek Harness (Linux, via notify-send):
// task finished, failed or blocked, and approval requests.
// Top-level sessions only: subagent turns are ignored.
// In DSH Desktop, clicking a notification opens its session (through the app's private local socket).
import { execFile } from 'node:child_process'
import { existsSync } from 'node:fs'
import { connect } from 'node:net'
import { homedir } from 'node:os'
import { join } from 'node:path'

export const name = 'dsh-notify'

const FR = /^fr/i.test(process.env.LC_ALL || process.env.LC_MESSAGES || process.env.LANG || '')
const T = FR
  ? { done: 'Tâche terminée', error: 'Erreur', blocked: 'Tâche bloquée', stopped: 'Tâche arrêtée', approval: 'Validation requise', session: 'Session dsh', failed: 'échec', open: 'Ouvrir' }
  : { done: 'Task finished', error: 'Error', blocked: 'Task blocked', stopped: 'Task stopped', approval: 'Approval required', session: 'dsh session', failed: 'failed', open: 'Open' }

const ICON = [join(homedir(), '.local/share/icons/hicolor/512x512/apps/dsh-desktop.png')].find(existsSync) ?? 'dialog-information'
const titles = new Map()

const RUNTIME = process.env.XDG_RUNTIME_DIR
const SOCKET = RUNTIME ? join(RUNTIME, 'dsh-desktop-linux', 'open-session.sock') : undefined

function openSession(sessionId) {
  if (SOCKET === undefined || !existsSync(SOCKET)) return
  const socket = connect(SOCKET, () => { socket.end(`${sessionId}\n`) })
  socket.setTimeout(2000, () => { socket.destroy() })
  socket.on('error', () => {})
}

function notify(summary, body, urgency = 'normal', sessionId) {
  const args = ['-a', 'DSH', '-i', ICON, '-u', urgency]
  // Only offer the click when DSH Desktop is running and listening; the web UI and the CLI get plain notifications.
  const clickable = sessionId !== undefined && SOCKET !== undefined && existsSync(SOCKET)
  if (clickable) args.push('-A', 'default=' + T.open, '-A', 'open=' + T.open)
  execFile('notify-send', [...args, summary, body], (error, stdout) => {
    const action = String(stdout ?? '').trim()
    if (clickable && !error && (action === 'default' || action === 'open')) openSession(sessionId)
  })
}

export function apply(ctx) {
  ctx.on('session/event', (session, event) => {
    const header = session?.header
    if (header?.origin === 'subagent' || (header?.delegationDepth ?? 0) > 0) return
    const id = session.id
    if (event.type === 'session/title') { titles.set(id, event.data.title); return }
    const title = titles.get(id) ?? T.session
    if (event.type === 'approval/asked') {
      notify(T.approval, `${title} — ${event.data.toolName}${event.data.reason ? `: ${event.data.reason}` : ''}`, 'critical', id)
    } else if (event.type === 'turn/end') {
      const kind = event.data.reason?.kind
      if (kind === 'completed') notify(T.done, title, 'normal', id)
      else if (kind === 'error') notify(T.error, `${title} — ${event.data.reason.error?.message ?? T.failed}`, 'critical', id)
      else if (kind === 'blocked') notify(T.blocked, title, 'critical', id)
      else if (kind && kind !== 'aborted') notify(T.stopped, `${title} (${kind})`, 'normal', id)
    }
  })
}
