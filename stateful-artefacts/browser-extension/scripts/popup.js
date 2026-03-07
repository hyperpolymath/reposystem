// Load current preference
chrome.storage.sync.get(['formatMode'], (result) => {
  const mode = result.formatMode || 'visual';
  const radio = document.querySelector(`input[value="${mode}"]`);
  if (radio) {
    radio.checked = true;
    document.querySelector(`.option[data-mode="${mode}"]`).classList.add('active');
  }
  updateStatus(mode);
});

// Handle option clicks
document.querySelectorAll('.option').forEach(option => {
  option.addEventListener('click', () => {
    const mode = option.dataset.mode;
    const radio = option.querySelector('input[type="radio"]');
    radio.checked = true;

    // Update UI
    document.querySelectorAll('.option').forEach(o => o.classList.remove('active'));
    option.classList.add('active');

    // Save preference
    chrome.storage.sync.set({ formatMode: mode }, () => {
      updateStatus(mode);

      // Notify content script to apply changes
      chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        if (tabs[0]) {
          chrome.tabs.sendMessage(tabs[0].id, {
            action: 'changeFormat',
            mode: mode
          });
        }
      });
    });
  });
});

function updateStatus(mode) {
  const statusText = document.getElementById('status-text');
  statusText.textContent = mode === 'visual'
    ? '✅ Showing badges and emoji'
    : '✅ Showing plain text';
}
