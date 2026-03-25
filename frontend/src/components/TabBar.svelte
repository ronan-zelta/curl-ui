<script>
  import { tabStore } from '../stores/tabs.js';

  $: tabs = $tabStore.tabs;
  $: activeTabId = $tabStore.activeTabId;

  function getTabTitle(tab) {
    if (!tab.url) return 'New Request';
    try {
      const url = tab.url.startsWith('http') ? tab.url : 'https://' + tab.url;
      const hostname = new URL(url).hostname;
      return `${tab.method} ${hostname}`;
    } catch {
      return `${tab.method} ${tab.url.substring(0, 20)}`;
    }
  }
</script>

<div class="tab-bar">
  <div class="tabs-scroll">
    {#each tabs as tab (tab.id)}
      <button
        class="tab"
        class:active={tab.id === activeTabId}
        on:click={() => tabStore.setActive(tab.id)}
        title={getTabTitle(tab)}
      >
        <span class="tab-title">{getTabTitle(tab)}</span>
        <span
          class="tab-close"
          on:click|stopPropagation={() => tabStore.closeTab(tab.id)}
        >&times;</span>
      </button>
    {/each}
  </div>
  <button class="tab-new" on:click={() => tabStore.addTab()} title="New Tab (Cmd+T)">+</button>
</div>

<style>
  .tab-bar {
    display: flex;
    align-items: center;
    background: #1a1a24;
    border-bottom: 1px solid #2a2a3a;
    padding: 0;
    height: 38px;
    flex-shrink: 0;
  }
  .tabs-scroll {
    display: flex;
    overflow-x: auto;
    flex: 1;
    scrollbar-width: none;
  }
  .tabs-scroll::-webkit-scrollbar { display: none; }
  .tab {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0 12px;
    height: 38px;
    background: transparent;
    border: none;
    border-right: 1px solid #2a2a3a;
    color: #888;
    font-size: 12px;
    cursor: pointer;
    white-space: nowrap;
    max-width: 200px;
    flex-shrink: 0;
    font-family: inherit;
  }
  .tab:hover { color: #ccc; background: #22222e; }
  .tab.active {
    color: #e0e0e0;
    background: #24243a;
    border-bottom: 2px solid #7c6fe0;
  }
  .tab-title {
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .tab-close {
    font-size: 14px;
    line-height: 1;
    opacity: 0.4;
    padding: 0 2px;
    border-radius: 3px;
  }
  .tab-close:hover { opacity: 1; background: #3a3a4a; }
  .tab-new {
    background: transparent;
    border: none;
    color: #888;
    font-size: 18px;
    padding: 0 12px;
    height: 38px;
    cursor: pointer;
    flex-shrink: 0;
    font-family: inherit;
  }
  .tab-new:hover { color: #ccc; background: #22222e; }
</style>
