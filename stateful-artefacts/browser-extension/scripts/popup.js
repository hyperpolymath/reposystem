// SPDX-License-Identifier: MPL-2.0
// (PMPL-1.0-or-later preferred; MPL-2.0 required for Chrome Web Store)
// Gnosis popup - displays 6scm project state from current repo page

(function() {
  'use strict';

  // Load toggles from storage
  chrome.storage.sync.get(['formatMode', 'annotationsEnabled'], (result) => {
    const formatToggle = document.getElementById('format-toggle');
    const annotationToggle = document.getElementById('annotation-toggle');

    if (result.formatMode === 'accessible') formatToggle.classList.add('on');
    if (result.annotationsEnabled) annotationToggle.classList.add('on');
  });

  // Format toggle
  document.getElementById('format-toggle').addEventListener('click', function() {
    this.classList.toggle('on');
    const mode = this.classList.contains('on') ? 'accessible' : 'visual';
    chrome.storage.sync.set({ formatMode: mode });
    sendToContentScript({ action: 'changeFormat', mode: mode });
  });

  // Annotation toggle
  document.getElementById('annotation-toggle').addEventListener('click', function() {
    this.classList.toggle('on');
    const enabled = this.classList.contains('on');
    chrome.storage.sync.set({ annotationsEnabled: enabled });
    sendToContentScript({ action: 'toggleAnnotations', enabled: enabled });
  });

  // Ask content script for detected SCM data
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (!tabs[0]) return;

    chrome.tabs.sendMessage(tabs[0].id, { action: 'getProjectData' }, (response) => {
      if (chrome.runtime.lastError || !response || !response.data) {
        showNotDetected();
        return;
      }
      showProjectData(response.data);
    });
  });

  function showNotDetected() {
    document.getElementById('status-bar').className = 'status-bar not-detected';
    document.getElementById('status-bar').innerHTML =
      '<span class="status-dot yellow"></span>' +
      '<span>No 6scm metadata detected on this page</span>';
    document.getElementById('empty-state').style.display = 'block';
    document.getElementById('project-info').style.display = 'none';
  }

  function showProjectData(data) {
    document.getElementById('status-bar').className = 'status-bar detected';
    document.getElementById('status-bar').innerHTML =
      '<span class="status-dot green"></span>' +
      '<span>6scm metadata detected</span>';
    document.getElementById('empty-state').style.display = 'none';
    document.getElementById('project-info').style.display = 'block';

    // Fill in project info
    document.getElementById('val-name').textContent = data.name || data.project || '-';
    document.getElementById('val-version').textContent = data.version || '-';
    document.getElementById('val-phase').textContent = data.phase || '-';
    document.getElementById('val-updated').textContent = data.updated || '-';
    document.getElementById('val-license').textContent = data.license || '-';

    const completion = data['overall-completion'] || '0';
    document.getElementById('val-completion').textContent = completion + '%';
    document.getElementById('progress-fill').style.width = completion + '%';

    // Components
    const componentEntries = Object.entries(data).filter(([k]) =>
      k.startsWith('components.') && !k.includes('..'));
    if (componentEntries.length > 0) {
      document.getElementById('components-section').style.display = 'block';
      document.getElementById('component-count').textContent = componentEntries.length;
      const list = document.getElementById('component-list');
      list.innerHTML = '';
      componentEntries.forEach(([key, status]) => {
        const name = key.replace('components.', '');
        const li = document.createElement('li');
        const badgeClass = 'status-' + (status || 'planned');
        li.innerHTML =
          '<span class="status-badge ' + badgeClass + '">' + escapeHtml(status) + '</span>' +
          '<span>' + escapeHtml(name) + '</span>';
        list.appendChild(li);
      });
    }

    // Blockers
    if (data.blockers && data.blockers.length > 0) {
      document.getElementById('blockers-section').style.display = 'block';
      const blist = document.getElementById('blockers-list');
      blist.innerHTML = '';
      data.blockers.forEach(b => {
        const li = document.createElement('li');
        li.textContent = b;
        blist.appendChild(li);
      });
    }
  }

  function sendToContentScript(message) {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      if (tabs[0]) {
        chrome.tabs.sendMessage(tabs[0].id, message);
      }
    });
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str || '';
    return div.innerHTML;
  }
})();
