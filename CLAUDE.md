# curl-ui

A lightweight desktop HTTP client built with Go + Wails + Svelte. Single binary, no runtime dependencies.

## Design philosophy

- **Simple and minimal** — no unnecessary features or configuration. If it doesn't serve a clear need, it doesn't belong.
- **Small binary** — the entire app is a single native binary using the OS webview. No bundled browser engine (contrast: Postman is 307MB, this is ~14MB).
- **No runtime dependencies** — users download and run. Nothing to install.
- **Transparent storage** — request history is stored in a local SQLite file the user can inspect or delete, not a opaque binary format.

## Development workflow

After making any changes, rebuild and relaunch with:

```bash
make run
```

This builds the binary, cleanly installs it to `/Applications`, kills any running instance, and reopens it. Use this for all iterative development.

Other targets:

```bash
make build   # Build and install to /Applications (no relaunch)
make dev     # Wails dev mode with hot reload (frontend changes only)
make install # Copy last build to /Applications without rebuilding
```

## Structure

```
├── main.go       # Wails entry point
├── app.go        # Wails-exposed methods (SendRequest, CancelRequest, PickFile, SearchHistory)
├── types.go      # Structs and constants (App, RequestPayload, ResponsePayload, BodyType, etc.)
├── utils.go      # Helper functions (isBinaryContent)
├── history.go    # SQLite request history (save, search, schema migration)
└── frontend/
    └── src/
        ├── App.svelte                        # Root layout, keyboard shortcuts, draggable divider
        ├── stores/tabs.js                    # Multi-tab state management
        ├── lib/curlparser.js                 # cURL command parser
        └── components/
            ├── TabBar.svelte
            ├── RequestPanel.svelte
            ├── ResponsePanel.svelte
            ├── HistorySidebar.svelte
            ├── CodeEditor.svelte             # CodeMirror 6 wrapper
            ├── HeadersEditor.svelte
            └── KeyValueEditor.svelte         # Reusable key/value row editor
```

## Releases

Every push to `master` triggers a GitHub Actions build and publishes binaries for macOS (arm64 + amd64), Linux (amd64), and Windows (amd64) to the `latest` release. Work in progress should be on a branch.
