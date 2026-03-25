<script>
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import { EditorView, keymap, lineNumbers, placeholder as phExtension } from '@codemirror/view';
  import { EditorState } from '@codemirror/state';
  import { indentUnit } from '@codemirror/language';
  import { json } from '@codemirror/lang-json';
  import { basicSetup } from 'codemirror';
  import { oneDark } from '@codemirror/theme-one-dark';

  export let value = '';
  export let placeholder = '';
  export let lang = 'json';

  const dispatch = createEventDispatcher();

  let container;
  let view;
  let updating = false;

  const theme = EditorView.theme({
    '&': {
      fontSize: '13px',
      height: '100%',
    },
    '.cm-content': {
      fontFamily: "'SF Mono', 'Fira Code', 'Cascadia Code', monospace",
      caretColor: '#7c6fe0',
    },
    '.cm-gutters': {
      background: '#1a1a24',
      borderRight: '1px solid #2a2a3a',
      color: '#555',
    },
    '.cm-activeLineGutter': {
      background: '#22222e',
    },
    '&.cm-focused .cm-cursor': {
      borderLeftColor: '#7c6fe0',
    },
    '&.cm-focused .cm-selectionBackground, .cm-selectionBackground': {
      background: 'rgba(124, 111, 224, 0.25) !important',
    },
    '.cm-activeLine': {
      background: 'rgba(124, 111, 224, 0.06)',
    },
    '.cm-scroller': {
      overflow: 'auto',
    },
  });

  onMount(() => {
    const extensions = [
      basicSetup,
      oneDark,
      theme,
      indentUnit.of('    '),
      EditorState.tabSize.of(4),
      lineNumbers(),
      EditorView.updateListener.of((update) => {
        if (update.docChanged && !updating) {
          dispatch('input', update.state.doc.toString());
        }
      }),
    ];

    if (lang === 'json') {
      extensions.push(json());
    }

    if (placeholder) {
      extensions.push(phExtension(placeholder));
    }

    view = new EditorView({
      state: EditorState.create({
        doc: value,
        extensions,
      }),
      parent: container,
    });
  });

  onDestroy(() => {
    if (view) view.destroy();
  });

  $: if (view && value !== view.state.doc.toString()) {
    updating = true;
    view.dispatch({
      changes: {
        from: 0,
        to: view.state.doc.length,
        insert: value,
      },
    });
    updating = false;
  }
</script>

<div class="editor-wrapper" bind:this={container}></div>

<style>
  .editor-wrapper {
    border: 1px solid #2a2a3a;
    border-radius: 6px;
    overflow: hidden;
    min-height: 120px;
    max-height: 250px;
  }
  .editor-wrapper :global(.cm-editor) {
    height: 100%;
    min-height: 120px;
    max-height: 248px;
    background: #1a1a24;
  }
  .editor-wrapper :global(.cm-editor.cm-focused) {
    outline: 1px solid #7c6fe0;
  }
</style>
