// Gnosis Format Toggle Content Script
// Detects and transforms Gnosis-rendered content

(function() {
  'use strict';

  // Listen for format change messages
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'changeFormat') {
      applyFormat(request.mode);
      sendResponse({ success: true });
    }
  });

  // Apply format on page load
  chrome.storage.sync.get(['formatMode'], (result) => {
    const mode = result.formatMode || 'visual';
    applyFormat(mode);
  });

  function applyFormat(mode) {
    if (mode === 'accessible') {
      convertToAccessible();
    } else {
      convertToVisual();
    }
  }

  // Convert Shields.io badges to plain text
  function convertToAccessible() {
    // Find all images that look like Shields.io badges
    const images = document.querySelectorAll('img[src*="shields.io/badge"]');

    images.forEach(img => {
      const altText = img.alt;
      if (altText && !img.dataset.gnosisOriginal) {
        // Store original src for restoration
        img.dataset.gnosisOriginal = img.src;
        img.dataset.gnosisMode = 'accessible';

        // Replace with plain text
        const span = document.createElement('span');
        span.textContent = altText;
        span.className = 'gnosis-accessible-text';
        span.style.cssText = 'font-family: monospace; background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-size: 0.9em;';
        span.dataset.gnosisOriginal = img.dataset.gnosisOriginal;

        img.replaceWith(span);
      }
    });

    // Also convert any badges that are already converted back
    const accessibleTexts = document.querySelectorAll('.gnosis-accessible-text');
    accessibleTexts.forEach(span => {
      // Already in accessible mode, nothing to do
    });
  }

  // Restore Shields.io badges from plain text
  function convertToVisual() {
    // Find all accessible text elements we created
    const accessibleTexts = document.querySelectorAll('.gnosis-accessible-text');

    accessibleTexts.forEach(span => {
      if (span.dataset.gnosisOriginal) {
        const img = document.createElement('img');
        img.src = span.dataset.gnosisOriginal;
        img.alt = span.textContent;
        img.dataset.gnosisMode = 'visual';

        span.replaceWith(img);
      }
    });

    // Ensure badges are visible
    const images = document.querySelectorAll('img[src*="shields.io/badge"][data-gnosis-mode="accessible"]');
    images.forEach(img => {
      delete img.dataset.gnosisMode;
    });
  }

  // Detect when page content changes (for SPAs)
  const observer = new MutationObserver(() => {
    chrome.storage.sync.get(['formatMode'], (result) => {
      const mode = result.formatMode || 'visual';
      applyFormat(mode);
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
