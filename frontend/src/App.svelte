<script>
  import { onMount } from 'svelte';
  import { tabStore } from './stores/tabs.js';
  import TabBar from './components/TabBar.svelte';
  import RequestPanel from './components/RequestPanel.svelte';
  import ResponsePanel from './components/ResponsePanel.svelte';

  let splitPercent = 45;
  let dragging = false;
  let workspaceEl;

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

  onMount(() => {
    function handleKeydown(e) {
      const mod = e.metaKey || e.ctrlKey;

      if (mod && e.key === 't') {
        e.preventDefault();
        tabStore.addTab();
      }

      if (mod && e.key === 'w') {
        e.preventDefault();
        const state = getState();
        tabStore.closeTab(state.activeTabId);
      }

      if (mod && e.key === 'l') {
        e.preventDefault();
        const urlInput = document.getElementById('url-input');
        if (urlInput) {
          urlInput.focus();
          urlInput.select();
        }
      }
    }

    function getState() {
      let state;
      const unsub = tabStore.subscribe(s => state = s);
      unsub();
      return state;
    }

    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  });
</script>

<main>
  <TabBar />
  <div class="workspace" bind:this={workspaceEl} class:dragging>
    <div class="pane request-pane" style="height: {splitPercent}%">
      <RequestPanel />
    </div>
    <div class="divider" on:mousedown={onDividerMousedown}>
      <div class="divider-handle"></div>
    </div>
    <div class="pane response-pane" style="height: {100 - splitPercent}%">
      <ResponsePanel />
    </div>
  </div>
</main>

<style>
  :global(*) {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  :global(body) {
    background: #18181e;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    overflow: hidden;
  }
  :global(::selection) {
    background: rgba(124, 111, 224, 0.3);
  }
  :global(::-webkit-scrollbar) {
    width: 6px;
    height: 6px;
  }
  :global(::-webkit-scrollbar-track) {
    background: transparent;
  }
  :global(::-webkit-scrollbar-thumb) {
    background: #2a2a3a;
    border-radius: 3px;
  }
  :global(::-webkit-scrollbar-thumb:hover) {
    background: #3a3a4a;
  }
  main {
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
  }
  .workspace {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
  }
  .workspace.dragging {
    cursor: row-resize;
    user-select: none;
  }
  .pane {
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .divider {
    height: 6px;
    background: #1a1a24;
    border-top: 1px solid #2a2a3a;
    border-bottom: 1px solid #2a2a3a;
    cursor: row-resize;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .divider:hover, .workspace.dragging .divider {
    background: #22222e;
  }
  .divider-handle {
    width: 40px;
    height: 2px;
    background: #3a3a4a;
    border-radius: 1px;
  }
  .divider:hover .divider-handle, .workspace.dragging .divider-handle {
    background: #7c6fe0;
  }
</style>
