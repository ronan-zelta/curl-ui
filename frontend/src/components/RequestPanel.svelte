<script>
  import { tabStore, activeTab } from '../stores/tabs.js';
  import { SendRequest, CancelRequest, PickFile } from '../../wailsjs/go/main/App.js';
  import { main } from '../../wailsjs/go/models';
  import { parseCurl } from '../lib/curlparser.js';
  import { getMethodColor } from '../lib/methodColors.js';
  import HeadersEditor from './HeadersEditor.svelte';
  import CodeEditor from './CodeEditor.svelte';
  import KeyValueEditor from './KeyValueEditor.svelte';

  $: tab = $activeTab;
  $: paramCount = tab?.params.filter(p => p.key.trim()).length ?? 0;
  $: headerCount = tab?.headers.filter(h => h.key.trim()).length ?? 0;

  let activeSection = 'params';
  let syncingParams = false;
  let curlCopyText = 'Copy as cURL';

  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'];

  function setUrl(e) {
    const url = e.target.value;
    tabStore.updateTab(tab.id, { url });
    syncParamsFromUrl(url);
  }

  function syncParamsFromUrl(rawUrl) {
    if (syncingParams) return;
    syncingParams = true;
    try {
      const fullUrl = rawUrl.startsWith('http') ? rawUrl : 'https://' + rawUrl;
      const parsed = new URL(fullUrl);
      const params = [];
      parsed.searchParams.forEach((value, key) => params.push({ key, value, enabled: true }));
      tabStore.updateTab(tab.id, { params: params.length ? params : [{ key: '', value: '', enabled: true }] });
    } catch {}
    syncingParams = false;
  }

  function syncUrlFromParams(params) {
    if (syncingParams) return;
    syncingParams = true;
    try {
      const raw = tab.url || '';
      const fullUrl = raw.startsWith('http') ? raw : 'https://' + raw;
      const parsed = new URL(fullUrl);
      [...parsed.searchParams.keys()].forEach(k => parsed.searchParams.delete(k));
      for (const p of params) {
        if (p.enabled && p.key.trim()) parsed.searchParams.append(p.key, p.value);
      }
      let newUrl = parsed.toString();
      if (!raw.startsWith('http')) newUrl = newUrl.replace(/^https?:\/\//, '');
      tabStore.updateTab(tab.id, { url: newUrl, params });
    } catch {
      tabStore.updateTab(tab.id, { params });
    }
    syncingParams = false;
  }

  function handlePaste(e) {
    const text = e.clipboardData.getData('text').trim();
    if (!text.match(/^\s*curl\s/i)) return;
    e.preventDefault();
    const parsed = parseCurl(text);
    if (!parsed) return;
    tabStore.updateTab(tab.id, {
      method: parsed.method,
      url: parsed.url,
      headers: parsed.headers.length > 0
        ? parsed.headers.map(h => ({ ...h, enabled: true }))
        : [{ key: '', value: '', enabled: true }],
      body: parsed.body,
      bodyType: parsed.bodyType,
    });
  }

  async function pickFile() {
    try {
      const path = await PickFile();
      if (path) tabStore.updateTab(tab.id, { binaryPath: path });
    } catch {}
  }

  async function sendRequest() {
    if (!tab || tab.loading) return;
    tabStore.updateTab(tab.id, { loading: true, error: null, response: null });
    try {
      const response = await SendRequest(main.RequestPayload.createFrom({
        method: tab.method,
        url: tab.url,
        headers: tab.headers.filter(h => h.enabled && h.key.trim()).reduce((acc, h) => ({ ...acc, [h.key]: h.value }), {}),
        body: tab.body,
        bodyType: tab.bodyType,
        formData: tab.formData,
        urlEncoded: tab.urlEncoded,
        binaryPath: tab.binaryPath,
      }));
      tabStore.updateTab(tab.id, { response, loading: false });
    } catch (err) {
      tabStore.updateTab(tab.id, { error: typeof err === 'string' ? err : err.message || 'Request failed', loading: false });
    }
  }

  function prettyPrint() {
    if (!tab || tab.bodyType !== 'json' || !tab.body.trim()) return;
    try {
      tabStore.updateTab(tab.id, { body: JSON.stringify(JSON.parse(tab.body), null, 4) });
    } catch {}
  }

  function copyAsCurl() {
    if (!tab) return;
    const url = tab.url.startsWith('http') ? tab.url : 'https://' + tab.url;
    const enabledHeaders = tab.headers.filter(h => h.enabled && h.key.trim());
    const parts = [`curl -X ${tab.method}`];

    for (const h of enabledHeaders) parts.push(`-H '${h.key}: ${h.value}'`);

    if (tab.bodyType === 'json' && tab.body.trim()) {
      if (!enabledHeaders.some(h => h.key.toLowerCase() === 'content-type')) parts.push("-H 'Content-Type: application/json'");
      parts.push(`-d '${tab.body.replace(/'/g, "'\\''")}'`);
    } else if (tab.bodyType === 'raw' && tab.body.trim()) {
      parts.push(`-d '${tab.body.replace(/'/g, "'\\''")}'`);
    } else if (tab.bodyType === 'form-data') {
      for (const kv of tab.formData.filter(f => f.enabled && f.key.trim())) {
        parts.push(`-F '${kv.key}=${kv.value.replace(/'/g, "'\\''")}'`);
      }
    } else if (tab.bodyType === 'urlencoded') {
      const pairs = tab.urlEncoded.filter(f => f.enabled && f.key.trim()).map(kv => `${encodeURIComponent(kv.key)}=${encodeURIComponent(kv.value)}`).join('&');
      if (pairs) {
        if (!enabledHeaders.some(h => h.key.toLowerCase() === 'content-type')) parts.push("-H 'Content-Type: application/x-www-form-urlencoded'");
        parts.push(`-d '${pairs}'`);
      }
    } else if (tab.bodyType === 'binary' && tab.binaryPath) {
      parts.push(`--data-binary '@${tab.binaryPath}'`);
    }

    parts.push(`'${url}'`);
    navigator.clipboard.writeText(parts.join(' \\\n    '));
    curlCopyText = 'Copied!';
    setTimeout(() => { curlCopyText = 'Copy as cURL'; }, 1500);
  }
</script>

{#if tab}
<div class="request-panel">
  <div class="url-bar">
    <select
      class="method-select"
      on:change={(e) => tabStore.updateTab(tab.id, { method: e.currentTarget.value })}
      style="color: {getMethodColor(tab.method)}"
    >
      {#each methods as method}
        <option value={method} selected={method === tab.method} style="color: {getMethodColor(method)}">{method}</option>
      {/each}
    </select>
    <input
      id="url-input"
      class="url-input"
      type="text"
      placeholder="Enter URL..."
      value={tab.url}
      on:input={setUrl}
      on:keydown={(e) => e.key === 'Enter' && (e.metaKey || e.ctrlKey) && sendRequest()}
      on:paste={handlePaste}
    />
    {#if tab.loading}
      <button class="send-btn cancel" on:click={() => { CancelRequest(); tabStore.updateTab(tab.id, { loading: false, error: 'Request cancelled' }); }}>Cancel</button>
    {:else}
      <button class="send-btn" on:click={sendRequest}>Send</button>
    {/if}
  </div>

  <div class="section-tabs">
    <button class="section-tab" class:active={activeSection === 'params'} on:click={() => activeSection = 'params'}>
      Params
      {#if paramCount > 0}<span class="badge">{paramCount}</span>{/if}
    </button>
    <button class="section-tab" class:active={activeSection === 'headers'} on:click={() => activeSection = 'headers'}>
      Headers
      {#if headerCount > 0}<span class="badge">{headerCount}</span>{/if}
    </button>
    <button class="section-tab" class:active={activeSection === 'body'} on:click={() => activeSection = 'body'}>Body</button>
    <div class="section-actions">
      <button class="action-btn" on:click={prettyPrint} title="Format JSON body">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1"/>
          <path d="M16 21h1a2 2 0 0 0 2-2v-5c0-1.1.9-2 2-2a2 2 0 0 1-2-2V5a2 2 0 0 0-2-2h-1"/>
        </svg>
      </button>
      <button class="action-btn" on:click={copyAsCurl} title="Copy request as cURL command">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="m18 16 4-4-4-4"/>
          <path d="m6 8-4 4 4 4"/>
          <path d="m14.5 4-5 16"/>
        </svg>
      </button>
    </div>
  </div>

  {#if activeSection === 'body'}
    <div class="body-type-tabs">
      {#each ['none', 'json', 'raw', 'form-data', 'urlencoded', 'binary'] as type}
        <button class:active={tab.bodyType === type} on:click={() => tabStore.updateTab(tab.id, { bodyType: type })}>
          {type === 'urlencoded' ? 'URL Encoded' : type === 'form-data' ? 'Form Data' : type.charAt(0).toUpperCase() + type.slice(1)}
        </button>
      {/each}
    </div>
  {/if}

  <div class="section-content">
    {#if activeSection === 'params'}
      <KeyValueEditor items={tab.params} keyPlaceholder="Parameter" valuePlaceholder="Value" on:change={(e) => syncUrlFromParams(e.detail)} />
    {:else if activeSection === 'headers'}
      <HeadersEditor />
    {:else if tab.bodyType === 'json'}
      <CodeEditor value={tab.body} lang="json" placeholder={'{"key": "value"}'} on:input={(e) => tabStore.updateTab(tab.id, { body: e.detail })} />
    {:else if tab.bodyType === 'raw'}
      <textarea class="body-textarea" placeholder="Request body..." value={tab.body} on:input={(e) => tabStore.updateTab(tab.id, { body: e.target.value })} spellcheck="false"></textarea>
    {:else if tab.bodyType === 'form-data'}
      <KeyValueEditor items={tab.formData} keyPlaceholder="Key" valuePlaceholder="Value" on:change={(e) => tabStore.updateTab(tab.id, { formData: e.detail })} />
    {:else if tab.bodyType === 'urlencoded'}
      <KeyValueEditor items={tab.urlEncoded} keyPlaceholder="Key" valuePlaceholder="Value" on:change={(e) => tabStore.updateTab(tab.id, { urlEncoded: e.detail })} />
    {:else if tab.bodyType === 'binary'}
      <div class="binary-picker">
        <input class="binary-path" type="text" placeholder="/path/to/file" value={tab.binaryPath} on:input={(e) => tabStore.updateTab(tab.id, { binaryPath: e.target.value })} />
        <button class="binary-browse" on:click={pickFile}>Browse...</button>
      </div>
    {:else}
      <div class="body-empty">This request does not have a body</div>
    {/if}
  </div>
</div>
{/if}

<style>
  .request-panel {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
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
    padding: 8px;
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
  .section-actions {
    margin-left: auto;
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .action-btn {
    background: none;
    border: none;
    border-radius: 4px;
    color: #888;
    padding: 4px 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
  }
  .action-btn:hover { color: #ccc; background: #22222e; }
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
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  .body-type-tabs {
    display: flex;
    gap: 4px;
    padding: 8px 16px;
    border-bottom: 1px solid #2a2a3a;
    flex-shrink: 0;
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
    resize: none;
    flex: 1;
    min-height: 0;
    outline: none;
    line-height: 1.5;
  }
  .body-textarea:focus { border-color: #7c6fe0; }
  .body-textarea::placeholder { color: #444; }
  .binary-picker {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .binary-path {
    flex: 1;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    color: #e0e0e0;
    padding: 8px 12px;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    outline: none;
  }
  .binary-path:focus { border-color: #7c6fe0; }
  .binary-path::placeholder { color: #555; }
  .binary-browse {
    background: #2a2a3a;
    border: 1px solid #3a3a4a;
    border-radius: 6px;
    color: #ccc;
    padding: 8px 16px;
    font-size: 13px;
    cursor: pointer;
    white-space: nowrap;
    font-family: inherit;
  }
  .binary-browse:hover { background: #3a3a4a; border-color: #7c6fe0; }
  .body-empty {
    color: #555;
    font-size: 13px;
    padding: 20px;
    text-align: center;
  }
</style>
