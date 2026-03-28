<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import { SearchHistory } from '../../wailsjs/go/main/App.js';

  export let open = false;

  const dispatch = createEventDispatcher();

  let query = '';
  let results = [];

  onMount(() => {
    if (open) load();
  });

  $: if (open) load();

  async function load() {
    try {
      results = await SearchHistory(query) ?? [];
    } catch (e) {
      results = [];
    }
  }

  function onInput() {
    load();
  }

  function select(entry) {
    dispatch('select', entry);
  }

  function formatUrl(url) {
    try {
      const u = new URL(url.startsWith('http') ? url : 'https://' + url);
      return u.host + u.pathname;
    } catch {
      return url;
    }
  }

  function formatTime(ms) {
    const d = new Date(ms);
    const now = new Date();
    const diffDays = Math.floor((now - d) / 86400000);
    if (diffDays === 0) return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return d.toLocaleDateString([], { weekday: 'short' });
    return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  }

  function getMethodColor(method) {
    const colors = {
      GET: '#61affe', POST: '#49cc90', PUT: '#fca130',
      PATCH: '#e8c438', DELETE: '#f93e3e', HEAD: '#9012fe', OPTIONS: '#0d5aa7',
    };
    return colors[method] || '#888';
  }
</script>

<div class="sidebar" class:open>
  {#if open}
    <div class="sidebar-header">
      <span class="sidebar-title">History</span>
      <button class="close-btn" on:click={() => dispatch('close')}>×</button>
    </div>
    <div class="search-bar">
      <input
        class="search-input"
        type="text"
        placeholder="Search..."
        bind:value={query}
        on:input={onInput}
        autofocus
      />
    </div>
    <div class="results">
      {#if results.length === 0}
        <div class="state-msg">{query ? 'No results' : 'No history yet'}</div>
      {:else}
        {#each results as entry (entry.id)}
          <button class="result-row" on:click={() => select(entry)}>
            <span class="method" style="color: {getMethodColor(entry.method)}">{entry.method}</span>
            <span class="url" title={entry.url}>{formatUrl(entry.url)}</span>
            <span class="time">{formatTime(entry.timestamp)}</span>
          </button>
        {/each}
      {/if}
    </div>
  {/if}
</div>

<style>
  .sidebar {
    width: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: #16161f;
    border-right: 1px solid #2a2a3a;
    transition: width 0.2s ease;
    flex-shrink: 0;
  }
  .sidebar.open {
    width: 280px;
  }
  .sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 14px;
    border-bottom: 1px solid #2a2a3a;
    flex-shrink: 0;
  }
  .sidebar-title {
    font-size: 12px;
    font-weight: 600;
    color: #888;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .close-btn {
    background: transparent;
    border: none;
    color: #666;
    font-size: 18px;
    cursor: pointer;
    line-height: 1;
    padding: 0 2px;
  }
  .close-btn:hover { color: #ccc; }
  .search-bar {
    padding: 8px 10px;
    border-bottom: 1px solid #2a2a3a;
    flex-shrink: 0;
  }
  .search-input {
    width: 100%;
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 5px;
    color: #e0e0e0;
    padding: 6px 10px;
    font-size: 13px;
    font-family: inherit;
    outline: none;
  }
  .search-input:focus { border-color: #7c6fe0; }
  .search-input::placeholder { color: #555; }
  .results {
    flex: 1;
    overflow-y: auto;
  }
  .state-msg {
    color: #555;
    font-size: 13px;
    text-align: center;
    padding: 24px 16px;
  }
  .result-row {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 7px 12px;
    background: transparent;
    border: none;
    border-bottom: 1px solid #1e1e2a;
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    min-width: 0;
  }
  .result-row:hover { background: #1e1e2e; }
  .method {
    font-size: 10px;
    font-weight: 700;
    font-family: 'SF Mono', 'Fira Code', monospace;
    flex-shrink: 0;
    width: 44px;
  }
  .url {
    font-size: 12px;
    color: #ccc;
    font-family: 'SF Mono', 'Fira Code', monospace;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
  }
  .time {
    font-size: 10px;
    color: #555;
    flex-shrink: 0;
    white-space: nowrap;
  }
</style>
