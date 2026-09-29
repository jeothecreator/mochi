// Mochi for VS Code — tells the Mochi desktop pet (macOS app) about errors and task results.
// It only sends small mochi:// links to the app on this Mac (error *counts* and exit codes — never code or file names).
const vscode = require('vscode');
const { execFile } = require('child_process');

let lastErrors = null;      // null until we've seen a baseline, so opening a messy project doesn't trigger anything
let lastSaveAt = 0;
let debounce = null;

function ping(path) {
  if (process.platform !== 'darwin') return;
  // -g keeps Mochi in the background so VS Code keeps focus.
  execFile('/usr/bin/open', ['-g', `mochi://${path}`], () => {});
}

function config() { return vscode.workspace.getConfiguration('mochi'); }

function countErrors() {
  const isError = d => d.severity === vscode.DiagnosticSeverity.Error;
  if (config().get('errorScope') === 'activeFile') {
    const doc = vscode.window.activeTextEditor && vscode.window.activeTextEditor.document;
    return doc ? vscode.languages.getDiagnostics(doc.uri).filter(isError).length : 0;
  }
  return vscode.languages.getDiagnostics().reduce((n, [, diags]) => n + diags.filter(isError).length, 0);
}

function check() {
  if (!config().get('reactToErrors')) return;
  const n = countErrors();
  if (lastErrors === null) { lastErrors = n; return; }
  const recentlySaved = Date.now() - lastSaveAt < 15000;
  if (n > 0 && lastErrors === 0 && recentlySaved) {
    ping(`editor?errors=${n}`);            // new errors right after a save → "uh oh"
  } else if (n === 0 && lastErrors > 0) {
    ping('editor?errors=0');              // everything fixed → celebrate
  }
  lastErrors = n;
}

function schedule() {
  clearTimeout(debounce);
  debounce = setTimeout(check, 1500);     // let the language server settle (no reacting mid-keystroke)
}

function looksLikeBuildOrTest(task) {
  const g = task.group;
  if (g === vscode.TaskGroup.Build || g === vscode.TaskGroup.Test) return true;
  return /build|test|compile|make|lint/i.test(task.name || '');
}

function activate(context) {
  context.subscriptions.push(
    vscode.languages.onDidChangeDiagnostics(schedule),
    vscode.workspace.onDidSaveTextDocument(() => { lastSaveAt = Date.now(); schedule(); }),
    vscode.window.onDidChangeActiveTextEditor(() => { if (config().get('errorScope') === 'activeFile') { lastErrors = null; schedule(); } }),
    vscode.tasks.onDidEndTaskProcess(e => {
      if (!config().get('reactToTasks') || e.exitCode === undefined) return;
      const task = e.execution.task;
      if (!looksLikeBuildOrTest(task)) return;
      const kind = task.group === vscode.TaskGroup.Test || /test/i.test(task.name || '') ? 'test' : 'build';
      ping(`${kind}?status=${e.exitCode}`);
    }),
    vscode.commands.registerCommand('mochi.cheer', () => ping('build?status=0')),
    vscode.commands.registerCommand('mochi.oops', () => ping('build?status=1'))
  );
  schedule();
}

function deactivate() { clearTimeout(debounce); }

module.exports = { activate, deactivate };
