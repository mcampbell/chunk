(() => {
  const target = document.getElementById('chunk-diff-view');
  const button = document.getElementById('chunk-view-switch');
  const diff = JSON.parse(document.getElementById('chunk-diff').textContent);
  const labels = { 'side-by-side': 'Show inline', 'line-by-line': 'Show side by side' };

  const render = () => {
    const format = target.dataset.format;
    new Diff2HtmlUI(target, diff, { outputFormat: format, drawFileList: true, matching: 'lines', highlight: true }).draw();
    button.textContent = labels[format];
  };

  button.addEventListener('click', () => {
    target.dataset.format = target.dataset.format === 'side-by-side' ? 'line-by-line' : 'side-by-side';
    render();
  });

  render();
})();
