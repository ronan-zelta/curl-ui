import { writable, derived } from 'svelte/store';

let nextId = 1;

function createTab() {
  return {
    id: nextId++,
    method: 'GET',
    url: '',
    headers: [{ key: '', value: '', enabled: true }],
    bodyType: 'none',
    body: '',
    response: null,
    loading: false,
    error: null,
  };
}

function createTabStore() {
  const { subscribe, update, set } = writable({
    tabs: [createTab()],
    activeTabId: 1,
  });

  return {
    subscribe,
    addTab: () => {
      update(state => {
        const tab = createTab();
        return {
          tabs: [...state.tabs, tab],
          activeTabId: tab.id,
        };
      });
    },
    closeTab: (id) => {
      update(state => {
        if (state.tabs.length === 1) {
          const tab = createTab();
          return { tabs: [tab], activeTabId: tab.id };
        }
        const idx = state.tabs.findIndex(t => t.id === id);
        const newTabs = state.tabs.filter(t => t.id !== id);
        let newActiveId = state.activeTabId;
        if (state.activeTabId === id) {
          newActiveId = newTabs[Math.min(idx, newTabs.length - 1)].id;
        }
        return { tabs: newTabs, activeTabId: newActiveId };
      });
    },
    setActive: (id) => {
      update(state => ({ ...state, activeTabId: id }));
    },
    updateTab: (id, changes) => {
      update(state => ({
        ...state,
        tabs: state.tabs.map(t => t.id === id ? { ...t, ...changes } : t),
      }));
    },
  };
}

export const tabStore = createTabStore();

export const activeTab = derived(tabStore, $store =>
  $store.tabs.find(t => t.id === $store.activeTabId)
);
