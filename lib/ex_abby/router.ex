defmodule ExAbby.Router do
  @moduledoc """
  Provides macros for injecting ExAbby admin routes into a Phoenix router.

  Usage in host app's `router.ex`:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import ExAbby.Router

        scope "/admin", MyAppWeb do
          pipe_through [:browser, :admin_auth]
          ex_abby_admin_routes()
        end
      end

  To expose only the per-user/per-session Trials page to non-admin users,
  mount it on its own behind a normal (non-admin) pipeline:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import ExAbby.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]
          ex_abby_trials_route()
        end
      end
  """

  defmacro ex_abby_admin_routes(_opts \\ []) do
    quote do
      import Phoenix.LiveView.Router

      # These are the LiveViews for your A/B test admin pages:
      live("/ex_abby", ExAbby.Live.ExAbbyRedirectLive)
      live("/ex_abby/trials", ExAbby.Live.TrialManagementLive)
      live("/ex_abby/index", ExAbby.Live.ExperimentIndexLive)
      live("/ex_abby/:id", ExAbby.Live.ExperimentShowLive)
    end
  end

  defmacro ex_abby_trials_route(_opts \\ []) do
    quote do
      import Phoenix.LiveView.Router

      # Mounts only the Trials page, e.g. for non-admin users. The
      # "ex_abby_standalone" session flag tells the LiveView to hide the
      # "Back to Experiments" link, since the admin index isn't mounted here.
      live_session :ex_abby_trials, session: %{"ex_abby_standalone" => true} do
        live("/ex_abby/trials", ExAbby.Live.TrialManagementLive)
      end
    end
  end
end
