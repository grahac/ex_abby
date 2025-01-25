defmodule ExAbby.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_abby,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "An A/B Testing library for Phoenix (with optional LiveView admin).",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {ExAbby.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:phoenix_live_view, "~> 0.18"},
      {:plug, "~> 1.14"}
      # If needed, :phoenix_html, etc.
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/your_user/ex_abby"}
    ]
  end
end
