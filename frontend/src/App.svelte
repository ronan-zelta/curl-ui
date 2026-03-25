<script>
  import { onMount } from 'svelte';
  import { tabStore } from './stores/tabs.js';
  import TabBar from './components/TabBar.svelte';
  import RequestPanel from './components/RequestPanel.svelte';
  import ResponsePanel from './components/ResponsePanel.svelte';

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
  <div class="workspace">
    <RequestPanel />
    <ResponsePanel />
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
</style>
