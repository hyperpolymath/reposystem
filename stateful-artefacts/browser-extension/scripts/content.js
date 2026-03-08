// SPDX-License-Identifier: MPL-2.0
// (PMPL-1.0-or-later preferred; MPL-2.0 required for Chrome Web Store)
// Gnosis content script - detects 6scm metadata on Git forge pages

(function() {
  'use strict';

  let cachedProjectData = null;

  // =========================================================================
  // Message Handling
  // =========================================================================

  chrome.runtime.onMessage.addListener((request, _sender, sendResponse) => {
    switch (request.action) {
      case 'getProjectData':
        if (cachedProjectData) {
          sendResponse({ data: cachedProjectData });
        } else {
          detectAndFetch().then(data => {
            sendResponse({ data: data });
          });
          return true; // async response
        }
        break;

      case 'changeFormat':
        applyFormat(request.mode);
        sendResponse({ success: true });
        break;

      case 'toggleAnnotations':
        toggleAnnotations(request.enabled);
        sendResponse({ success: true });
        break;
    }
  });

  // =========================================================================
  // SCM Detection
  // =========================================================================

  async function detectAndFetch() {
    const forge = detectForge();
    if (!forge) return null;

    const repoInfo = extractRepoInfo(forge);
    if (!repoInfo) return null;

    try {
      const scmContent = await fetchSCMFile(forge, repoInfo);
      if (scmContent) {
        cachedProjectData = parseSCM(scmContent);
        injectStatusBadge(cachedProjectData);
        return cachedProjectData;
      }
    } catch (_e) {
      // SCM file not found or inaccessible
    }
    return null;
  }

  function detectForge() {
    const host = window.location.hostname;
    if (host === 'github.com') return 'github';
    if (host === 'gitlab.com') return 'gitlab';
    if (host === 'bitbucket.org') return 'bitbucket';
    return null;
  }

  function extractRepoInfo(forge) {
    const path = window.location.pathname.split('/').filter(Boolean);
    if (path.length < 2) return null;
    const owner = path[0];
    const repo = path[1];
    return { forge, owner, repo };
  }

  async function fetchSCMFile(forge, info) {
    let url;
    if (forge === 'github') {
      url = 'https://api.github.com/repos/' + info.owner + '/' + info.repo
            + '/contents/.machine_readable/STATE.scm';
      const res = await fetch(url, {
        headers: { 'Accept': 'application/vnd.github.v3.raw' }
      });
      if (!res.ok) return null;
      return await res.text();
    } else if (forge === 'gitlab') {
      const projectPath = encodeURIComponent(info.owner + '/' + info.repo);
      const filePath = encodeURIComponent('.machine_readable/STATE.scm');
      url = 'https://gitlab.com/api/v4/projects/' + projectPath
            + '/repository/files/' + filePath + '/raw?ref=main';
      const res = await fetch(url);
      if (!res.ok) return null;
      return await res.text();
    }
    return null;
  }

  // =========================================================================
  // S-Expression Parser (lightweight, matches gnosis engine)
  // =========================================================================

  function parseSCM(content) {
    const lines = content.split('\n').filter(l => !l.trim().startsWith(';'));
    const cleaned = lines.join('\n');
    const tokens = tokenize(cleaned);
    const tree = parseTokens(tokens);
    return extractKeys(tree, []);
  }

  function tokenize(input) {
    const tokens = [];
    let i = 0;
    while (i < input.length) {
      const ch = input[i];
      if (' \t\n\r'.includes(ch)) { i++; continue; }
      if (ch === '(' || ch === ')') { tokens.push(ch); i++; continue; }
      if (ch === '"') {
        i++;
        let str = '';
        while (i < input.length && input[i] !== '"') { str += input[i]; i++; }
        i++;
        tokens.push({ type: 's', v: str });
        continue;
      }
      let atom = '';
      while (i < input.length && !' \t\n\r()"'.includes(input[i])) { atom += input[i]; i++; }
      tokens.push({ type: 'a', v: atom });
    }
    return tokens;
  }

  function parseTokens(tokens) {
    const state = { pos: 0 };
    return parseExpr(tokens, state);
  }

  function parseExpr(tokens, state) {
    if (state.pos >= tokens.length) return null;
    const t = tokens[state.pos];
    if (t === '(') {
      state.pos++;
      const items = [];
      while (state.pos < tokens.length && tokens[state.pos] !== ')') {
        const item = parseExpr(tokens, state);
        if (item) items.push(item);
      }
      state.pos++;
      return { type: 'list', items: items };
    }
    if (t === ')') return null;
    state.pos++;
    return { type: 'atom', value: t.v };
  }

  function extractKeys(node, path) {
    if (!node || node.type === 'atom') return {};
    const items = node.items || [];
    const result = {};

    // (key "value") pair
    if (items.length === 2 && items[0] && items[0].type === 'atom' && items[1] && items[1].type === 'atom' && items[1].value !== '.') {
      result[items[0].value] = items[1].value;
      if (path.length > 0) result[path.concat(items[0].value).join('.')] = items[1].value;
      return result;
    }
    // (key . "value") dotted pair
    if (items.length === 3 && items[0] && items[0].type === 'atom' && items[1] && items[1].type === 'atom' && items[1].value === '.' && items[2] && items[2].type === 'atom') {
      result[items[0].value] = items[2].value;
      if (path.length > 0) result[path.concat(items[0].value).join('.')] = items[2].value;
      return result;
    }
    // Recurse
    for (const item of items) {
      if (item && item.type === 'list' && item.items && item.items.length > 0 && item.items[0] && item.items[0].type === 'atom') {
        Object.assign(result, extractKeys(item, path.concat(item.items[0].value)));
      } else if (item && item.type === 'list') {
        Object.assign(result, extractKeys(item, path));
      }
    }
    return result;
  }

  // =========================================================================
  // Page Injection
  // =========================================================================

  function injectStatusBadge(data) {
    if (!data || !data.phase) return;

    // Only inject on repo main pages (not file views, PRs, etc.)
    const path = window.location.pathname.split('/').filter(Boolean);
    if (path.length > 2) return;

    // Check if already injected
    if (document.getElementById('gnosis-status-badge')) return;

    const badge = document.createElement('div');
    badge.id = 'gnosis-status-badge';
    badge.style.cssText =
      'position:fixed;bottom:16px;right:16px;z-index:9999;' +
      'background:linear-gradient(135deg,#667eea,#764ba2);' +
      'color:white;padding:8px 14px;border-radius:8px;' +
      'font-family:system-ui,sans-serif;font-size:12px;' +
      'box-shadow:0 4px 12px rgba(0,0,0,0.15);cursor:pointer;' +
      'display:flex;align-items:center;gap:8px;';

    const name = data.name || data.project || 'Project';
    const phase = data.phase || '?';
    const completion = data['overall-completion'] || '?';

    badge.innerHTML =
      '<span style="font-weight:600">' + escapeHtml(name) + '</span>' +
      '<span style="opacity:0.8">' + escapeHtml(phase) + '</span>' +
      '<span style="background:rgba(255,255,255,0.2);padding:2px 6px;border-radius:4px">' +
      escapeHtml(completion) + '%</span>';

    badge.title = 'Gnosis: 6scm metadata detected. Click to dismiss.';
    badge.addEventListener('click', () => badge.remove());

    document.body.appendChild(badge);
  }

  // =========================================================================
  // Format Toggle (Shields.io badges <-> plain text)
  // =========================================================================

  function applyFormat(mode) {
    if (mode === 'accessible') {
      document.querySelectorAll('img[src*="shields.io/badge"]').forEach(img => {
        if (img.dataset.gnosisOriginal) return;
        img.dataset.gnosisOriginal = img.src;
        const span = document.createElement('span');
        span.textContent = img.alt || img.src;
        span.className = 'gnosis-accessible-text';
        span.style.cssText = 'font-family:monospace;background:#f0f0f0;padding:2px 6px;border-radius:3px;font-size:0.9em';
        span.dataset.gnosisOriginal = img.src;
        img.replaceWith(span);
      });
    } else {
      document.querySelectorAll('.gnosis-accessible-text').forEach(span => {
        if (!span.dataset.gnosisOriginal) return;
        const img = document.createElement('img');
        img.src = span.dataset.gnosisOriginal;
        img.alt = span.textContent;
        span.replaceWith(img);
      });
    }
  }

  // =========================================================================
  // Annotation Layer Toggle
  // =========================================================================

  function toggleAnnotations(enabled) {
    const existing = document.getElementById('gnosis-annotation-sidebar');
    if (enabled && !existing) {
      // Inject annotation layer CSS + JS
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = chrome.runtime.getURL('annotations/annotations.css');
      document.head.appendChild(link);

      const script = document.createElement('script');
      script.src = chrome.runtime.getURL('annotations/annotations.js');
      document.body.appendChild(script);
    } else if (!enabled && existing) {
      existing.remove();
      const form = document.getElementById('gnosis-annotation-form');
      if (form) form.remove();
      document.querySelectorAll('.gnosis-highlight').forEach(el => {
        el.replaceWith(document.createTextNode(el.textContent));
      });
    }
  }

  // =========================================================================
  // Utilities
  // =========================================================================

  function escapeHtml(str) {
    const d = document.createElement('div');
    d.textContent = str || '';
    return d.innerHTML;
  }

  // =========================================================================
  // Auto-detect on page load
  // =========================================================================

  detectAndFetch();

  // Re-detect on SPA navigation (GitHub uses turbo)
  let lastUrl = window.location.href;
  const urlObserver = new MutationObserver(() => {
    if (window.location.href !== lastUrl) {
      lastUrl = window.location.href;
      cachedProjectData = null;
      const badge = document.getElementById('gnosis-status-badge');
      if (badge) badge.remove();
      detectAndFetch();
    }
  });
  urlObserver.observe(document.body, { childList: true, subtree: true });
})();
