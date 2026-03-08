import * as vscode from 'vscode';
import * as path from 'path';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;
let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext) {
    console.log('RSR-Certified extension is activating...');

    // Create status bar item
    statusBarItem = vscode.window.createStatusBarItem(
        vscode.StatusBarAlignment.Right,
        100
    );
    statusBarItem.command = 'rsr.showReport';
    context.subscriptions.push(statusBarItem);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('rsr.checkCompliance', checkCompliance),
        vscode.commands.registerCommand('rsr.initConfig', initConfig),
        vscode.commands.registerCommand('rsr.showReport', showReport),
        vscode.commands.registerCommand('rsr.generateBadge', generateBadge)
    );

    // Start the language server
    startLanguageServer(context);

    // Update status bar
    updateStatusBar('silver', 75);

    // Check on save if enabled
    const config = vscode.workspace.getConfiguration('rsr');
    if (config.get('checkOnSave')) {
        context.subscriptions.push(
            vscode.workspace.onDidSaveTextDocument(onDocumentSave)
        );
    }
}

function startLanguageServer(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('rsr');
    let serverPath = config.get<string>('serverPath');

    if (!serverPath) {
        // Use bundled server
        serverPath = context.asAbsolutePath(
            path.join('server', process.platform === 'win32' ? 'rsr-lsp.exe' : 'rsr-lsp')
        );
    }

    // Check if server exists
    const fs = require('fs');
    if (!fs.existsSync(serverPath)) {
        vscode.window.showWarningMessage(
            'RSR LSP server not found. Some features may be limited. Install with: cargo install rsr-lsp'
        );
        return;
    }

    const serverOptions: ServerOptions = {
        run: {
            command: serverPath,
            transport: TransportKind.stdio
        },
        debug: {
            command: serverPath,
            transport: TransportKind.stdio
        }
    };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', pattern: '**/.rsr.toml' },
            { scheme: 'file', pattern: '**/README.md' },
            { scheme: 'file', pattern: '**/LICENSE*' },
            { scheme: 'file', pattern: '**/CONTRIBUTING.md' },
            { scheme: 'file', pattern: '**/SECURITY.md' },
            { scheme: 'file', pattern: '**/CHANGELOG.md' }
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/.rsr.toml')
        }
    };

    client = new LanguageClient(
        'rsrCertified',
        'RSR-Certified Language Server',
        serverOptions,
        clientOptions
    );

    client.start();
}

async function checkCompliance() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: 'RSR: Checking compliance...',
            cancellable: false
        },
        async () => {
            if (client) {
                try {
                    const result = await client.sendRequest('rsr/getCompliance');
                    handleComplianceResult(result);
                } catch (error) {
                    vscode.window.showErrorMessage(`RSR check failed: ${error}`);
                }
            } else {
                // Fallback: Run CLI
                runCliCheck(workspaceFolder.uri.fsPath);
            }
        }
    );
}

function runCliCheck(workspacePath: string) {
    const terminal = vscode.window.createTerminal('RSR Check');
    terminal.sendText(`rsr check "${workspacePath}"`);
    terminal.show();
}

function handleComplianceResult(result: any) {
    if (!result) return;

    const tier = result.tier || 'none';
    const score = result.score || 0;

    updateStatusBar(tier, Math.round(score * 100));

    // Show notification
    const tierEmoji = getTierEmoji(tier);
    vscode.window.showInformationMessage(
        `RSR Compliance: ${tierEmoji} ${tier.toUpperCase()} (${Math.round(score * 100)}%)`
    );

    // Update diagnostics
    if (result.checks) {
        updateDiagnostics(result.checks);
    }
}

function updateStatusBar(tier: string, score: number) {
    const config = vscode.workspace.getConfiguration('rsr');
    if (!config.get('showStatusBarItem')) {
        statusBarItem.hide();
        return;
    }

    const emoji = getTierEmoji(tier);
    statusBarItem.text = `${emoji} RSR: ${tier.toUpperCase()} ${score}%`;
    statusBarItem.tooltip = `RSR Compliance: ${tier} tier (${score}% score)\nClick to view report`;

    // Color based on tier
    switch (tier.toLowerCase()) {
        case 'rhodium':
            statusBarItem.backgroundColor = undefined;
            break;
        case 'gold':
            statusBarItem.backgroundColor = undefined;
            break;
        case 'silver':
            statusBarItem.backgroundColor = undefined;
            break;
        case 'bronze':
            statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
            break;
        default:
            statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
    }

    statusBarItem.show();
}

function getTierEmoji(tier: string): string {
    switch (tier.toLowerCase()) {
        case 'rhodium': return '◆';
        case 'gold': return '★';
        case 'silver': return '☆';
        case 'bronze': return '●';
        default: return '○';
    }
}

const diagnosticCollection = vscode.languages.createDiagnosticCollection('rsr');

function updateDiagnostics(checks: any[]) {
    diagnosticCollection.clear();

    const failedChecks = checks.filter((c: any) => !c.passed);
    if (failedChecks.length === 0) return;

    // Group by file (if we have file info)
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) return;

    // Create a single diagnostic for the workspace
    const rootUri = workspaceFolder.uri;
    const diagnostics: vscode.Diagnostic[] = failedChecks.map((check: any) => {
        const severity = getSeverity(check.tier);
        return new vscode.Diagnostic(
            new vscode.Range(0, 0, 0, 0),
            `[${check.tier.toUpperCase()}] ${check.name}: ${check.message}`,
            severity
        );
    });

    // Add to a virtual "compliance" file or README
    const readmePath = vscode.Uri.joinPath(rootUri, 'README.md');
    diagnosticCollection.set(readmePath, diagnostics);
}

