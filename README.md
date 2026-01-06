# ExAbby

**ExAbby** is a minimal A/B testing library for Elixir/Phoenix.  

*Caveat: This was created primarily over a weekend with the help of Chat GPT/Claude. The code is working but still needs a lot of cleanup and optimizations, which I'll do as I run into problems.   As it stands, it is working under low load in production settings providing a super easy way to AB test Phoenix and Liveview using assigns.*


## Why Ex Abby? 
I have found there are no super simple ways to get ab testing working for smaller sites in Elixir. You have to pay $$ or use a complex system.  And everything has moved to feature tagging. This experiment framework is based on something we built in-house for a previous company that reached virality co-efficients of 1.0 a few times.  And the goal is to make it super easy to use in Liveview environments. 

This is really early and the API is 100% likely to change. Feedback is appreciated! 

It supports:

- Ecto-based storage (Experiments, Variations, Trials)
- Session-based or User-based assignment
- **Linking session trials to users** - Track user performance from session-based experiments
- **Archive experiments** with optional winner declaration
- Flexible ID support: structs, integers, or strings
- Weighted randomization
- Recording success events
- LiveView helpers (checking `connected?/1` and storing assigned variation)
- Admin LiveViews with experiment filtering (Active/Archived/All)
- Upserting experiments/variations with optional weight updates
- Reviewing results over different time periods
- Ability to toggle variations by user or session for testing

Coming in the future
- armed bandits
- optimizations / caching
- statistical significance
- better UX of admin screens
- So much cleanup
- Likely changes to the API.


---

