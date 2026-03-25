<script>
  import { tabStore, activeTab } from '../stores/tabs.js';

  $: tab = $activeTab;
  $: headers = tab ? tab.headers : [];

  function updateHeader(index, field, value) {
    const newHeaders = headers.map((h, i) =>
      i === index ? { ...h, [field]: value } : h
    );
    tabStore.updateTab(tab.id, { headers: newHeaders });
  }

  function addHeader() {
    tabStore.updateTab(tab.id, {
      headers: [...headers, { key: '', value: '', enabled: true }],
    });
  }

  function removeHeader(index) {
    if (headers.length === 1) {
      tabStore.updateTab(tab.id, {
        headers: [{ key: '', value: '', enabled: true }],
      });
      return;
    }
    tabStore.updateTab(tab.id, {
      headers: headers.filter((_, i) => i !== index),
    });
  }

  function toggleHeader(index) {
    updateHeader(index, 'enabled', !headers[index].enabled);
  }
</script>

<div class="headers-editor">
  <div class="headers-table">
    <div class="header-row header-labels">
      <span class="header-toggle"></span>
      <span class="header-key">Key</span>
      <span class="header-value">Value</span>
      <span class="header-action"></span>
    </div>
    {#each headers as header, i}
      <div class="header-row" class:disabled={!header.enabled}>
        <label class="header-toggle">
          <input
            type="checkbox"
            checked={header.enabled}
            on:change={() => toggleHeader(i)}
          />
        </label>
        <input
          class="header-key"
          type="text"
          placeholder="Header name"
          value={header.key}
          on:input={(e) => updateHeader(i, 'key', e.target.value)}
        />
        <input
          class="header-value"
          type="text"
          placeholder="Value"
          value={header.value}
          on:input={(e) => updateHeader(i, 'value', e.target.value)}
        />
        <button class="header-remove" on:click={() => removeHeader(i)} title="Remove">&times;</button>
      </div>
    {/each}
  </div>
  <button class="add-header" on:click={addHeader}>+ Add Header</button>
</div>

<style>
  .headers-editor {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .headers-table {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .header-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .header-row.disabled { opacity: 0.5; }
  .header-labels {
    font-size: 11px;
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding-bottom: 4px;
  }
  .header-toggle {
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .header-toggle input[type="checkbox"] {
    accent-color: #7c6fe0;
  }
  .header-key, .header-value {
    flex: 1;
  }
  .header-row input[type="text"] {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 4px;
    color: #e0e0e0;
    padding: 6px 8px;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    outline: none;
  }
  .header-row input[type="text"]:focus {
    border-color: #7c6fe0;
  }
  .header-remove {
    background: transparent;
    border: none;
    color: #666;
    font-size: 16px;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 3px;
    width: 28px;
    flex-shrink: 0;
  }
  .header-remove:hover { color: #e06f6f; background: #2a2a3a; }
  .add-header {
    background: transparent;
    border: 1px dashed #2a2a3a;
    border-radius: 4px;
    color: #666;
    padding: 6px;
    font-size: 12px;
    cursor: pointer;
    font-family: inherit;
  }
  .add-header:hover { border-color: #7c6fe0; color: #7c6fe0; }
</style>
