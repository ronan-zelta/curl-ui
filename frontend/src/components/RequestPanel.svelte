<script>
  import { tabStore, activeTab } from '../stores/tabs.js';
  import { SendRequest, CancelRequest } from '../../wailsjs/go/main/App.js';
  import HeadersEditor from './HeadersEditor.svelte';

  $: tab = $activeTab;

  let activeSection = 'headers';

  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'];

  function setMethod(method) {
    tabStore.updateTab(tab.id, { method });
  }

  function setUrl(e) {
    tabStore.updateTab(tab.id, { url: e.target.value });
  }

  function setBodyType(type) {
    tabStore.updateTab(tab.id, { bodyType: type });
  }

  function setBody(e) {
    tabStore.updateTab(tab.id, { body: e.target.value });
  }

  async function sendRequest() {
    if (!tab || tab.loading) return;

    const enabledHeaders = tab.headers
      .filter(h => h.enabled && h.key.trim())
      .reduce((acc, h) => ({ ...acc, [h.key]: h.value }), {});

    const payload = {
      method: tab.method,
      url: tab.url,
      headers: enabledHeaders,
      body: tab.bodyType !== 'none' ? tab.body : '',
      bodyType: tab.bodyType,
    };

    tabStore.updateTab(tab.id, { loading: true, error: null, response: null });

    try {
      const response = await SendRequest(payload);
      tabStore.updateTab(tab.id, { response, loading: false });
    } catch (err) {
      tabStore.updateTab(tab.id, {
        error: typeof err === 'string' ? err : err.message || 'Request failed',
        loading: false,
      });
    }
  }

  function cancelRequest() {
    CancelRequest();
    tabStore.updateTab(tab.id, { loading: false, error: 'Request cancelled' });
  }

  function handleUrlKeydown(e) {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      sendRequest();
    }
  }

  function getMethodColor(method) {
    const colors = {
      GET: '#61affe',
      POST: '#49cc90',
      PUT: '#fca130',
      PATCH: '#e8c438',
      DELETE: '#f93e3e',
      HEAD: '#9012fe',
      OPTIONS: '#0d5aa7',
    };
    return colors[method] || '#888';
  }
</script>

{#if tab}
<div class="request-panel">
  <div class="url-bar">
    <select
      class="method-select"
      value={tab.method}
      on:change={(e) => setMethod(e.target.value)}
      style="color: {getMethodColor(tab.method)}"
    >
      {#each methods as method}
        <option value={method} style="color: {getMethodColor(method)}">{method}</option>
      {/each}
    </select>
    <input
      id="url-input"
      class="url-input"
      type="text"
      placeholder="Enter URL..."
      value={tab.url}
      on:input={setUrl}
      on:keydown={handleUrlKeydown}
    />
    {#if tab.loading}
      <button class="send-btn cancel" on:click={cancelRequest}>Cancel</button>
    {:else}
      <button class="send-btn" on:click={sendRequest}>Send</button>
    {/if}
  </div>

  <div class="section-tabs">
    <button
      class="section-tab"
      class:active={activeSection === 'headers'}
      on:click={() => activeSection = 'headers'}
    >
      Headers
      {#if tab.headers.filter(h => h.key.trim()).length > 0}
        <span class="badge">{tab.headers.filter(h => h.key.trim()).length}</span>
      {/if}
    </button>
    <button
      class="section-tab"
      class:active={activeSection === 'body'}
      on:click={() => activeSection = 'body'}
    >Body</button>
  </div>

  <div class="section-content">
    {#if activeSection === 'headers'}
      <HeadersEditor />
    {:else}
      <div class="body-editor">
        <div class="body-type-tabs">
          <button class:active={tab.bodyType === 'none'} on:click={() => setBodyType('none')}>None</button>
          <button class:active={tab.bodyType === 'json'} on:click={() => setBodyType('json')}>JSON</button>
          <button class:active={tab.bodyType === 'raw'} on:click={() => setBodyType('raw')}>Raw</button>
        </div>
        {#if tab.bodyType !== 'none'}
          <textarea
            class="body-textarea"
            placeholder={tab.bodyType === 'json' ? '{\n  "key": "value"\n}' : 'Request body...'}
            value={tab.body}
            on:input={setBody}
            spellcheck="false"
          ></textarea>
        {:else}
          <div class="body-empty">This request does not have a body</div>
        {/if}
      </div>
    {/if}
  </div>
</div>
{/if}

<style>
  .request-panel {
    display: flex;
    flex-direction: column;
    gap: 0;
    flex-shrink: 0;
  }
  .url-bar {
    display: flex;
    gap: 8px;
    padding: 12px 16px;
    align-items: center;
  }
  .method-select {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    color: #61affe;
    padding: 8px 8px;
    font-size: 13px;
    font-weight: 700;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    cursor: pointer;
    outline: none;
    min-width: 100px;
  }
  .method-select:focus { border-color: #7c6fe0; }
  .method-select option { background: #1a1a24; }
  .url-input {
    flex: 1;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    color: #e0e0e0;
    padding: 8px 12px;
    font-size: 14px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    outline: none;
  }
  .url-input:focus { border-color: #7c6fe0; }
  .url-input::placeholder { color: #555; }
  .send-btn {
    background: #7c6fe0;
    border: none;
    border-radius: 6px;
    color: #fff;
    padding: 8px 20px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    font-family: inherit;
  }
  .send-btn:hover { background: #6b5ed4; }
  .send-btn.cancel { background: #e06f6f; }
  .send-btn.cancel:hover { background: #d05555; }
  .section-tabs {
    display: flex;
    border-bottom: 1px solid #2a2a3a;
    padding: 0 16px;
  }
  .section-tab {
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    color: #888;
    padding: 8px 16px;
    font-size: 13px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 6px;
    font-family: inherit;
  }
  .section-tab:hover { color: #ccc; }
  .section-tab.active { color: #e0e0e0; border-bottom-color: #7c6fe0; }
  .badge {
    background: #7c6fe0;
    color: #fff;
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 10px;
  }
  .section-content {
    padding: 12px 16px;
    overflow-y: auto;
    max-height: 250px;
  }
  .body-editor {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .body-type-tabs {
    display: flex;
    gap: 4px;
  }
  .body-type-tabs button {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 4px;
    color: #888;
    padding: 4px 12px;
    font-size: 12px;
    cursor: pointer;
    font-family: inherit;
  }
  .body-type-tabs button:hover { color: #ccc; }
  .body-type-tabs button.active {
    background: #7c6fe0;
    border-color: #7c6fe0;
    color: #fff;
  }
  .body-textarea {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    color: #e0e0e0;
    padding: 10px 12px;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    resize: vertical;
    min-height: 120px;
    outline: none;
    line-height: 1.5;
    tab-size: 2;
  }
  .body-textarea:focus { border-color: #7c6fe0; }
  .body-textarea::placeholder { color: #444; }
  .body-empty {
    color: #555;
    font-size: 13px;
    padding: 20px;
    text-align: center;
  }
</style>
