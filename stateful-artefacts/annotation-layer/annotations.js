// SPDX-License-Identifier: PMPL-1.0-or-later
// Gnosis Annotation Layer - Hypothesis-style post-it notes on rendered docs
//
// Usage: Include this script in rendered HTML output to enable annotations.
//   <script src="annotations.js"></script>
//   <link rel="stylesheet" href="annotations.css">
//
// Annotations are stored as JSON in .annotations/ directory alongside rendered files.
// Git history tracks annotation changes over time.

(function() {
  'use strict';

  const STORAGE_KEY = 'gnosis-annotations';
  const ANNOTATION_ATTR = 'data-gnosis-annotation';

  // =========================================================================
  // Annotation Data Model
  // =========================================================================

  // Annotation structure:
  // {
  //   id: string (UUID),
  //   file: string (source file path),
  //   selector: string (CSS selector or text anchor),
  //   selectedText: string (highlighted text),
  //   note: string (annotation content),
  //   author: string,
  //   created: string (ISO timestamp),
  //   updated: string (ISO timestamp),
  //   thread: string|null (parent annotation ID for replies),
  //   visibility: 'private'|'contributors'|'public'
  // }

  let annotations = [];
  let activeAnnotation = null;

  // =========================================================================
  // Initialization
  // =========================================================================

  function init() {
    loadAnnotations();
    createSidebar();
    renderHighlights();
    setupTextSelection();
  }

  // =========================================================================
  // Storage (localStorage for browser, .annotations/ for git-backed)
  // =========================================================================

  function loadAnnotations() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      annotations = stored ? JSON.parse(stored) : [];
    } catch (_e) {
      annotations = [];
    }
  }

  function saveAnnotations() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(annotations));
    renderHighlights();
    renderAnnotationList();
  }

  function generateId() {
    return 'ann-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
  }

  // =========================================================================
  // UI: Sidebar
  // =========================================================================

  function createSidebar() {
    const sidebar = document.createElement('div');
    sidebar.id = 'gnosis-annotation-sidebar';
    sidebar.innerHTML =
      '<div class="gnosis-sidebar-header">' +
        '<h3>Annotations</h3>' +
        '<span class="gnosis-annotation-count">' + annotations.length + '</span>' +
        '<button class="gnosis-sidebar-toggle" title="Toggle sidebar">&#9776;</button>' +
      '</div>' +
      '<div class="gnosis-sidebar-body">' +
        '<div id="gnosis-annotation-list"></div>' +
      '</div>' +
      '<div class="gnosis-sidebar-footer">' +
        '<button id="gnosis-export-btn" title="Export annotations as JSON">Export</button>' +
        '<button id="gnosis-import-btn" title="Import annotations from JSON">Import</button>' +
      '</div>';
    document.body.appendChild(sidebar);

    // Toggle sidebar
    sidebar.querySelector('.gnosis-sidebar-toggle').addEventListener('click', () => {
      sidebar.classList.toggle('collapsed');
    });

    // Export button
    document.getElementById('gnosis-export-btn').addEventListener('click', exportAnnotations);

    // Import button
    document.getElementById('gnosis-import-btn').addEventListener('click', importAnnotations);

    renderAnnotationList();
  }

  function renderAnnotationList() {
    const list = document.getElementById('gnosis-annotation-list');
    if (!list) return;

    const count = document.querySelector('.gnosis-annotation-count');
    if (count) count.textContent = annotations.length;

    if (annotations.length === 0) {
      list.innerHTML = '<p class="gnosis-no-annotations">No annotations yet. Select text to add one.</p>';
      return;
    }

    // Group by thread (top-level first)
    const topLevel = annotations.filter(a => !a.thread);
    const replies = annotations.filter(a => a.thread);

    list.innerHTML = '';
    topLevel.forEach(ann => {
      const card = createAnnotationCard(ann);
      list.appendChild(card);

      // Append replies
      const threadReplies = replies.filter(r => r.thread === ann.id);
      threadReplies.forEach(reply => {
        const replyCard = createAnnotationCard(reply, true);
        list.appendChild(replyCard);
      });
    });
  }

  function createAnnotationCard(ann, isReply) {
    const card = document.createElement('div');
    card.className = 'gnosis-annotation-card' + (isReply ? ' gnosis-reply' : '');
    card.dataset.id = ann.id;

    const dateStr = new Date(ann.created).toLocaleDateString();
    card.innerHTML =
      '<div class="gnosis-annotation-meta">' +
        '<span class="gnosis-annotation-author">' + escapeHtml(ann.author || 'Anonymous') + '</span>' +
        '<span class="gnosis-annotation-date">' + dateStr + '</span>' +
      '</div>' +
      (ann.selectedText ?
        '<div class="gnosis-annotation-quote">' + escapeHtml(ann.selectedText.slice(0, 80)) +
        (ann.selectedText.length > 80 ? '...' : '') + '</div>' : '') +
      '<div class="gnosis-annotation-note">' + escapeHtml(ann.note) + '</div>' +
      '<div class="gnosis-annotation-actions">' +
        '<button class="gnosis-reply-btn" title="Reply">Reply</button>' +
        '<button class="gnosis-delete-btn" title="Delete">Delete</button>' +
      '</div>';

    // Click to scroll to highlight
    card.addEventListener('click', (e) => {
      if (e.target.tagName === 'BUTTON') return;
      scrollToAnnotation(ann.id);
    });

    // Reply button
    card.querySelector('.gnosis-reply-btn').addEventListener('click', () => {
      showAnnotationForm(null, ann.id);
    });

    // Delete button
    card.querySelector('.gnosis-delete-btn').addEventListener('click', () => {
      annotations = annotations.filter(a => a.id !== ann.id && a.thread !== ann.id);
      saveAnnotations();
    });

    return card;
  }

  // =========================================================================
  // UI: Text Selection and Annotation Creation
  // =========================================================================

  function setupTextSelection() {
    document.addEventListener('mouseup', (e) => {
      // Ignore clicks in the sidebar
      if (e.target.closest('#gnosis-annotation-sidebar')) return;
      if (e.target.closest('#gnosis-annotation-form')) return;

      const selection = window.getSelection();
      if (!selection || selection.isCollapsed || selection.toString().trim().length === 0) {
        return;
      }

      const selectedText = selection.toString().trim();
      if (selectedText.length < 3) return;

      showAnnotationForm(selectedText, null);
    });
  }

  function showAnnotationForm(selectedText, threadId) {
    // Remove existing form
    const existing = document.getElementById('gnosis-annotation-form');
    if (existing) existing.remove();

    const form = document.createElement('div');
    form.id = 'gnosis-annotation-form';
    form.innerHTML =
      '<div class="gnosis-form-content">' +
        '<h4>' + (threadId ? 'Reply' : 'Add Annotation') + '</h4>' +
        (selectedText ?
          '<div class="gnosis-form-quote">' + escapeHtml(selectedText.slice(0, 120)) + '</div>' : '') +
        '<textarea id="gnosis-note-input" placeholder="Your note..." rows="3"></textarea>' +
        '<input type="text" id="gnosis-author-input" placeholder="Your name (optional)"' +
        ' value="' + escapeHtml(localStorage.getItem('gnosis-author') || '') + '">' +
        '<div class="gnosis-form-actions">' +
          '<button id="gnosis-save-btn">Save</button>' +
          '<button id="gnosis-cancel-btn">Cancel</button>' +
        '</div>' +
      '</div>';

    document.body.appendChild(form);

    document.getElementById('gnosis-note-input').focus();

    document.getElementById('gnosis-save-btn').addEventListener('click', () => {
      const note = document.getElementById('gnosis-note-input').value.trim();
      const author = document.getElementById('gnosis-author-input').value.trim();

      if (!note) return;

      if (author) localStorage.setItem('gnosis-author', author);

      const annotation = {
        id: generateId(),
        file: window.location.pathname,
        selector: selectedText ? getTextSelector(selectedText) : '',
        selectedText: selectedText || '',
        note: note,
        author: author || 'Anonymous',
        created: new Date().toISOString(),
        updated: new Date().toISOString(),
        thread: threadId || null,
        visibility: 'private'
      };

      annotations.push(annotation);
      saveAnnotations();
      form.remove();
    });

    document.getElementById('gnosis-cancel-btn').addEventListener('click', () => {
      form.remove();
    });
  }

  // =========================================================================
  // Highlighting
  // =========================================================================

  function renderHighlights() {
    // Remove existing highlights
    document.querySelectorAll('.gnosis-highlight').forEach(el => {
      const parent = el.parentNode;
      parent.replaceChild(document.createTextNode(el.textContent), el);
      parent.normalize();
    });

    // Apply highlights for annotations with selected text
    annotations.forEach(ann => {
      if (!ann.selectedText) return;
      highlightText(ann.selectedText, ann.id);
    });
  }

  function highlightText(text, annotationId) {
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: function(node) {
          // Skip sidebar and form
          if (node.parentElement.closest('#gnosis-annotation-sidebar')) return NodeFilter.FILTER_REJECT;
          if (node.parentElement.closest('#gnosis-annotation-form')) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );

    while (walker.nextNode()) {
      const node = walker.currentNode;
      const idx = node.textContent.indexOf(text);
      if (idx === -1) continue;

      const range = document.createRange();
      range.setStart(node, idx);
      range.setEnd(node, idx + text.length);

      const highlight = document.createElement('mark');
      highlight.className = 'gnosis-highlight';
      highlight.setAttribute(ANNOTATION_ATTR, annotationId);
      highlight.title = 'Click to view annotation';
      highlight.addEventListener('click', () => {
        scrollToAnnotationCard(annotationId);
      });

      range.surroundContents(highlight);
      break; // Only highlight first occurrence
    }
  }

  function scrollToAnnotation(id) {
    const highlight = document.querySelector('[' + ANNOTATION_ATTR + '="' + id + '"]');
    if (highlight) {
      highlight.scrollIntoView({ behavior: 'smooth', block: 'center' });
      highlight.classList.add('gnosis-highlight-active');
      setTimeout(() => highlight.classList.remove('gnosis-highlight-active'), 2000);
    }
  }

  function scrollToAnnotationCard(id) {
    const card = document.querySelector('.gnosis-annotation-card[data-id="' + id + '"]');
    if (card) {
      const sidebar = document.getElementById('gnosis-annotation-sidebar');
      sidebar.classList.remove('collapsed');
      card.scrollIntoView({ behavior: 'smooth', block: 'center' });
      card.classList.add('gnosis-card-active');
      setTimeout(() => card.classList.remove('gnosis-card-active'), 2000);
    }
  }

  // =========================================================================
  // Export / Import
  // =========================================================================

  function exportAnnotations() {
    const data = JSON.stringify(annotations, null, 2);
    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'annotations.json';
    a.click();
    URL.revokeObjectURL(url);
  }

  function importAnnotations() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.addEventListener('change', async (e) => {
      const file = e.target.files[0];
      if (!file) return;
      try {
        const text = await file.text();
        const imported = JSON.parse(text);
        if (!Array.isArray(imported)) throw new Error('Invalid format');
        // Merge, avoiding duplicates by ID
        const existingIds = new Set(annotations.map(a => a.id));
        const newOnes = imported.filter(a => !existingIds.has(a.id));
        annotations = annotations.concat(newOnes);
        saveAnnotations();
      } catch (_err) {
        // Silently fail on invalid JSON
      }
    });
    input.click();
  }

  // =========================================================================
  // Utilities
  // =========================================================================

  function getTextSelector(text) {
    // Simple text-based selector for persistence
    return 'text:' + text.slice(0, 50).replace(/[^a-zA-Z0-9 ]/g, '');
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // =========================================================================
  // Start
  // =========================================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