## Table of Contents
1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Migrations](#migrations)
4. [Upgrading from v0.1 to v0.2](#upgrading-from-v01-to-v02)
5. [Upserting Experiments and Updating Weights](#upserting-experiments-and-updating-weights)
6. [Session Setup](#session-setup)
7. [Admin Routes](#admin-routes)
8. [Usage in Controllers](#usage-in-controllers)
9. [Usage in LiveView](#usage-in-liveview)
10. [Linking Sessions to Users](#linking-sessions-to-users)
11. [Archiving Experiments](#archiving-experiments)
12. [Production Deployment](#production-deployment)
13. [Troubleshooting](#troubleshooting)

---

## Installation

1. **Add** `ex_abby` as a dependency in your Phoenix (host) app’s `mix.exs`. 

   If it's a public Hex package (or if you plan to publish it):
   ```elixir
   defp deps do
     [
       {:ex_abby, "~> 0.2.0"}
     ]
   end
   ```

   If it's a **GitHub** repo (private or public):
   ```elixir
   defp deps do
     [
       {:ex_abby, github: "grahac/ex_abby", tag: "0.2.0"}
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

- `ex_abby_experiments`
- `ex_abby_variations`
- `ex_abby_trials`

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

---

## Upgrading from v0.1 to v0.2

Version 0.2.0 adds experiment archiving with optional winner declaration. To upgrade:

1. **Update your dependency** in `mix.exs`:
```elixir
{:ex_abby, "~> 0.2.0"}
```

2. **Create a new migration**:
```bash
mix ecto.gen.migration ex_abby_v2
```

3. **Add to the generated migration file**:
```elixir
defmodule MyApp.Repo.Migrations.ExAbbyV2 do
  use Ecto.Migration

  def up, do: ExAbby.Migrations.v1_to_v2()
  def down, do: ExAbby.Migrations.v2_to_v1()
end
```

4. **Run the migration**:
```bash
mix ecto.migrate
```

This adds two new columns to `ex_abby_experiments`:
- `archived_at` - Timestamp when experiment was archived
- `winner_variation_id` - Reference to the winning variation (optional)

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

---
### Session Setup

To enable session-based A/B testing, add `ExAbby.SessionPlug` to your endpoint or router pipeline:


```elixir
# In  your router pipeline (recommended):

pipeline :browser do
  # ... other plugs ...
  plug ExAbby.SessionPlug
end

# In lib/your_app_web/endpoint.ex
plug Plug.Session,
  store: :cookie,
  key: "_your_app_key",
  signing_salt: "your_signing_salt"

plug ExAbby.SessionPlug

```


This plug creates a unique `"ex_abby_session_id"` for tracking A/B test variations across requests.
---


## Admin Routes

ExAbby includes a simple admin interface for viewing and managing experiments. To use it:

1. Add the routes to your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import ExAbby.Router  # add this line 

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

## Usage in Controllers

ExAbby supports multiple ways to identify users and sessions:

- **Plug.Conn** - For session-based experiments in controllers
- **Phoenix.LiveView.Socket** - For session-based experiments in LiveView
- **User struct** - Any struct/map with an `id` field (e.g., `%{id: 123}`)
- **Integer ID** - Pass user ID directly (e.g., `123`)
- **String ID** - Pass session ID directly (e.g., `"session_abc123"`)

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

### Direct ID Usage

ExAbby now supports passing IDs directly without wrapping in a struct:

```elixir
# Using integer user IDs directly
user_id = 12345
variation = ExAbby.get_variation(user_id, "experiment_name")
variations = ExAbby.get_variations(user_id, ["exp1", "exp2"])

# Record success with user ID
ExAbby.record_success(user_id, "experiment_name")
ExAbby.record_successes(user_id, ["exp1", "exp2"], amount: 99.99)

# Using session IDs directly (strings)
session_id = "abc123xyz"
variation = ExAbby.get_variation(session_id, "experiment_name")
variations = ExAbby.get_variations(session_id, ["exp1", "exp2"])

# Record success with session ID
ExAbby.record_success(session_id, "experiment_name")
ExAbby.record_successes(session_id, ["exp1", "exp2"], success_type: :success2)
```

This is useful when:
- You only have the user ID (not the full user struct)
- You're working with session IDs from external systems
- You want to run A/B tests in background jobs or processes without full context


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

---

## Linking Sessions to Users

When a user signs up or logs in, you can link their session-based experiment trials to their user account. This allows you to track how users who signed up through different experiment variations perform over time.

### Why Link Sessions to Users?

Session-based experiments are great for testing landing pages and signup flows. But once a user creates an account, you want to track their long-term behavior (purchases, engagement, retention) tied to the original experiment variation they saw.

### Usage

**In Controllers (Plug.Conn):**
```elixir
def create(conn, %{"user" => user_params}) do
  case Accounts.create_user(user_params) do
    {:ok, user} ->
      # Link all session experiments to the new user
      conn = ExAbby.link_session_to_user(conn, user)

      # Or link specific experiments only
      conn = ExAbby.link_session_to_user(conn, user, ["signup_flow_test", "landing_page_test"])

      conn
      |> put_flash(:info, "Account created!")
      |> redirect(to: "/dashboard")

    {:error, changeset} ->
      render(conn, "new.html", changeset: changeset)
  end
end
```

**In LiveView:**
```elixir
def handle_event("register", %{"user" => user_params}, socket) do
  case Accounts.create_user(user_params) do
    {:ok, user} ->
      # Link all session experiments to the new user
      socket = ExAbby.link_session_to_user(socket, user)

      # Or link specific experiments
      socket = ExAbby.link_session_to_user(socket, user, ["signup_flow_test"])

      {:noreply, push_navigate(socket, to: "/dashboard")}

    {:error, changeset} ->
      {:noreply, assign(socket, changeset: changeset)}
  end
end
```

### Flexible User Identification

You can pass the user in different ways:
```elixir
# Pass user struct (must have :id field)
ExAbby.link_session_to_user(conn, user)

# Pass user ID directly
ExAbby.link_session_to_user(conn, 12345)
```

### What Happens When You Link

1. The session trial's `user_id` field is updated to the provided user ID
2. Future success recordings for that user will be associated with the original variation
3. You can now analyze user-based metrics (lifetime value, retention) by experiment variation

---

## Archiving Experiments

Once an experiment has concluded and you've determined a winner (or decided to end it), you can archive it. Archived experiments:

- **Stop accepting new trials** - New users won't be assigned to the experiment
- **Preserve existing data** - All historical trials and conversions remain
- **Can declare a winner** - Optionally mark which variation won
- **Are hidden by default** - Admin UI shows Active experiments by default

### Archiving via Admin UI

1. Navigate to `/admin/ex_abby/:id` (experiment detail page)
2. Select an optional winner from the dropdown
3. Click "Archive Experiment"

To unarchive, click the "Unarchive" button on the archived experiment.

### Archiving via Seeds

You can archive experiments directly in your seeds file:

```elixir
experiments = [
  # Active experiment
  {
    "current_test",
    "Currently running experiment",
    [{"control", 0.5}, {"variant", 0.5}],
    [success1_label: "Signup", update_weights: false]
  },

  # Archived experiment with winner
  {
    "old_test",
    "Completed experiment",
    [{"control", 0.5}, {"variant", 0.5}],
    [archived: true, winner: "variant", update_weights: false]
  }
]

Enum.each(experiments, fn {name, description, variations, opts} ->
  ExAbby.upsert_experiment_and_update_weights(name, description, variations, opts)
end)
```

**Important:** If you archive an experiment via the Admin UI and then run seeds without `archived: true`, the experiment will **remain archived**. Seeds only modify the archived status when explicitly specified.

### Archiving Programmatically

```elixir
# Archive without winner
ExAbby.Experiments.archive_experiment(experiment_id)

# Archive with winner (by variation name)
ExAbby.Experiments.archive_experiment(experiment_id, "variant_a")

# Archive with winner (by variation ID)
ExAbby.Experiments.archive_experiment(experiment_id, 123)

# Unarchive
ExAbby.Experiments.unarchive_experiment(experiment_id)
```

### Filtering Experiments

```elixir
# List only active experiments (default in Admin UI)
ExAbby.Experiments.list_experiments(status: :active)

# List only archived experiments
ExAbby.Experiments.list_experiments(status: :archived)

# List all experiments
ExAbby.Experiments.list_experiments(status: :all)
```

---

## Production Deployment

ExAbby experiments can be seeded automatically during your migration process.

1. **Update Mix Release Configuration**

In your `mix.exs`, ensure you have the releases configuration:
```elixir
def releases do
  [
    memoir: [
      include_erts: true,
      include_executables_for: [:unix],
      applications: [runtime_tools: :permanent],
      overlays: ["priv/repo/seeds"]
    ]
  ]
end
```


2. **Add Release Module Function**

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

3. **Update Migration Script**

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

## Troubleshooting

- **`No Ecto repo configured for :ex_abby`**  
  Add `config :ex_abby, repo: MyApp.Repo` in your host app’s `config.exs`.

- **No Experiment Found**  
  If you see a warning for no experiment found, make sure you have seeded the database wtih experiments nd variations.

---

**Enjoy A/B testing with ExAbby!** Feel free to customize it further for bandit algorithms, Bayesian stats, or other advanced features.
