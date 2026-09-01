defmodule ExAbby.Live.AdminStyle do
  @moduledoc false

  use Phoenix.Component

  def styles(assigns) do
    ~H"""
    <style>
      .ex-abby-admin {
        --ex-abby-color-canvas: #f7f6f3;
        --ex-abby-color-surface: #ffffff;
        --ex-abby-color-surface-soft: #fbfaf7;
        --ex-abby-color-surface-hover: #f2f0eb;
        --ex-abby-color-row-leader: #fbfcfb;
        --ex-abby-color-ink: #191a17;
        --ex-abby-color-ink-soft: #57544d;
        --ex-abby-color-ink-muted: #8a867d;
        --ex-abby-color-ink-faint: #b0aca2;
        --ex-abby-color-border: #e4e1da;
        --ex-abby-color-border-soft: #eae7e0;
        --ex-abby-color-border-row: #f0ede7;
        --ex-abby-color-border-strong: #d9d5cc;
        --ex-abby-color-accent: #12664a;
        --ex-abby-color-accent-deep: #0c4a35;
        --ex-abby-color-accent-wash: #e7f1ec;
        --ex-abby-color-accent-border: #c7e0d5;
        --ex-abby-color-success: #12664a;
        --ex-abby-color-success-surface: #e7f1ec;
        --ex-abby-color-warning: #8a6a18;
        --ex-abby-color-warning-accent: #c2a24e;
        --ex-abby-color-warning-surface: #fbf4e3;
        --ex-abby-color-danger: #a33a2a;
        --ex-abby-color-danger-border: #e7c9c2;
        --ex-abby-color-danger-surface: #fcf3f1;
        --ex-abby-color-button: #191a17;
        --ex-abby-color-button-hover: #33352e;
        --ex-abby-color-chart-neutral: #a9a498;
        --ex-abby-font-sans: "Instrument Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
        --ex-abby-font-mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, monospace;

        min-height: 100%;
        padding-bottom: 5rem;
        background: var(--ex-abby-color-canvas);
        color: var(--ex-abby-color-ink);
        font-family: var(--ex-abby-font-sans);
        font-size: 1rem;
        line-height: 1.5;
        -webkit-font-smoothing: antialiased;
      }

      .ex-abby-admin,
      .ex-abby-admin *,
      .ex-abby-admin *::before,
      .ex-abby-admin *::after {
        box-sizing: border-box;
      }

      .ex-abby-admin button {
        font: inherit;
      }

      .ex-abby-admin input,
      .ex-abby-admin select {
        font: inherit;
        font-family: var(--ex-abby-font-mono);
      }

      .ex-abby-admin a {
        color: var(--ex-abby-color-accent);
        text-decoration: none;
      }

      .ex-abby-admin a:hover {
        color: var(--ex-abby-color-accent-deep);
        text-decoration: underline;
      }

      .ex-abby-admin button,
      .ex-abby-admin a,
      .ex-abby-admin input,
      .ex-abby-admin select {
        transition: border-color 150ms ease, background-color 150ms ease, color 150ms ease,
          box-shadow 150ms ease;
      }

      .ex-abby-admin button:focus-visible,
      .ex-abby-admin a:focus-visible,
      .ex-abby-admin input:focus-visible,
      .ex-abby-admin select:focus-visible {
        outline: 2px solid var(--ex-abby-color-ink);
        outline-offset: 2px;
        box-shadow: 0 0 0 4px var(--ex-abby-color-accent-wash);
      }

      .ex-abby-mono {
        font-family: var(--ex-abby-font-mono);
      }

      .ex-abby-topbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 1.5rem;
        padding: 0.875rem 2.5rem;
        background: var(--ex-abby-color-surface);
        border-bottom: 1px solid var(--ex-abby-color-border);
      }

      .ex-abby-topbar__crumbs {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.8125rem;
        font-weight: 500;
      }

      .ex-abby-topbar__crumbs a {
        color: var(--ex-abby-color-ink-soft);
      }

      .ex-abby-topbar__brand {
        color: var(--ex-abby-color-ink);
        font-family: var(--ex-abby-font-mono);
        font-weight: 600;
        letter-spacing: -0.01em;
      }

      .ex-abby-topbar__separator {
        color: var(--ex-abby-color-border-strong);
      }

      .ex-abby-topbar__current {
        color: var(--ex-abby-color-ink);
        font-family: var(--ex-abby-font-mono);
      }

      .ex-abby-topbar__actions {
        display: flex;
        align-items: center;
        gap: 0.625rem;
      }

      .ex-abby-topbar__link {
        padding: 0.4375rem 0.75rem;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.8125rem;
        font-weight: 500;
      }

      .ex-abby-admin__shell {
        width: min(100%, 1320px);
        margin: 0 auto;
        padding: 2rem 2.5rem 0;
      }

      .ex-abby-admin__shell--narrow {
        width: min(100%, 1100px);
      }

      .ex-abby-admin__header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 3rem;
        flex-wrap: wrap;
      }

      .ex-abby-admin__title {
        margin: 0;
        color: var(--ex-abby-color-ink);
        font-size: 1.625rem;
        font-weight: 700;
        letter-spacing: -0.02em;
        line-height: 1.2;
      }

      .ex-abby-admin__subtitle {
        margin: 0.5rem 0 0;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.9375rem;
        line-height: 1.5;
        text-wrap: pretty;
      }

      .ex-abby-eyebrow {
        display: block;
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.6875rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .ex-abby-label {
        display: block;
        margin-bottom: 0.375rem;
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.6875rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .ex-abby-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.375rem;
        padding: 0.25rem 0.625rem;
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 99px;
        font-size: 0.6875rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .ex-abby-pill::before {
        width: 0.375rem;
        height: 0.375rem;
        border-radius: 99px;
        background: currentColor;
        content: "";
      }

      .ex-abby-pill--running {
        background: var(--ex-abby-color-accent-wash);
        border-color: var(--ex-abby-color-accent-border);
        color: var(--ex-abby-color-accent);
      }

      .ex-abby-pill--archived {
        background: var(--ex-abby-color-surface-hover);
        color: var(--ex-abby-color-ink-muted);
      }

      .ex-abby-panel {
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
        overflow: hidden;
      }

      .ex-abby-panel__header {
        display: flex;
        align-items: baseline;
        gap: 0.75rem;
        padding: 1rem 1.25rem;
        border-bottom: 1px solid var(--ex-abby-color-border-soft);
      }

      .ex-abby-panel__title {
        margin: 0;
        font-size: 0.9375rem;
        font-weight: 700;
      }

      .ex-abby-panel__meta {
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.75rem;
      }

      .ex-abby-panel__footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
        padding: 0.875rem 1.25rem;
        background: var(--ex-abby-color-surface-soft);
        border-top: 1px solid var(--ex-abby-color-border);
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.75rem;
        text-wrap: pretty;
      }

      .ex-abby-button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.5625rem 1rem;
        border: 1px solid transparent;
        border-radius: 6px;
        cursor: pointer;
        font-family: var(--ex-abby-font-sans);
        font-size: 0.8125rem;
        font-weight: 600;
        line-height: 1.2;
        text-decoration: none;
      }

      .ex-abby-button:hover {
        text-decoration: none;
      }

      .ex-abby-button--primary {
        background: var(--ex-abby-color-button);
        color: var(--ex-abby-color-surface);
      }

      .ex-abby-button--primary:hover {
        background: var(--ex-abby-color-button-hover);
        color: var(--ex-abby-color-surface);
      }

      .ex-abby-button--secondary {
        background: var(--ex-abby-color-surface);
        border-color: var(--ex-abby-color-border-strong);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-button--secondary:hover {
        background: var(--ex-abby-color-surface-hover);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-button--danger {
        background: var(--ex-abby-color-surface);
        border-color: var(--ex-abby-color-danger-border);
        color: var(--ex-abby-color-danger);
      }

      .ex-abby-button--danger:hover {
        background: var(--ex-abby-color-danger-surface);
        color: var(--ex-abby-color-danger);
      }

      .ex-abby-input,
      .ex-abby-select {
        padding: 0.5625rem 0.6875rem;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border-strong);
        border-radius: 6px;
        color: var(--ex-abby-color-ink);
        font-size: 0.8125rem;
      }

      .ex-abby-input:hover,
      .ex-abby-select:hover {
        border-color: var(--ex-abby-color-ink-muted);
      }

      .ex-abby-input:disabled,
      .ex-abby-select:disabled {
        background: var(--ex-abby-color-canvas);
        color: var(--ex-abby-color-ink-muted);
        cursor: not-allowed;
      }

      .ex-abby-segmented {
        display: flex;
        overflow: hidden;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border-strong);
        border-radius: 6px;
      }

      .ex-abby-segmented button {
        padding: 0.5625rem 0.875rem;
        background: var(--ex-abby-color-surface);
        border: none;
        border-left: 1px solid var(--ex-abby-color-border);
        color: var(--ex-abby-color-ink-soft);
        cursor: pointer;
        font-size: 0.8125rem;
        font-weight: 500;
      }

      .ex-abby-segmented button:first-child {
        border-left: none;
      }

      .ex-abby-segmented button:hover {
        background: var(--ex-abby-color-surface-hover);
      }

      .ex-abby-segmented button.active {
        background: var(--ex-abby-color-button);
        color: var(--ex-abby-color-surface);
        font-weight: 600;
      }

      .ex-abby-table-frame {
        overflow-x: auto;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
      }

      .ex-abby-table {
        width: 100%;
        border-collapse: separate;
        border-spacing: 0;
        font-variant-numeric: tabular-nums;
      }

      .ex-abby-table th {
        padding: 0.6875rem 1.25rem;
        border-bottom: 1px solid var(--ex-abby-color-border-soft);
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.6875rem;
        font-weight: 600;
        letter-spacing: 0.06em;
        line-height: 1.35;
        text-align: left;
        text-transform: uppercase;
        white-space: nowrap;
      }

      .ex-abby-table td {
        padding: 0.8125rem 1.25rem;
        border-bottom: 1px solid var(--ex-abby-color-border-row);
        color: var(--ex-abby-color-ink);
        font-size: 0.8125rem;
        vertical-align: middle;
      }

      .ex-abby-table tbody tr:last-child td {
        border-bottom: none;
      }

      .ex-abby-table .ex-abby-num {
        font-family: var(--ex-abby-font-mono);
        text-align: right;
        white-space: nowrap;
      }

      .ex-abby-table .ex-abby-muted {
        color: var(--ex-abby-color-ink-muted);
      }

      .ex-abby-table .ex-abby-faint {
        color: var(--ex-abby-color-ink-faint);
      }

      .ex-abby-table .ex-abby-significant {
        color: var(--ex-abby-color-accent-deep);
        font-weight: 700;
      }

      .ex-abby-table tr.ex-abby-row--leader {
        background: var(--ex-abby-color-row-leader);
      }

      .ex-abby-table tr.ex-abby-row--leader td:first-child,
      .ex-abby-table tr.ex-abby-row--significant td:first-child {
        box-shadow: inset 3px 0 0 var(--ex-abby-color-accent);
      }

      .ex-abby-table tr.ex-abby-row--warning td:first-child {
        box-shadow: inset 3px 0 0 var(--ex-abby-color-warning-accent);
      }

      .ex-abby-lift {
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 0.625rem;
      }

      .ex-abby-lift--start {
        justify-content: flex-start;
      }

      .ex-abby-lift__chart {
        flex: none;
      }

      .ex-abby-lift__zero {
        stroke: var(--ex-abby-color-border-strong);
        stroke-width: 1;
      }

      .ex-abby-lift__range {
        stroke: var(--ex-abby-color-chart-neutral);
        stroke-width: 2.5;
        stroke-linecap: round;
      }

      .ex-abby-lift__point {
        fill: var(--ex-abby-color-ink-soft);
      }

      .ex-abby-lift__chart--significant .ex-abby-lift__range {
        stroke: var(--ex-abby-color-accent);
      }

      .ex-abby-lift__chart--significant .ex-abby-lift__point {
        fill: var(--ex-abby-color-accent);
      }

      .ex-abby-lift__label {
        color: var(--ex-abby-color-ink-soft);
        font-family: var(--ex-abby-font-mono);
        font-size: 0.75rem;
        text-align: right;
        white-space: nowrap;
      }

      .ex-abby-lift__label--significant {
        color: var(--ex-abby-color-accent-deep);
        font-weight: 600;
      }

      .ex-abby-empty-state {
        padding: 2.5rem 1rem;
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.875rem;
        text-align: center;
      }

      @media (max-width: 760px) {
        .ex-abby-topbar {
          padding: 0.875rem 1rem;
        }

        .ex-abby-admin__shell {
          padding: 1.5rem 1rem 0;
        }

        .ex-abby-admin__header {
          flex-direction: column;
          gap: 1.5rem;
        }
      }
    </style>
    """
  end
end