function getSeverity(tier: string): vscode.DiagnosticSeverity {
    switch (tier.toLowerCase()) {
        case 'bronze':
            return vscode.DiagnosticSeverity.Error;
        case 'silver':
            return vscode.DiagnosticSeverity.Warning;
        case 'gold':
        case 'rhodium':
            return vscode.DiagnosticSeverity.Information;
        default:
            return vscode.DiagnosticSeverity.Hint;
    }
}

async function initConfig() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    const config = vscode.workspace.getConfiguration('rsr');
    const targetTier = config.get<string>('targetTier') || 'silver';

    const configContent = `# RSR (Rhodium Standard Repository) Configuration
# https://github.com/Hyperpolymath/git-rsr-certified

[compliance]
target_tier = "${targetTier}"
strict_mode = false

[checks]
# License configuration
license.required = true
license.allowed = ["MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause"]

# README requirements
readme.min_length = 100

[ignore]
# Paths to exclude from compliance scanning
paths = [
    "vendor/",
    "third_party/",
    "node_modules/",
    ".git/",
]

[badges]
style = "flat-square"
include_score = true
`;

    const configPath = vscode.Uri.joinPath(workspaceFolder.uri, '.rsr.toml');
    await vscode.workspace.fs.writeFile(configPath, Buffer.from(configContent));

    const doc = await vscode.workspace.openTextDocument(configPath);
    await vscode.window.showTextDocument(doc);

    vscode.window.showInformationMessage('RSR configuration created: .rsr.toml');
}

async function showReport() {
    // Create a webview panel for the report
    const panel = vscode.window.createWebviewPanel(
        'rsrReport',
        'RSR Compliance Report',
        vscode.ViewColumn.One,
        {}
    );

    // TODO: Get actual compliance data
    panel.webview.html = getReportHtml('silver', 75, [
        { name: 'License', tier: 'bronze', passed: true, message: 'MIT License detected' },
        { name: 'README', tier: 'bronze', passed: true, message: 'README.md found' },
        { name: 'Contributing', tier: 'silver', passed: true, message: 'CONTRIBUTING.md found' },
        { name: 'Documentation', tier: 'gold', passed: false, message: 'No docs/ directory found' }
    ]);
}

function getReportHtml(tier: string, score: number, checks: any[]): string {
    const passedChecks = checks.filter(c => c.passed).length;
    const totalChecks = checks.length;

    return `<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: var(--vscode-font-family); padding: 20px; }
        h1 { color: var(--vscode-foreground); }
        .tier { font-size: 24px; margin: 20px 0; }
        .tier.rhodium { color: #E8E4E1; }
        .tier.gold { color: #FFD700; }
        .tier.silver { color: #C0C0C0; }
        .tier.bronze { color: #CD7F32; }
        .score { font-size: 18px; color: var(--vscode-descriptionForeground); }
        .checks { margin-top: 20px; }
        .check { padding: 10px; margin: 5px 0; border-radius: 4px; }
        .check.passed { background: var(--vscode-testing-iconPassed); opacity: 0.2; }
        .check.failed { background: var(--vscode-testing-iconFailed); opacity: 0.2; }
        .check-icon { margin-right: 10px; }
    </style>
</head>
<body>
    <h1>RSR Compliance Report</h1>
    <div class="tier ${tier}">${getTierEmoji(tier)} ${tier.toUpperCase()}</div>
    <div class="score">Score: ${score}% (${passedChecks}/${totalChecks} checks passed)</div>
    <div class="checks">
        <h2>Checks</h2>
        ${checks.map(c => `
            <div class="check ${c.passed ? 'passed' : 'failed'}">
                <span class="check-icon">${c.passed ? '✓' : '✗'}</span>
                <strong>[${c.tier.toUpperCase()}]</strong> ${c.name}: ${c.message}
            </div>
        `).join('')}
    </div>
</body>
</html>`;
}

async function generateBadge() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    // TODO: Get actual tier from compliance check
    const tier = 'silver';
    const badgeMarkdown = `[![RSR Certification](https://rsr-certified.dev/badge/${tier}.svg)](https://rsr-certified.dev)`;

    await vscode.env.clipboard.writeText(badgeMarkdown);
    vscode.window.showInformationMessage('Badge markdown copied to clipboard!');
}

function onDocumentSave(document: vscode.TextDocument) {
    const relevantFiles = [
        'README.md', 'LICENSE', 'CONTRIBUTING.md', 'SECURITY.md',
        'CHANGELOG.md', 'CODE_OF_CONDUCT.md', '.rsr.toml'
    ];

    const fileName = path.basename(document.fileName);
    if (relevantFiles.includes(fileName) || fileName.startsWith('LICENSE')) {
        checkCompliance();
    }
}

export function deactivate(): Thenable<void> | undefined {
    if (client) {
        return client.stop();
    }
    return undefined;
}
