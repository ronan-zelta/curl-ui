<script>
  import { activeTab } from '../stores/tabs.js';
  import BodyViewer from './BodyViewer.svelte';

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
      <button class="toolbar-btn copy-btn" on:click={copyBody} title="Copy response body">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <rect width="14" height="14" x="8" y="8" rx="2" ry="2"/>
          <path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>
        </svg>
      </button>
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

    <div class="response-body" class:is-editor={isJson}>
      {#if isJson}
        <BodyViewer value={formattedBody} lang="json" readonly={true} />
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
  .toolbar-btn:hover { color: #ccc; background: #22222e; }
  .toolbar-btn.active { color: #e0e0e0; border-color: #7c6fe0; }
  .copy-btn { margin-left: auto; background: none; border: none; padding: 4px 6px; display: flex; align-items: center; }
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
    min-height: 0;
  }
  .response-body.is-editor {
    display: flex;
    flex-direction: column;
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
