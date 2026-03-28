<script>
  import { activeTab } from '../stores/tabs.js';

  $: tab = $activeTab;
  $: response = tab?.response ?? null;
  $: error = tab?.error ?? null;
  $: loading = tab?.loading ?? false;

  $: isJson = isJsonContent(response?.headers);
  $: formattedBody = formatBody(response?.body, response?.headers);

  let showHeaders = false;
  let copyText = 'Copy';

  function getStatusColor(code) {
    if (code >= 200 && code < 300) return '#49cc90';
    if (code >= 300 && code < 400) return '#e8c438';
    if (code >= 400 && code < 500) return '#fca130';
    return '#f93e3e';
  }

  function isJsonContent(headers) {
    const ct = headers?.['Content-Type'] || '';
    return ct.includes('application/json') || ct.includes('+json');
  }

  function formatBody(body, headers) {
    if (!body) return '';
    if (isJsonContent(headers)) {
      try { return JSON.stringify(JSON.parse(body), null, 4); } catch {}
    }
    return body;
  }

  function syntaxHighlight(json) {
    return json
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/("(\\u[\da-fA-F]{4}|\\[^u]|[^\\"])*"(\s*:)?)/g, (match) =>
        `<span class="${match.endsWith(':') ? 'json-key' : 'json-string'}">${match}</span>`)
      .replace(/\b(true|false)\b/g, '<span class="json-boolean">$1</span>')
      .replace(/\b(null)\b/g, '<span class="json-null">$1</span>')
      .replace(/\b(-?\d+\.?\d*([eE][+-]?\d+)?)\b/g, '<span class="json-number">$1</span>');
  }

  async function copyBody() {
    if (!formattedBody) return;
    await navigator.clipboard.writeText(formattedBody);
    copyText = 'Copied!';
    setTimeout(() => { copyText = 'Copy'; }, 1500);
  }
</script>

<div class="response-panel">
  {#if loading}
    <div class="state-view">
      <div class="spinner"></div>
      <span>Sending request...</span>
    </div>
  {:else if error}
    <div class="state-view error">
      <span class="error-icon">!</span>
      <span>{error}</span>
    </div>
  {:else if response}
    <div class="status-bar">
      <span class="status-code" style="color: {getStatusColor(response.statusCode)}">{response.statusCode}</span>
      <span class="status-text">{response.statusText}</span>
      <span class="status-time">{response.durationMs} ms</span>
    </div>

    <div class="response-toolbar">
      <button class="toolbar-btn" class:active={showHeaders} on:click={() => showHeaders = !showHeaders}>
        Headers ({Object.keys(response.headers).length})
      </button>
      <button class="toolbar-btn copy-btn" on:click={copyBody}>{copyText}</button>
    </div>

    {#if showHeaders}
      <div class="response-headers">
        {#each Object.entries(response.headers) as [key, value]}
          <div class="resp-header-row">
            <span class="resp-header-key">{key}</span>
            <span class="resp-header-value">{value}</span>
          </div>
        {/each}
      </div>
    {/if}

    <div class="response-body">
      {#if isJson}
        <pre>{@html syntaxHighlight(formattedBody)}</pre>
      {:else}
        <pre>{formattedBody}</pre>
      {/if}
    </div>
  {/if}
</div>

<style>
  .response-panel {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
  }
  .status-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 16px;
    background: #1a1a24;
    border-top: 1px solid #2a2a3a;
    border-bottom: 1px solid #2a2a3a;
    flex-shrink: 0;
  }
  .status-code {
    font-weight: 700;
    font-size: 14px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  }
  .status-text { color: #888; font-size: 13px; }
  .status-time {
    margin-left: auto;
    color: #888;
    font-size: 12px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  }
  .response-toolbar {
    display: flex;
    gap: 8px;
    padding: 6px 16px;
    border-bottom: 1px solid #2a2a3a;
    flex-shrink: 0;
  }
  .toolbar-btn {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 4px;
    color: #888;
    padding: 4px 10px;
    font-size: 12px;
    cursor: pointer;
    font-family: inherit;
  }
  .toolbar-btn:hover { color: #ccc; border-color: #3a3a4a; }
  .toolbar-btn.active { color: #e0e0e0; border-color: #7c6fe0; }
  .copy-btn { margin-left: auto; }
  .response-headers {
    padding: 8px 16px;
    border-bottom: 1px solid #2a2a3a;
    max-height: 200px;
    overflow-y: auto;
    flex-shrink: 0;
  }
  .resp-header-row {
    display: flex;
    gap: 12px;
    padding: 3px 0;
    font-size: 12px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  }
  .resp-header-key { color: #7c6fe0; min-width: 180px; }
  .resp-header-value { color: #aaa; word-break: break-all; }
  .response-body {
    flex: 1;
    overflow: auto;
    padding: 12px 16px;
  }
  .response-body pre {
    margin: 0;
    white-space: pre-wrap;
    word-break: break-word;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    line-height: 1.5;
    color: #e0e0e0;
  }
  :global(.json-key) { color: #7c6fe0; }
  :global(.json-string) { color: #49cc90; }
  :global(.json-number) { color: #fca130; }
  :global(.json-boolean) { color: #61affe; }
  :global(.json-null) { color: #888; }
  .state-view {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    flex: 1;
    color: #555;
    font-size: 14px;
  }
  .state-view.error { color: #e06f6f; }
  .error-icon {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    border: 2px solid #e06f6f;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 18px;
  }
  .spinner {
    width: 24px;
    height: 24px;
    border: 3px solid #2a2a3a;
    border-top-color: #7c6fe0;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
