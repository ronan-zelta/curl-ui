<script>
  export let open = false;

  let sidebarEl;
  let width = 280;
  let dragging = false;

  const MIN = 160;
  const MAX = 480;

  function onHandleMousedown(e) {
    e.preventDefault();
    dragging = true;

    function onMousemove(e) {
      width = Math.max(MIN, Math.min(MAX, e.clientX - sidebarEl.getBoundingClientRect().left));
    }

    function onMouseup() {
      dragging = false;
      window.removeEventListener('mousemove', onMousemove);
      window.removeEventListener('mouseup', onMouseup);
    }

    window.addEventListener('mousemove', onMousemove);
    window.addEventListener('mouseup', onMouseup);
  }
</script>

<div
  class="sidebar"
  class:open
  class:dragging
  style="width: {open ? width : 0}px"
  bind:this={sidebarEl}
>
  {#if open}
    <slot />
    <div class="drag-handle" on:mousedown={onHandleMousedown} />
  {/if}
</div>

<style>
  .sidebar {
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: #16161f;
    border-right: 1px solid #2a2a3a;
    transition: width 0.2s ease;
    flex-shrink: 0;
  }
  .sidebar.dragging {
    transition: none;
  }
  .drag-handle {
    position: absolute;
    top: 0;
    right: 0;
    width: 3px;
    height: 100%;
    cursor: col-resize;
    transition: background 0.1s;
  }
  .drag-handle:hover, .sidebar.dragging .drag-handle {
    background: #7c6fe055;
  }
</style>
