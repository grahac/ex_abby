defmodule ExAbby.Live.AdminStyle do
  @moduledoc false

  use Phoenix.Component

  def styles(assigns) do
    ~H"""
    <style>
      .ex-abby-admin {
        --ex-abby-color-signal-blue: #3ba6f1;
        --ex-abby-color-highlight-wash: #c1e1f7;
        --ex-abby-color-canvas-cream: #fafaf9;
        --ex-abby-color-pure-white: #ffffff;
        --ex-abby-color-stone-ink: #0c0a09;
        --ex-abby-color-stone-charcoal: #1c1917;
        --ex-abby-color-warm-slate: #78716c;
        --ex-abby-color-soft-slate: #a8a29e;
        --ex-abby-color-pearl-border: #e5e7eb;
        --ex-abby-color-warm-border: #d6d3d1;

        --ex-abby-color-canvas: #fafaf9;
        --ex-abby-color-surface: #ffffff;
        --ex-abby-color-ink: #0c0a09;
        --ex-abby-color-ink-soft: #525252;
        --ex-abby-color-border: #e5e7eb;
        --ex-abby-color-border-strong: #d4d4d4;
        --ex-abby-color-accent: #2563eb;
        --ex-abby-color-accent-wash: #dbeafe;
        --ex-abby-color-success: #047857;
        --ex-abby-color-success-surface: #ecfdf5;
        --ex-abby-color-warning: #92400e;
        --ex-abby-color-warning-surface: #fef3c7;
        --ex-abby-color-danger: #c81e1e;
        --ex-abby-color-danger-surface: #fde8e8;
        --ex-abby-shadow-subtle: 0 1px 2px rgb(12 10 9 / 0.05);

        min-height: 100%;
        background: var(--ex-abby-color-canvas);
        color: var(--ex-abby-color-ink);
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
          sans-serif;
        font-size: 1rem;
        line-height: 1.5;
      }

      .ex-abby-admin,
      .ex-abby-admin *,
      .ex-abby-admin *::before,
      .ex-abby-admin *::after {
        box-sizing: border-box;
      }

      .ex-abby-admin button,
      .ex-abby-admin input,
      .ex-abby-admin select {
        font: inherit;
      }

      .ex-abby-admin button,
      .ex-abby-admin a,
      .ex-abby-admin input,
      .ex-abby-admin select {
        transition: border-color 150ms ease, background-color 150ms ease, color 150ms ease,
          box-shadow 150ms ease, filter 150ms ease;
      }

      .ex-abby-admin button:focus-visible,
      .ex-abby-admin a:focus-visible,
      .ex-abby-admin input:focus-visible,
      .ex-abby-admin select:focus-visible {
        outline: 2px solid var(--ex-abby-color-stone-charcoal);
        outline-offset: 2px;
        box-shadow: 0 0 0 4px var(--ex-abby-color-accent-wash);
      }

      .ex-abby-admin__shell {
        width: min(100%, 1600px);
        margin: 0 auto;
        padding: 2.5rem 1.5rem 4rem;
      }

      .ex-abby-admin__header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1.5rem;
        margin-bottom: 2rem;
      }

      .ex-abby-admin__title {
        margin: 0;
        color: var(--ex-abby-color-ink);
        font-family: Geist, "General Sans", Inter, ui-sans-serif, system-ui, sans-serif;
        font-size: clamp(1.75rem, 3vw, 2.25rem);
        font-weight: 500;
        letter-spacing: -0.025em;
        line-height: 1.15;
      }

      .ex-abby-admin__subtitle {
        max-width: 48rem;
        margin: 0.5rem 0 0;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.9375rem;
      }

      .ex-abby-panel {
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
        box-shadow: var(--ex-abby-shadow-subtle);
      }

      .ex-abby-button {
        display: inline-flex;
        min-height: 2.5rem;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.625rem 1rem;
        border: 1px solid transparent;
        border-radius: 6px;
        cursor: pointer;
        font-size: 0.875rem;
        font-weight: 500;
        line-height: 1;
        text-decoration: none;
      }

      .ex-abby-button--primary {
        background: var(--ex-abby-color-accent);
        color: var(--ex-abby-color-pure-white);
      }

      .ex-abby-button--primary:hover {
        filter: brightness(0.94);
      }

      .ex-abby-button--secondary {
        background: var(--ex-abby-color-surface);
        border-color: var(--ex-abby-color-border-strong);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-button--secondary:hover {
        background: var(--ex-abby-color-canvas);
        border-color: var(--ex-abby-color-warm-slate);
      }

      .ex-abby-button--danger {
        background: var(--ex-abby-color-surface);
        border-color: var(--ex-abby-color-border-strong);
        color: var(--ex-abby-color-danger);
      }

      .ex-abby-button--danger:hover {
        background: var(--ex-abby-color-danger-surface);
        border-color: var(--ex-abby-color-danger);
      }

      .ex-abby-input,
      .ex-abby-select {
        min-height: 2.5rem;
        padding: 0.5rem 0.75rem;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border-strong);
        border-radius: 6px;
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-input:hover,
      .ex-abby-select:hover {
        border-color: var(--ex-abby-color-warm-slate);
      }

      .ex-abby-label {
        display: block;
        margin-bottom: 0.375rem;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.8125rem;
        font-weight: 500;
      }

      .ex-abby-table-frame {
        overflow-x: auto;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
        box-shadow: var(--ex-abby-shadow-subtle);
      }

      .ex-abby-table {
        width: 100%;
        border-collapse: collapse;
        font-variant-numeric: tabular-nums;
      }

      .ex-abby-table th {
        padding: 0.75rem 1rem;
        background: var(--ex-abby-color-canvas);
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.75rem;
        font-weight: 600;
        letter-spacing: 0.04em;
        line-height: 1.35;
        text-align: left;
        text-transform: uppercase;
        white-space: nowrap;
      }

      .ex-abby-table td {
        padding: 0.875rem 1rem;
        border-top: 1px solid var(--ex-abby-color-border);
        color: var(--ex-abby-color-ink);
        font-size: 0.875rem;
        vertical-align: middle;
      }

      .ex-abby-table tbody tr:hover {
        background: color-mix(
          in srgb,
          var(--ex-abby-color-accent-wash) 28%,
          var(--ex-abby-color-surface)
        );
      }

      .ex-abby-status {
        display: inline-flex;
        align-items: center;
        gap: 0.375rem;
        font-size: 0.8125rem;
        font-weight: 600;
      }

      .ex-abby-status::before {
        width: 0.5rem;
        height: 0.5rem;
        border-radius: 9999px;
        background: currentColor;
        content: "";
      }

      .ex-abby-status--success {
        color: var(--ex-abby-color-success);
      }

      .ex-abby-status--muted {
        color: var(--ex-abby-color-warm-slate);
      }

      .ex-abby-empty-state {
        padding: 2.5rem 1rem;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.875rem;
        text-align: center;
      }

      @media (max-width: 760px) {
        .ex-abby-admin__shell {
          padding: 1.5rem 1rem 3rem;
        }

        .ex-abby-admin__header {
          flex-direction: column;
          margin-bottom: 1.5rem;
        }
      }
    </style>
    """
  end
end
