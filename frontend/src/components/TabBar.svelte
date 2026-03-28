<script>
  import { tabStore } from '../stores/tabs.js';

  $: ({ tabs, activeTabId } = $tabStore);

  function getTabTitle(tab) {
    if (!tab.url) return 'New Request';
    try {
      const url = tab.url.startsWith('http') ? tab.url : 'https://' + tab.url;
      return `${tab.method} ${new URL(url).hostname}`;
    } catch {
      return `${tab.method} ${tab.url.substring(0, 20)}`;
    }
  }
</script>

<div class="tab-bar">
  <div class="tabs-scroll">
    {#each tabs as tab (tab.id)}
      {@const title = getTabTitle(tab)}
      <button class="tab" class:active={tab.id === activeTabId} on:click={() => tabStore.setActive(tab.id)} title={title}>
        <span class="tab-title">{title}</span>
        <button class="tab-close" on:click|stopPropagation={() => tabStore.closeTab(tab.id)}>&times;</button>
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
    height: 38px;
    flex-shrink: 0;
  }
  .tabs-scroll {
    display: flex;
    overflow-x: auto;
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
  .tab.active { color: #e0e0e0; background: #24243a; border-bottom: 2px solid #7c6fe0; }
  .tab-title { overflow: hidden; text-overflow: ellipsis; }
  .tab-close {
    background: transparent;
    border: none;
    color: inherit;
    font-size: 18px;
    line-height: 1;
    opacity: 0.4;
    padding: 2px 4px;
    border-radius: 3px;
    cursor: pointer;
    font-family: inherit;
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
