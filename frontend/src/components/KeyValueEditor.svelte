<script>
  import { createEventDispatcher } from 'svelte';

  export let items = [];
  export let keyPlaceholder = 'Key';
  export let valuePlaceholder = 'Value';

  const dispatch = createEventDispatcher();

  function update(index, field, value) {
    const updated = items.map((item, i) =>
      i === index ? { ...item, [field]: value } : item
    );
    dispatch('change', updated);
  }

  function add() {
    dispatch('change', [...items, { key: '', value: '', enabled: true }]);
  }

  function remove(index) {
    if (items.length === 1) {
      dispatch('change', [{ key: '', value: '', enabled: true }]);
      return;
    }
    dispatch('change', items.filter((_, i) => i !== index));
  }

  function toggle(index) {
    update(index, 'enabled', !items[index].enabled);
  }
</script>

<div class="kv-editor">
  <div class="kv-table">
    <div class="kv-row kv-labels">
      <span class="kv-toggle"></span>
      <span class="kv-key">{keyPlaceholder}</span>
      <span class="kv-value">{valuePlaceholder}</span>
      <span class="kv-action"></span>
    </div>
    {#each items as item, i}
      <div class="kv-row" class:disabled={!item.enabled}>
        <label class="kv-toggle">
          <input type="checkbox" checked={item.enabled} on:change={() => toggle(i)} />
        </label>
        <input
          class="kv-key"
          type="text"
          placeholder={keyPlaceholder}
          value={item.key}
          on:input={(e) => update(i, 'key', e.target.value)}
        />
        <input
          class="kv-value"
          type="text"
          placeholder={valuePlaceholder}
          value={item.value}
          on:input={(e) => update(i, 'value', e.target.value)}
        />
        <button class="kv-remove" on:click={() => remove(i)}>&times;</button>
      </div>
    {/each}
  </div>
  <button class="kv-add" on:click={add}>+ Add Row</button>
</div>

<style>
  .kv-editor {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .kv-table {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .kv-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .kv-row.disabled { opacity: 0.5; }
  .kv-labels {
    font-size: 11px;
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding-bottom: 4px;
  }
  .kv-toggle {
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .kv-toggle input[type="checkbox"] {
    accent-color: #7c6fe0;
  }
  .kv-key, .kv-value { flex: 1; }
  .kv-row input[type="text"] {
    background: #1a1a24;
    border: 1px solid #2a2a3a;
    border-radius: 4px;
    color: #e0e0e0;
    padding: 6px 8px;
    font-size: 13px;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    outline: none;
  }
  .kv-row input[type="text"]:focus { border-color: #7c6fe0; }
  .kv-remove {
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
  .kv-remove:hover { color: #e06f6f; background: #2a2a3a; }
  .kv-add {
    background: transparent;
    border: 1px dashed #2a2a3a;
    border-radius: 4px;
    color: #666;
    padding: 6px;
    font-size: 12px;
    cursor: pointer;
    font-family: inherit;
  }
  .kv-add:hover { border-color: #7c6fe0; color: #7c6fe0; }
</style>
