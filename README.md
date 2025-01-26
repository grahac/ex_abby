# ExAbby

**ExAbby** is a minimal A/B testing library for Elixir/Phoenix.  

*Note: This was created with my friends Claude and C. HatGPT. The code is working but not my favorite and feels a bit too spaghetti code and inconsistent for my liking. I plan to continue to refactor/change it as I come across issues.  There are also a ton of optimizations needed.*

It supports:

- Ecto-based storage (Experiments, Variations, Trials)
- Session-based or User-based assignment
- Weighted randomization
- Recording success events
- LiveView helpers (checking `connected?/1` and storing assigned variation)
- Admin LiveViews 
- Upserting experiments/variations with optional weight updates

Coming in the future
- ability to toggle variations by user or session for testing
- armed bandits
- statistical significance
- better UX of admin screens
- So much cleanup
- Likely changes to the API.


---

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Migrations](#migrations)
4. [Usage in Controllers](#usage-in-controllers)
5. [Usage in LiveView](#usage-in-liveview)
6. [Optional Admin Routes](#optional-admin-routes)
7. [Upserting Experiments and Updating Weights](#upserting-experiments-and-updating-weights)
8. [Runtime vs. Compile-Time Repo](#runtime-vs-compile-time-repo)
9. [Troubleshooting](#troubleshooting)

---

## Installation

1. **Add** `ex_abby` as a dependency in your Phoenix (host) app’s `mix.exs`. 

   If it’s a public Hex package (or if you plan to publish it):
   ```elixir
   defp deps do
     [
       {:ex_abby, "~> 0.1.0"}
     ]
   end
   ```
   
   If it’s a **GitHub** repo (private or public):
   ```elixir
   defp deps do
     [
       {:ex_abby, github: "YOUR_USER/ex_abby", tag: "0.1.0"}
     ]
   end
   ```

2. Run:
   ```bash
   mix deps.get
   ```

---

## Configuration

In your host app’s `config/config.exs` (or `dev.exs`, etc.), set:

```elixir
config :ex_abby,
  repo: MyApp.Repo
```

Where `MyApp.Repo` is your **Ecto Repo** module.

---

## Migrations

ExAbby provides Ecto migrations that create three tables:

- `exabby_experiments`
- `exabby_variations`
- `exabby_trials`

In your host app, generate a new migration:

```bash
mix ecto.gen.migration create_ex_abby_tables
```

Open `priv/repo/migrations/2025xxxxxx_create_ex_abby_tables.exs`, and **add**:

```elixir
defmodule MyApp.Repo.Migrations.CreateExAbbyTables do
  use Ecto.Migration

  def up do
    # ExAbby.Migrations is your module that creates the tables
    ExAbby.Migrations.create_tables()
  end

  def down do
    ExAbby.Migrations.drop_tables()
  end
end
```

Then run:

```bash
mix ecto.migrate
```

---
## Usage in Controllers

### Session-based Example

In a controller action (e.g., `PageController`):

```elixir
def index(conn, _params) do
  {conn, variation} = ExAbby.get_variation(conn, "landing_page_test")
  render(conn, "index.html", ab_variation: variation)
end

def record_conversion(conn, _params) do
  ExAbby.record_success(conn, "landing_page_test")
  redirect(conn, to: "/thank_you")
end
```

### User-based Example

If you have a `current_user`:

```elixir
def show(conn, _params) do
  user = conn.assigns.current_user
  variation = ExAbby.get_variation(user, "dashboard_experiment")
  render(conn, "show.html", ab_variation: variation)
end

def record_dashboard_success(conn, _params) do
  ExAbby.record_success(conn.assigns.current_user, "dashboard_experiment")
  redirect(conn, to: "/thanks")
end
```

## Usage in LiveView

1. **Ensure** your endpoint/pipeline sets up a session and calls `ExAbby.SessionPlug` or something similar to create `"ex_abby_session_id"`.
2. In your LiveView:

```elixir
defmodule MyAppWeb.LandingLive do
  use MyAppWeb, :live_view

  def mount(_params, session, socket) do
    # Only assign the variation if the socket is connected
    socket = ExAbby.get_variation(socket, session, "landing_page_test")
    # Optionally store the session for event handlers:
    {:ok, assign(socket, :my_session, session)}
  end

  def render(assigns) do
    ~H"""
    <h2>Landing Page</h2>
    <%= case @ex_abby_trials["landing_page_test"] do %>
      <% "variation_a" -> %>
        <div>Variation A Content</div>
      <% "variation_b" -> %>
        <div>Variation B Content</div>
      <% _ -> %>
        <div>Original Content</div>
    <% end %>
    <button phx-click="convert">Click me</button>
    """
  end

  def handle_event("convert", _params, socket) do
    case ExAbby.record_success(socket, socket.assigns.my_session, "landing_page_test") do
      {:ok, _trial} -> {:noreply, socket}
      {:error, reason} -> 
        IO.inspect(reason, label: "AB Test error")
        {:noreply, socket}
    end
  end
end
```

The variations are stored in `@ex_abby_trials` as a map where:
- Keys are experiment names (e.g., `"landing_page_test"`)
- Values are variation names (e.g., `"original"`, `"variation_a"`)
This makes it easy to pattern match or conditionally render content based on the variation name.

This way, your LiveView handles session-based trials **without** needing a `conn`.

---

## Optional Admin Routes

If you’re using the **admin LiveViews** included in `ex_abby`, add something like:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import ExAbby.Router  

  scope "/admin", MyAppWeb do
    pipe_through [:browser, :admin_auth]

    ex_abby_admin_routes()
  end
end
```

Then navigate to `/admin/ab_tests` to see your experiments in a simple table. You can click on any to view details and edit variation weights.

---

## Upserting Experiments and Updating Weights

If you have a function like:

```elixir
ExAbby.upsert_experiment_and_update_weights(
  "landing_page_test",
  "Testing different landing pages",
  [
    {"Original", 1.0},
    {"Variation A", 1.0},
    {"Variation B", 2.0}
  ]
)
```

Then:

- If `"landing_page_test"` **does not exist**, the library creates a new experiment with that name + description, and 3 variations with the specified weights.  
- If the experiment **already exists**, we do **not** change its description nor create new variations. We **only** update the weight of any existing variation whose name matches. Others get skipped.

---

## Runtime vs. Compile-Time Repo

`ex_abby` uses a **runtime** lookup for the Ecto Repo:

```elixir
defp repo() do
  case Application.get_env(:ex_abby, :repo) do
    nil -> 
      raise "No Ecto repo configured for :ex_abby! Please set config :ex_abby, repo: MyApp.Repo"
    repo_mod -> 
      repo_mod
  end
end
```

All Ecto calls do `repo().insert(...)`, `repo().update(...)`, etc. This approach allows the library to **compile** even if `config :ex_abby, :repo` is not set or is `nil`. At **runtime**, if you call an A/B test function without configuring a real repo, you get a clear error.

---

## Troubleshooting

- **`warning: nil.update(...) is undefined`**  
  This usually indicates a pipeline might receive `nil`. Use an explicit check or `case` before calling `repo().update(...)`.

- **`No Ecto repo configured for :ex_abby`**  
  Add `config :ex_abby, repo: MyApp.Repo` in your host app’s `config.exs`.

- **Double assignment in LiveView**  
  If you see double counts, check whether you’re calling the assignment logic in `mount/3` **before** `connected?(socket)`. You can gate it with `if connected?(socket) do ... end`.

---

**Enjoy A/B testing with ExAbby!** Feel free to customize it further for bandit algorithms, Bayesian stats, or other advanced features.
