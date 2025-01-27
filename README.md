# ExAbby

**ExAbby** is a minimal A/B testing library for Elixir/Phoenix.  

*Note: This was created with my friends Claude and C. Hat GPT. The code is working but not necessarily something I am proud of yet. It feels a bit too spaghetti code and inconsistent for my liking. Also it is currently non-performant so be careful under load.  I plan to continue to refactor/change it as I come across issues.  There are also a ton of optimizations needed.*

## Why Ex Abby? 
I have found there are no super simple ways to get ab testing working for smaller sites. You have to pay $$ or use a complex system.  And everything has moved to feature tagging. This experiment framework is based on something we built in-house for a consumer company that reached virality co-efficients of 1.0 a few times.  And the goal is to make it super easy to use in Liveview environments. 

This is really early and the API is 100% likely to change. Feedback is appreciated! 

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
4. [Upserting Experiments and Updating Weights](#upserting-experiments-and-updating-weights)
5. [Usage in Controllers](#usage-in-controllers)
6. [Usage in LiveView](#usage-in-liveview)
7. [Optional Admin Routes](#optional-admin-routes)
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
       {:ex_abby, github: "grahac/ex_abby", tag: "0.1.0"}
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
  ],
  success1_label: "Signup",
  success2_label: "Purchase"
)

```


Then:

- If `"landing_page_test"` **does not exist**, the library creates a new experiment with that name + description, and 3 variations with the specified weights.  
- If the experiment **already exists**, we do **not** change its weights. We update all the other info if
- you can optionally add labels to label success. This is just for readability and is optional.
---


## Seeding Experiments

Create a file `priv/repo/seeds/experiments.exs` to define your experiments:

```elixir
experiments = [
  {
    "button_color_test",
    "Testing different button colors for signup",
    [
      {"control", 0.33},
      {"green", 0.33}, 
      {"blue", 0.33}
    ],
    [success1_label: "Signup", success2_label: "Purchase", update_weights: false]
  }
]

# Seed or update experiments without modifying weights
Enum.each(experiments, fn {name, description, variations, opts} ->
  ExAbby.upsert_experiment_and_update_weights(name, description, variations, opts)
end)
```

Then in your `priv/repo/seeds.exs`, add:

```elixir
Code.require_file("seeds/experiments.exs", __DIR__)
```

You can run the seeds in different ways:

### Development:
```bash
mix run priv/repo/seeds.exs
```

## Production Deployment

ExAbby experiments can be seeded automatically during your migration process.

1. **Add Release Module Function**

In `lib/your_app/release.ex`:
```elixir
defmodule YourApp.Release do
  # ... existing release module code ...

  def seed_experiments do
    load_app()
    repo = Application.get_env(:ex_abby, :repo)
    
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo ->
      seed_path = Application.app_dir(@app, "priv/repo/seeds/experiments.exs")
      Code.eval_file(seed_path)
    end)
  end
end
```

2. **Update Migration Script**

Your existing `rel/overlays/bin/migrate` script will now run both migrations and seeds:
```bash
#!/bin/sh

./memoir eval "Memoir.Release.migrate"
./memoir eval "Memoir.Release.seed_experiments"
```

Now your experiments will be automatically seeded whenever you run migrations using:
```bash
bin/migrate
```
This will create or update your experiments while preserving existing weights for any experiments that already exist.
---
## Usage in Controllers

### Session-based Example

In a controller action (e.g., `PageController`):

```elixir
def index(conn, _params) do
  # Single variation example
  {conn, _variation} = ExAbby.get_variation(conn, "landing_page_test")
  
  # Multiple variations example
  {conn, _variations} = ExAbby.get_variations(conn, ["landing_page_test", "button_color_test"])
  render(conn, "index.html")
end

def record_conversion(conn, _params) do
  # Single experiment success recording
  ExAbby.record_success(conn, "landing_page_test")
  
  # Multiple experiment success recording
  ExAbby.record_successes(conn, ["landing_page_test", "button_color_test"])
  
  # Record with options (works for both single and multiple)
  ExAbby.record_successes(conn, ["landing_page_test", "button_color_test"], 
    amount: 99.99,
    success_type: :success1
  )
  
  redirect(conn, to: "/thank_you")
end
```

### User-based Example

If you have a `current_user`:

```elixir
def show(conn, _params) do
  user = conn.assigns.current_user
  
  # Single variation
  variation = ExAbby.get_variation(user, "dashboard_experiment")
  
  # Multiple variations
  variations = ExAbby.get_variations(user, ["dashboard_experiment", "feature_test"])
  render(conn, "show.html", ab_variations: variations)
end

def record_dashboard_success(conn, _params) do
  user = conn.assigns.current_user
  
  # Record multiple successes
  ExAbby.record_successes(user, ["dashboard_experiment", "feature_test"])
  redirect(conn, to: "/thanks")
end
```


## Usage in LiveView

1. **Ensure** your endpoint/pipeline sets up a session and calls `ExAbby.SessionPlug` or something similar to create `"ex_abby_session_id"`.
2. In your LiveView:

```elixir
defmodule MyAppWeb.ButtonTestLive do
  use MyAppWeb, :live_view

  def mount(_params, session, socket) do
    # Get multiple variations at once
    socket = ExAbby.get_variations(socket, session, ["landing_page_test", "button_color_test"])
    {:ok, assign(socket, session: session)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-10 p-6 bg-white rounded-lg shadow-lg">
      <%= case @ex_abby_trials["landing_page_test"] do %>
        <% "hello_world" -> %>
          <div>Hello World!</div>
        <% _ -> %>
          <div>This is the control</div>
      <% end %>

      <button 
        phx-click="convert" 
        class={get_button_class(@ex_abby_trials["button_color_test"])}
      >
        Click Me!
      </button>
    </div>
    """
  end

  def handle_event("convert", _params, socket) do
    case ExAbby.record_successes(socket, ["landing_page_test", "button_color_test"]) do
      {:ok, _trial} ->
        {:noreply, put_flash(socket, :info, "Conversion recorded!")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to record conversion")}
    end
  end

  # Helper function for button styling based on variation
  defp get_button_class("blue"), do: "bg-blue-500 text-white rounded hover:bg-blue-600"
  defp get_button_class("green"), do: "bg-green-500 text-white rounded hover:bg-green-600"
  defp get_button_class(_), do: "bg-gray-500 text-white rounded hover:bg-gray-600"
end
```

The variations are stored in `@ex_abby_trials` as a map where:
- Keys are experiment names (e.g., `"landing_page_test"`)
- Values are variation names (e.g., `"hello_world"`, `"control"`)

### Recording Conversions with Options

You can record conversions with additional options:

```elixir
# Record a conversion with an amount
ExAbby.record_success(socket, "button_color_test",
  amount: 100.0,
  success_type: :success2
)

# Record multiple conversions at once
ExAbby.record_successes(socket, ["landing_page_test", "button_color_test"])
```

Available options:
- `:amount` - Optional numeric value to track with the success (default: 0.0)
- `:success_type` - Type of success to record, either `:success1` or `:success2` (default: `:success1`)

// ... existing code ...

## Optional Admin Routes

ExAbby includes a simple admin interface for viewing and managing experiments. To use it:

1. Add the routes to your router:

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

2. Visit `/admin/ab_tests` to see a clean, Tailwind-styled interface showing:
   - List of all experiments
   - Experiment details and descriptions
   - Quick links to view individual experiments


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

- **`No Ecto repo configured for :ex_abby`**  
  Add `config :ex_abby, repo: MyApp.Repo` in your host app’s `config.exs`.

- **No Experiment Found**  
  If you see a warning for no experiment found, make sure you have seeded the database wtih experiments nd variations.

---

**Enjoy A/B testing with ExAbby!** Feel free to customize it further for bandit algorithms, Bayesian stats, or other advanced features.
