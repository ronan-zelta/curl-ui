<script>
  import { onMount } from 'svelte';
  import { tabStore } from './stores/tabs.js';
  import TabBar from './components/TabBar.svelte';
  import RequestPanel from './components/RequestPanel.svelte';
  import ResponsePanel from './components/ResponsePanel.svelte';
  import Sidebar from './components/Sidebar.svelte';
  import HistorySidebar from './components/HistorySidebar.svelte';

  let splitPercent = 45;
  let dragging = false;
  let workspaceEl;
  let historyOpen = false;

  function onDividerMousedown(e) {
    e.preventDefault();
    dragging = true;

    function onMousemove(e) {
      if (!workspaceEl) return;
      const rect = workspaceEl.getBoundingClientRect();
      const y = e.clientY - rect.top;
      const pct = (y / rect.height) * 100;
      splitPercent = Math.max(15, Math.min(85, pct));
    }

    function onMouseup() {
      dragging = false;
      window.removeEventListener('mousemove', onMousemove);
      window.removeEventListener('mouseup', onMouseup);
    }

    window.addEventListener('mousemove', onMousemove);
    window.addEventListener('mouseup', onMouseup);
  }

  function loadHistoryEntry(e) {
    const entry = e.detail;
    let headers = [{ key: '', value: '', enabled: true }];
    try {
      const parsed = JSON.parse(entry.headers);
      if (parsed && typeof parsed === 'object') {
        const rows = Object.entries(parsed).map(([key, value]) => ({ key, value, enabled: true }));
        if (rows.length > 0) headers = rows;
      }
    } catch {}

    let params = [{ key: '', value: '', enabled: true }];
    try {
      const parsed = JSON.parse(entry.params);
      if (Array.isArray(parsed) && parsed.length > 0) params = parsed;
    } catch {}

    let state;
    const unsub = tabStore.subscribe(s => state = s);
    unsub();

    tabStore.updateTab(state.activeTabId, {
      method: entry.method,
      url: entry.url,
      headers,
      params,
      body: entry.body || '',
      bodyType: entry.bodyType || 'none',
    });

    historyOpen = false;
  }

  onMount(() => {
    function handleKeydown(e) {
      const mod = e.metaKey || e.ctrlKey;
      if (mod && e.key === 't') { e.preventDefault(); tabStore.addTab(); }
      if (mod && e.key === 'w') {
        e.preventDefault();
        let state;
        const unsub = tabStore.subscribe(s => state = s);
        unsub();
        tabStore.closeTab(state.activeTabId);
      }
      if (mod && e.key === 'l') {
        e.preventDefault();
        const urlInput = document.getElementById('url-input');
        if (urlInput) { urlInput.focus(); urlInput.select(); }
      }
    }
    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  });
</script>

<main>
  <TabBar />
  <div class="body">
    <div class="icon-strip">
      <button
        class="strip-btn"
        class:active={historyOpen}
        on:click={() => historyOpen = !historyOpen}
        title="History"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/>
          <polyline points="12 6 12 12 16 14"/>
        </svg>
      </button>
    </div>

    <Sidebar open={historyOpen}>
      <HistorySidebar on:select={loadHistoryEntry} />
    </Sidebar>

    <div class="workspace" bind:this={workspaceEl} class:dragging>
      <div class="pane" style="height: {splitPercent}%">
        <RequestPanel />
      </div>
      <div class="divider" on:mousedown={onDividerMousedown}>
        <div class="divider-handle"></div>
      </div>
      <div class="pane" style="height: {100 - splitPercent}%">
        <ResponsePanel />
      </div>
    </div>
  </div>
</main>

<style>
  :global(*) { margin: 0; padding: 0; box-sizing: border-box; }
  :global(body) {
    background: #18181e;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    overflow: hidden;
  }
  :global(::selection) { background: rgba(124, 111, 224, 0.3); }
  :global(::-webkit-scrollbar) { width: 6px; height: 6px; }
  :global(::-webkit-scrollbar-track) { background: transparent; }
  :global(::-webkit-scrollbar-thumb) { background: #2a2a3a; border-radius: 3px; }
  :global(::-webkit-scrollbar-thumb:hover) { background: #3a3a4a; }

  main {
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
  }
  .body {
    display: flex;
    flex: 1;
    overflow: hidden;
  }
  .icon-strip {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 8px 0;
    background: #16161f;
    border-right: 1px solid #2a2a3a;
    width: 40px;
    flex-shrink: 0;
    gap: 4px;
  }
  .strip-btn {
    background: transparent;
    border: none;
    color: #555;
    cursor: pointer;
    padding: 7px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .strip-btn:hover { color: #ccc; background: #22222e; }
  .strip-btn.active { color: #7c6fe0; background: #22222e; }
  .workspace {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
  }
  .workspace.dragging { cursor: row-resize; user-select: none; }
  .pane { display: flex; flex-direction: column; overflow: hidden; }
  .divider {
    height: 3px;
    background: #2a2a3a;
    cursor: row-resize;
    flex-shrink: 0;
    transition: background 0.1s;
  }
  .divider:hover, .workspace.dragging .divider { background: #7c6fe055; }
  .divider-handle { display: none; }
</style>
