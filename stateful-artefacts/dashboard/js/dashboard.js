// SPDX-License-Identifier: PMPL-1.0-or-later
// Gnosis Living Dashboard - Main Logic
// Fetches data from Git forges OR loads local SCM files

(function() {
  'use strict';

  const form = document.getElementById('config-form');
  const metricsPanel = document.getElementById('metrics-panel');
  const componentsPanel = document.getElementById('components-panel');
  const scmOutput = document.getElementById('scm-output');
  const errorPanel = document.getElementById('error-panel');

  let currentMode = 'forge';

  // Mode tab switching
  document.querySelectorAll('.mode-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.mode-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      currentMode = tab.dataset.mode;

      document.getElementById('forge-fields').style.display =
        currentMode === 'forge' ? 'block' : 'none';
      document.getElementById('local-fields').style.display =
        currentMode === 'local' ? 'block' : 'none';
    });
  });

  // Form submission handler
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError();
    showLoading(true);

    try {
      if (currentMode === 'local') {
        const pasteContent = document.getElementById('scm-paste').value.trim();
        const fileInput = document.getElementById('scm-files');

        if (pasteContent) {
          const parsed = parseSCM(pasteContent);
          displayLocalData(parsed);
        } else if (fileInput.files.length > 0) {
          const files = Array.from(fileInput.files);
          const scmFiles = files.filter(f => f.name.endsWith('.scm'));
          const merged = {};
          for (const file of scmFiles) {
            const content = await file.text();
            const parsed = parseSCM(content);
            Object.assign(merged, parsed);
          }
          displayLocalData(merged);
        } else {
          showError('Please paste SCM content or select .machine_readable/ directory');
        }
      } else {
        const forge = document.getElementById('forge').value;
        const owner = document.getElementById('owner').value.trim();
        const repo = document.getElementById('repo').value.trim();
        const token = document.getElementById('token').value.trim();

        if (!owner || !repo) {
          showError('Please provide both owner and repository name');
          return;
        }

        const data = await fetchRepoData(forge, owner, repo, token);
        displayMetrics(data);
        const scm = generateSCM(data);
        displaySCM(scm);
      }
    } catch (error) {
      showError(error.message);
    } finally {
      showLoading(false);
    }
  });

  // =========================================================================
  // Local SCM Parser (mirrors Gnosis SExp parser logic)
  // =========================================================================

  function parseSCM(content) {
    const lines = content.split('\n').filter(l => !l.trim().startsWith(';'));
    const cleaned = lines.join('\n');
    const tokens = tokenize(cleaned);
    const tree = parseTokens(tokens);
    return extractKeysFromTree(tree, []);
  }

  function tokenize(input) {
    const tokens = [];
    let i = 0;
    while (i < input.length) {
      const ch = input[i];
      if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
        i++;
      } else if (ch === '(' || ch === ')') {
        tokens.push(ch);
        i++;
      } else if (ch === '"') {
        i++;
        let str = '';
        while (i < input.length && input[i] !== '"') {
          str += input[i];
          i++;
        }
        i++; // skip closing quote
        tokens.push({ type: 'string', value: str });
      } else {
        let atom = '';
        while (i < input.length && !' \t\n\r()\"'.includes(input[i])) {
          atom += input[i];
          i++;
        }
        tokens.push({ type: 'atom', value: atom });
      }
    }
    return tokens;
  }

  function parseTokens(tokens) {
    const result = { pos: 0 };
    return parseExpr(tokens, result);
  }

  function parseExpr(tokens, state) {
    if (state.pos >= tokens.length) return null;
    const token = tokens[state.pos];

    if (token === '(') {
      state.pos++;
      const items = [];
      while (state.pos < tokens.length && tokens[state.pos] !== ')') {
        const item = parseExpr(tokens, state);
        if (item !== null) items.push(item);
      }
      state.pos++; // skip ')'
      return { type: 'list', items };
    } else if (token === ')') {
      return null;
    } else {
      state.pos++;
      return { type: 'atom', value: token.value };
    }
  }

  function extractKeysFromTree(node, path) {
    if (!node || node.type === 'atom') return {};
    const result = {};
    const items = node.items || [];

    if (items.length === 2 && items[0]?.type === 'atom' && items[1]?.type === 'atom' && items[1]?.value !== '.') {
      const key = items[0].value;
      result[key] = items[1].value;
      if (path.length > 0) {
        result[path.concat(key).join('.')] = items[1].value;
      }
    } else if (items.length === 3 && items[0]?.type === 'atom' && items[1]?.type === 'atom' && items[1]?.value === '.' && items[2]?.type === 'atom') {
      const key = items[0].value;
      result[key] = items[2].value;
      if (path.length > 0) {
        result[path.concat(key).join('.')] = items[2].value;
      }
    } else {
      for (const item of items) {
        if (item?.type === 'list' && item.items?.length > 0 && item.items[0]?.type === 'atom') {
          const sub = extractKeysFromTree(item, path.concat(item.items[0].value));
          Object.assign(result, sub);
        } else if (item?.type === 'list') {
          const sub = extractKeysFromTree(item, path);
          Object.assign(result, sub);
        }
      }
    }
    return result;
  }

  // Display data from local SCM files
  function displayLocalData(data) {
    // Show basic metrics from SCM
    document.getElementById('metric-name').textContent = data.name || data.project || 'Unknown';
    document.getElementById('metric-stars').textContent = data['star-count'] || '-';
    document.getElementById('metric-forks').textContent = data['fork-count'] || '-';
    document.getElementById('metric-issues').textContent = data['open-issues'] || '-';
    document.getElementById('metric-prs').textContent = data['open-prs'] || '-';
    document.getElementById('metric-language').textContent = data.primary || data.language || '-';
    document.getElementById('metric-license').textContent = data.license || '-';
    document.getElementById('metric-updated').textContent = data.updated || data['last-updated'] || '-';

    // Health score from SCM
    const healthScore = data['health-score'] || data['overall-completion'] || '-';
    document.getElementById('score-value').textContent = healthScore;
    document.getElementById('score-details').innerHTML =
      'Phase: ' + (data.phase || 'unknown') + '<br>' +
      'Version: ' + (data.version || 'unknown') + '<br>' +
      'Tagline: ' + (data.tagline || '-');

    metricsPanel.style.display = 'block';

    // Show component status if available
    displayComponents(data);

    // Show raw SCM as output
    const scmText = Object.entries(data)
      .map(([k, v]) => `  ${k} = ${v}`)
      .join('\n');
    displaySCM('; Parsed SCM context (' + Object.keys(data).length + ' keys)\n\n' + scmText);
  }

  // Display component completion grid
  function displayComponents(data) {
    const componentKeys = Object.entries(data).filter(([k]) =>
      k.startsWith('components.') && !k.includes('..'));
    if (componentKeys.length === 0) {
      componentsPanel.style.display = 'none';
      return;
    }

    const grid = document.getElementById('components-grid');
    grid.innerHTML = '';

    const statusColors = {
      'complete': '#48bb78',
      'scaffolded': '#ed8936',
      'designed': '#4299e1',
      'planned': '#a0aec0',
      'in-progress': '#ecc94b'
    };

    componentKeys.forEach(([key, status]) => {
      const name = key.replace('components.', '');
      const card = document.createElement('div');
      card.className = 'component-card';
      card.style.borderLeft = '4px solid ' + (statusColors[status] || '#a0aec0');
      card.innerHTML = `
        <div class="component-name">${name}</div>
        <div class="component-status" style="color: ${statusColors[status] || '#a0aec0'}">${status}</div>
      `;
      grid.appendChild(card);
    });

    const completion = data['overall-completion'] || '0';
    document.getElementById('overall-completion').textContent = completion;
    document.getElementById('completion-fill').style.width = completion + '%';

    componentsPanel.style.display = 'block';
  }

  // =========================================================================
  // Git Forge API Mode
  // =========================================================================

  async function fetchRepoData(forge, owner, repo, token) {
    if (forge === 'github') {
      return await fetchGitHubData(owner, repo, token);
    } else if (forge === 'gitlab') {
      return await fetchGitLabData(owner, repo, token);
    } else if (forge === 'bitbucket') {
      return await fetchBitbucketData(owner, repo, token);
    }
    throw new Error('Unsupported forge: ' + forge);
  }

  async function fetchGitHubData(owner, repo, token) {
    const headers = { 'Accept': 'application/vnd.github.v3+json' };
    if (token) headers['Authorization'] = 'token ' + token;

    const repoUrl = 'https://api.github.com/repos/' + owner + '/' + repo;
    const repoRes = await fetch(repoUrl, { headers });
    if (!repoRes.ok) {
      const error = await repoRes.json();
      throw new Error('GitHub API error: ' + (error.message || repoRes.statusText));
    }
    const repoData = await repoRes.json();

    const commitsUrl = 'https://api.github.com/repos/' + owner + '/' + repo + '/commits?per_page=1';
    const commitsRes = await fetch(commitsUrl, { headers });
    const commits = commitsRes.ok ? await commitsRes.json() : [];

    return {
      forge: 'github', name: repoData.name, fullName: repoData.full_name,
      description: repoData.description || 'No description',
      stars: repoData.stargazers_count, forks: repoData.forks_count,
      openIssues: repoData.open_issues_count, openPRs: 0,
      language: repoData.language || 'Multiple',
      license: repoData.license ? repoData.license.spdx_id : 'None',
      lastUpdated: new Date(repoData.updated_at),
      lastCommit: commits[0] ? new Date(commits[0].commit.author.date) : null,
      createdAt: new Date(repoData.created_at),
      isPrivate: repoData.private, defaultBranch: repoData.default_branch,
      url: repoData.html_url, hasIssues: repoData.has_issues,
      hasWiki: repoData.has_wiki, topics: repoData.topics || []
    };
  }

  async function fetchGitLabData(owner, repo, token) {
    const headers = { 'Accept': 'application/json' };
    if (token) headers['PRIVATE-TOKEN'] = token;
    const projectPath = encodeURIComponent(owner + '/' + repo);
    const url = 'https://gitlab.com/api/v4/projects/' + projectPath;
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error('GitLab API error: ' + res.statusText);
    const data = await res.json();
    return {
      forge: 'gitlab', name: data.name, fullName: data.path_with_namespace,
      description: data.description || 'No description',
      stars: data.star_count, forks: data.forks_count,
      openIssues: data.open_issues_count || 0, openPRs: 0,
      language: 'Multiple', license: data.license ? data.license.name : 'None',
      lastUpdated: new Date(data.last_activity_at), lastCommit: null,
      createdAt: new Date(data.created_at), isPrivate: data.visibility === 'private',
      defaultBranch: data.default_branch, url: data.web_url,
      hasIssues: data.issues_enabled, hasWiki: data.wiki_enabled, topics: data.topics || []
    };
  }

  async function fetchBitbucketData(owner, repo, token) {
    const headers = { 'Accept': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    const url = 'https://api.bitbucket.org/2.0/repositories/' + owner + '/' + repo;
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error('Bitbucket API error: ' + res.statusText);
    const data = await res.json();
    return {
      forge: 'bitbucket', name: data.name, fullName: data.full_name,
      description: data.description || 'No description',
      stars: 0, forks: 0, openIssues: 0, openPRs: 0,
      language: data.language || 'Multiple', license: 'Unknown',
      lastUpdated: new Date(data.updated_on), lastCommit: null,
      createdAt: new Date(data.created_on), isPrivate: data.is_private,
      defaultBranch: data.mainbranch ? data.mainbranch.name : 'main',
      url: data.links.html.href, hasIssues: data.has_issues,
      hasWiki: data.has_wiki, topics: []
    };
  }

  // =========================================================================
  // Display Functions
  // =========================================================================

  function displayMetrics(data) {
    document.getElementById('metric-name').textContent = data.name;
    document.getElementById('metric-stars').textContent = data.stars.toLocaleString();
    document.getElementById('metric-forks').textContent = data.forks.toLocaleString();
    document.getElementById('metric-issues').textContent = data.openIssues.toLocaleString();
    document.getElementById('metric-prs').textContent = data.openPRs.toLocaleString();
    document.getElementById('metric-language').textContent = data.language;
    document.getElementById('metric-license').textContent = data.license;
    document.getElementById('metric-updated').textContent = getTimeAgo(data.lastUpdated);

    const health = calculateHealthScore(data);
    document.getElementById('score-value').textContent = health.score;
    document.getElementById('score-details').innerHTML = health.details;
    metricsPanel.style.display = 'block';
  }

  function calculateHealthScore(data) {
    let score = 100;
    const factors = [];
    const daysSinceUpdate = Math.floor((Date.now() - data.lastUpdated) / (1000 * 60 * 60 * 24));
    if (daysSinceUpdate > 90) { score -= 30; factors.push('No updates in 90+ days'); }
    else if (daysSinceUpdate > 30) { score -= 15; factors.push('Last updated 30+ days ago'); }
    else { factors.push('Recently active'); }
    if (data.openIssues > 50) { score -= 20; factors.push(data.openIssues + ' open issues'); }
    else if (data.openIssues > 20) { score -= 10; factors.push(data.openIssues + ' open issues'); }
    if (data.license === 'None' || data.license === 'Unknown') { score -= 20; factors.push('No license'); }
    score = Math.max(0, Math.min(100, score));
    return { score, details: factors.join('<br>') };
  }

  function generateSCM(data) {
    const now = new Date().toISOString();
    const phase = inferPhase(data);
    const health = calculateHealthScore(data);
    return '; SPDX-License-Identifier: PMPL-1.0-or-later\n'
      + '; Auto-generated by Gnosis Living Dashboard\n'
      + '; Generated: ' + now + '\n'
      + '; Source: ' + data.forge + ' (' + data.fullName + ')\n\n'
      + '(state\n'
      + '  (metadata\n'
      + '    (schema-version . "1.0.0")\n'
      + '    (generated-at . "' + now + '")\n'
      + '    (source . "' + data.url + '"))\n\n'
      + '  (identity\n'
      + '    (name . "' + escapeString(data.name) + '")\n'
      + '    (tagline . "' + escapeString(data.description) + '")\n'
      + '    (version . "auto")\n'
      + '    (phase . "' + phase + '")\n'
      + '    (license . "' + data.license + '"))\n\n'
      + '  (vital-signs\n'
      + '    (health-score . "' + health.score + '")\n'
      + '    (stars . "' + data.stars + '")\n'
      + '    (forks . "' + data.forks + '")\n'
      + '    (open-issues . "' + data.openIssues + '")\n'
      + '    (open-prs . "' + data.openPRs + '"))\n\n'
      + '  (activity\n'
      + '    (last-updated . "' + data.lastUpdated.toISOString() + '")\n'
      + '    (created-at . "' + data.createdAt.toISOString() + '")\n'
      + '    (default-branch . "' + data.defaultBranch + '"))\n\n'
      + '  (ecosystem\n'
      + '    (forge . "' + data.forge + '")\n'
      + '    (url . "' + data.url + '")\n'
      + '    (primary-language . "' + data.language + '")\n'
      + '    (has-issues . "' + data.hasIssues + '")\n'
      + '    (has-wiki . "' + data.hasWiki + '"))\n\n'
      + '  (tags . "' + data.topics.join(', ') + '"))\n';
  }

  function inferPhase(data) {
    const age = (Date.now() - data.createdAt) / (1000 * 60 * 60 * 24);
    if (age < 30 && data.stars < 10) return 'alpha';
    if (age < 90 && data.stars < 50) return 'beta';
    if (data.stars > 1000) return 'production';
    if (data.stars > 100) return 'stable';
    return 'active';
  }

  function displaySCM(scm) {
    document.getElementById('scm-content').textContent = scm;
    scmOutput.style.display = 'block';

    document.getElementById('copy-scm').onclick = () => {
      navigator.clipboard.writeText(scm).then(() => {
        const btn = document.getElementById('copy-scm');
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = 'Copy to Clipboard'; }, 2000);
      });
    };

    document.getElementById('download-scm').onclick = () => {
      const blob = new Blob([scm], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'STATE.scm';
      a.click();
      URL.revokeObjectURL(url);
    };
  }

  // =========================================================================
  // Utilities
  // =========================================================================

  function showError(message) {
    document.getElementById('error-message').textContent = message;
    errorPanel.style.display = 'block';
  }

  function hideError() { errorPanel.style.display = 'none'; }

  function showLoading(loading) {
    form.querySelector('button[type="submit"]').disabled = loading;
    form.classList.toggle('loading', loading);
  }

  function getTimeAgo(date) {
    const seconds = Math.floor((Date.now() - date) / 1000);
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds / 60);
    if (days > 0) return days + 'd ago';
    if (hours > 0) return hours + 'h ago';
    if (minutes > 0) return minutes + 'm ago';
    return 'Just now';
  }

  function escapeString(str) {
    return str.replace(/"/g, '\\"').replace(/\n/g, ' ');
  }
})();
