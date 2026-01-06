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
end
