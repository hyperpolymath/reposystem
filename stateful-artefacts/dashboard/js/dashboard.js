// Gnosis Living Dashboard - Main Logic
// Fetches data from Git forges and generates STATE.scm

(function() {
  'use strict';

  const form = document.getElementById('config-form');
  const metricsPanel = document.getElementById('metrics-panel');
  const scmOutput = document.getElementById('scm-output');
  const errorPanel = document.getElementById('error-panel');

  // Form submission handler
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const forge = document.getElementById('forge').value;
    const owner = document.getElementById('owner').value.trim();
    const repo = document.getElementById('repo').value.trim();
    const token = document.getElementById('token').value.trim();

    if (!owner || !repo) {
      showError('Please provide both owner and repository name');
      return;
    }

    hideError();
    showLoading(true);

    try {
      const data = await fetchRepoData(forge, owner, repo, token);
      displayMetrics(data);
      const scm = generateSCM(data);
      displaySCM(scm);
    } catch (error) {
      showError(error.message);
    } finally {
      showLoading(false);
    }
  });

  // Fetch repository data from Git forge API
  async function fetchRepoData(forge, owner, repo, token) {
    if (forge === 'github') {
      return await fetchGitHubData(owner, repo, token);
    } else if (forge === 'gitlab') {
      return await fetchGitLabData(owner, repo, token);
    } else if (forge === 'bitbucket') {
      return await fetchBitbucketData(owner, repo, token);
    }
    throw new Error(`Unsupported forge: ${forge}`);
  }

  // GitHub API integration
  async function fetchGitHubData(owner, repo, token) {
    const headers = {
      'Accept': 'application/vnd.github.v3+json'
    };
    if (token) {
      headers['Authorization'] = `token ${token}`;
    }

    // Fetch repository data
    const repoUrl = `https://api.github.com/repos/${owner}/${repo}`;
    const repoRes = await fetch(repoUrl, { headers });

    if (!repoRes.ok) {
      const error = await repoRes.json();
      throw new Error(`GitHub API error: ${error.message || repoRes.statusText}`);
    }

    const repoData = await repoRes.json();

    // Fetch recent commits for activity
    const commitsUrl = `https://api.github.com/repos/${owner}/${repo}/commits?per_page=1`;
    const commitsRes = await fetch(commitsUrl, { headers });
    const commits = commitsRes.ok ? await commitsRes.json() : [];

    // Fetch open issues and PRs count
    const issuesUrl = `https://api.github.com/repos/${owner}/${repo}/issues?state=open&per_page=1`;
    const issuesRes = await fetch(issuesUrl, { headers });
    const openIssuesCount = issuesRes.ok ? parseInt(issuesRes.headers.get('link')?.match(/page=(\d+)>; rel="last"/)?.[1] || repoData.open_issues_count) : repoData.open_issues_count;

    return {
      forge: 'github',
      name: repoData.name,
      fullName: repoData.full_name,
      description: repoData.description || 'No description',
      stars: repoData.stargazers_count,
      forks: repoData.forks_count,
      openIssues: openIssuesCount,
      openPRs: repoData.open_issues_count - openIssuesCount, // Approximation
      language: repoData.language || 'Multiple',
      license: repoData.license?.spdx_id || 'None',
      lastUpdated: new Date(repoData.updated_at),
      lastCommit: commits[0] ? new Date(commits[0].commit.author.date) : null,
      createdAt: new Date(repoData.created_at),
      isPrivate: repoData.private,
      defaultBranch: repoData.default_branch,
      url: repoData.html_url,
      hasIssues: repoData.has_issues,
      hasWiki: repoData.has_wiki,
      topics: repoData.topics || []
    };
  }

  // GitLab API integration (basic)
  async function fetchGitLabData(owner, repo, token) {
    const headers = {
      'Accept': 'application/json'
    };
    if (token) {
      headers['PRIVATE-TOKEN'] = token;
    }

    const projectPath = encodeURIComponent(`${owner}/${repo}`);
    const url = `https://gitlab.com/api/v4/projects/${projectPath}`;
    const res = await fetch(url, { headers });

    if (!res.ok) {
      throw new Error(`GitLab API error: ${res.statusText}`);
    }

    const data = await res.json();

    return {
      forge: 'gitlab',
      name: data.name,
      fullName: data.path_with_namespace,
      description: data.description || 'No description',
      stars: data.star_count,
      forks: data.forks_count,
      openIssues: data.open_issues_count || 0,
      openPRs: 0, // Would need separate API call
      language: 'Multiple',
      license: data.license?.name || 'None',
      lastUpdated: new Date(data.last_activity_at),
      lastCommit: null,
      createdAt: new Date(data.created_at),
      isPrivate: data.visibility === 'private',
      defaultBranch: data.default_branch,
      url: data.web_url,
      hasIssues: data.issues_enabled,
      hasWiki: data.wiki_enabled,
      topics: data.topics || []
    };
  }

  // Bitbucket API integration (basic)
  async function fetchBitbucketData(owner, repo, token) {
    const headers = {
      'Accept': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const url = `https://api.bitbucket.org/2.0/repositories/${owner}/${repo}`;
    const res = await fetch(url, { headers });

    if (!res.ok) {
      throw new Error(`Bitbucket API error: ${res.statusText}`);
    }

    const data = await res.json();

    return {
      forge: 'bitbucket',
      name: data.name,
      fullName: data.full_name,
      description: data.description || 'No description',
      stars: 0, // Bitbucket doesn't have stars
      forks: 0, // Would need separate API call
      openIssues: 0, // Would need separate API call
      openPRs: 0,
      language: data.language || 'Multiple',
      license: 'Unknown',
      lastUpdated: new Date(data.updated_on),
      lastCommit: null,
      createdAt: new Date(data.created_on),
      isPrivate: data.is_private,
      defaultBranch: data.mainbranch?.name || 'main',
      url: data.links.html.href,
      hasIssues: data.has_issues,
      hasWiki: data.has_wiki,
      topics: []
    };
  }

  // Display metrics in UI
  function displayMetrics(data) {
    document.getElementById('metric-name').textContent = data.name;
    document.getElementById('metric-stars').textContent = data.stars.toLocaleString();
    document.getElementById('metric-forks').textContent = data.forks.toLocaleString();
    document.getElementById('metric-issues').textContent = data.openIssues.toLocaleString();
    document.getElementById('metric-prs').textContent = data.openPRs.toLocaleString();
    document.getElementById('metric-language').textContent = data.language;
    document.getElementById('metric-license').textContent = data.license;

    const timeAgo = getTimeAgo(data.lastUpdated);
    document.getElementById('metric-updated').textContent = timeAgo;

    // Calculate and display health score
    const health = calculateHealthScore(data);
    document.getElementById('score-value').textContent = health.score;
    document.getElementById('score-details').innerHTML = health.details;

    metricsPanel.style.display = 'block';
  }

  // Calculate project health score
  function calculateHealthScore(data) {
    let score = 100;
    const factors = [];

    // Recent activity (max -30 points)
    const daysSinceUpdate = Math.floor((Date.now() - data.lastUpdated) / (1000 * 60 * 60 * 24));
    if (daysSinceUpdate > 90) {
      score -= 30;
      factors.push('⚠️ No updates in 90+ days');
    } else if (daysSinceUpdate > 30) {
      score -= 15;
      factors.push('⏳ Last updated 30+ days ago');
    } else {
      factors.push('✅ Recently active');
    }

    // Open issues (max -20 points)
    if (data.openIssues > 50) {
      score -= 20;
      factors.push(`⚠️ ${data.openIssues} open issues`);
    } else if (data.openIssues > 20) {
      score -= 10;
      factors.push(`⏳ ${data.openIssues} open issues`);
    } else {
      factors.push(`✅ ${data.openIssues} open issues (manageable)`);
    }

    // License (max -20 points)
    if (data.license === 'None' || data.license === 'Unknown') {
      score -= 20;
      factors.push('⚠️ No license specified');
    } else {
      factors.push(`✅ Licensed (${data.license})`);
    }

    // Documentation (max -15 points)
    if (!data.hasWiki) {
      score -= 10;
      factors.push('⚠️ No wiki');
    }
    if (data.description === 'No description') {
      score -= 5;
      factors.push('⚠️ No description');
    }

    // Issue tracking (max -15 points)
    if (!data.hasIssues) {
      score -= 15;
      factors.push('⚠️ Issues disabled');
    }

    score = Math.max(0, Math.min(100, score));

    return {
      score,
      details: factors.join('<br>')
    };
  }

  // Generate STATE.scm from data
  function generateSCM(data) {
    const now = new Date().toISOString();
    const phase = inferPhase(data);
    const health = calculateHealthScore(data);

    return `; SPDX-License-Identifier: PMPL-1.0-or-later
; Auto-generated by Gnosis Living Dashboard
; Generated: ${now}
; Source: ${data.forge} (${data.fullName})

(state
  (metadata
    (schema-version . "1.0.0")
    (generated-at . "${now}")
    (source . "${data.url}"))

  (identity
    (name . "${escapeString(data.name)}")
    (tagline . "${escapeString(data.description)}")
    (version . "auto")
    (phase . "${phase}")
    (license . "${data.license}"))

  (vital-signs
    (health-score . "${health.score}")
    (stars . "${data.stars}")
    (forks . "${data.forks}")
    (open-issues . "${data.openIssues}")
    (open-prs . "${data.openPRs}"))

  (activity
    (last-updated . "${data.lastUpdated.toISOString()}")
    (created-at . "${data.createdAt.toISOString()}")
    (default-branch . "${data.defaultBranch}"))

  (ecosystem
    (forge . "${data.forge}")
    (url . "${data.url}")
    (primary-language . "${data.language}")
    (has-issues . "${data.hasIssues}")
    (has-wiki . "${data.hasWiki}"))

  (tags . "${data.topics.join(', ')}"))
`;
  }

  // Infer project phase from metrics
  function inferPhase(data) {
    const age = (Date.now() - data.createdAt) / (1000 * 60 * 60 * 24); // days

    if (age < 30 && data.stars < 10) return 'alpha';
    if (age < 90 && data.stars < 50) return 'beta';
    if (data.stars > 1000) return 'production';
    if (data.stars > 100) return 'stable';
    return 'active';
  }

  // Display generated SCM
  function displaySCM(scm) {
    document.getElementById('scm-content').textContent = scm;
    scmOutput.style.display = 'block';

    // Copy to clipboard handler
    document.getElementById('copy-scm').onclick = () => {
      navigator.clipboard.writeText(scm).then(() => {
        alert('STATE.scm copied to clipboard!');
      });
    };

    // Download handler
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

  // Utility functions
  function showError(message) {
    document.getElementById('error-message').textContent = message;
    errorPanel.style.display = 'block';
  }

  function hideError() {
    errorPanel.style.display = 'none';
  }

  function showLoading(loading) {
    form.querySelector('button').disabled = loading;
    form.classList.toggle('loading', loading);
  }

  function getTimeAgo(date) {
    const seconds = Math.floor((Date.now() - date) / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return 'Just now';
  }

  function escapeString(str) {
    return str.replace(/"/g, '\\"').replace(/\n/g, ' ');
  }
})();
