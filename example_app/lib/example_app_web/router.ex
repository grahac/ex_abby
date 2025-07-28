defmodule ExampleAppWeb.Router do
  use ExampleAppWeb, :router
  import ExAbby.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug ExAbby.SessionPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExampleAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/index", PageController, :redirect_to_home
    live "/button-test-live", ButtonTestLive
    get "/button-test", ButtonTest.ButtonTestController, :index
    post "/button-test/convert", ButtonTest.ButtonTestController, :convert
  end

  scope "/admin" do
    # MAKE SURE THIS IS PROTECTED IN A REAL APP
    pipe_through :browser

    ex_abby_admin_routes()
  end

  scope "/", ExampleAppWeb do
    pipe_through :browser
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExampleAppWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:example_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExampleAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
