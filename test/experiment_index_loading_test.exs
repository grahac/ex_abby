defmodule ExAbby.ExperimentIndexLoadingTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias ExAbby.{Experiment, Variation}
  alias ExAbby.Live.ExperimentIndexLive

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :ex_abby
  end

  @endpoint Endpoint

  defmodule Repo do
    def all(%Ecto.Query{from: %{source: {"ex_abby_experiments", _}}}) do
      %{owner: owner, experiments: experiments, block?: block?} =
        Application.fetch_env!(:ex_abby, :index_test_data)

      send(owner, {:metadata_query, self()})

      if block? do
        receive do
          :continue -> :ok
          :fail -> raise "report query failed"
        end
      end

      experiments
    end

    def all(%Ecto.Query{from: %{source: {"ex_abby_variations", _}}, wheres: wheres}) do
      [{experiment_id, _}] = Enum.flat_map(wheres, & &1.params)

      %{owner: owner, experiments: experiments} =
        Application.fetch_env!(:ex_abby, :index_test_data)

      send(owner, {:summary_query, experiment_id})
      experiment = Enum.find(experiments, &(&1.id == experiment_id))

      for variation <- experiment.variations do
        conversions = if variation.name == "control", do: 100, else: 500

        %{
          variation_id: variation.id,
          variation_name: variation.name,
          trial_count: 1000,
          excluded_trial_count: 0,
          success1_sum: conversions,
          success1_amount: 0.0,
          success1_unique: conversions,
          success2_sum: 0,
          success2_amount: 0.0,
          success2_unique: 0
        }
      end
    end
  end

  setup do
    keys = [:repo, :index_test_data, Endpoint]
    original = Map.new(keys, &{&1, Application.fetch_env(:ex_abby, &1)})

    on_exit(fn ->
      for {key, value} <- original do
        case value do
          {:ok, config} -> Application.put_env(:ex_abby, key, config)
          :error -> Application.delete_env(:ex_abby, key)
        end
      end
    end)

    Application.put_env(:ex_abby, :repo, Repo)

    Application.put_env(:ex_abby, :index_test_data, %{
      owner: self(),
      block?: false,
      experiments: [experiment(1, nil), experiment(2, ~U[2026-09-01 00:00:00Z])]
    })

    Application.put_env(:ex_abby, Endpoint,
      secret_key_base: String.duplicate("test", 16),
      live_view: [signing_salt: "index-test"],
      server: false,
      pubsub_server: __MODULE__.PubSub
    )

    start_supervised!({Phoenix.PubSub, name: __MODULE__.PubSub})
    start_supervised!(Endpoint)
    :ok
  end

  test "initial HTTP mount renders a loading state without database queries" do
    {:ok, socket} = ExperimentIndexLive.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    html = render_component(&ExperimentIndexLive.render/1, socket.assigns)

    assert html =~ "Experiments"
    assert html =~ "Loading experiments"
    refute html =~ "No experiments match"
    refute_received {:metadata_query, _}
    refute_received {:summary_query, _}
  end

  test "Running skips archived summaries, preserves archive metadata, and loads tabs on demand" do
    data = Application.fetch_env!(:ex_abby, :index_test_data)
    Application.put_env(:ex_abby, :index_test_data, %{data | block?: true})

    {:ok, view, html} = live_isolated(Phoenix.ConnTest.build_conn(), ExperimentIndexLive)
    assert html =~ "Loading experiments"
    assert_receive {:metadata_query, task}
    send(task, :continue)

    html = render_async(view)
    assert_receive {:summary_query, 1}
    refute_received {:summary_query, 2}
    assert html =~ "1 running"
    assert html =~ "1 archived"
    assert html =~ "significant result in this tab"
    assert html =~ "Recently archived"
    assert html =~ "Winner"

    assert render_click(view, "filter", %{"status" => "archived"}) =~ "Loading experiments"
    assert_receive {:metadata_query, task}
    send(task, :continue)
    html = render_async(view)
    assert_receive {:summary_query, 2}
    refute_received {:summary_query, 1}
    assert html =~ "experiment_2"
    refute html =~ "experiment_1"

    html = render_change(view, "search", %{"query" => "missing"})
    assert html =~ "No experiments match"
    refute_received {:metadata_query, _}
    refute_received {:summary_query, _}

    render_change(view, "search", %{"query" => ""})
    render_click(view, "filter", %{"status" => "all"})
    assert_receive {:metadata_query, task}
    send(task, :continue)
    html = render_async(view)
    assert html =~ "experiment_1"
    assert html =~ "experiment_2"
    assert_receive {:summary_query, 1}
    assert_receive {:summary_query, 2}
  end

  test "switching tabs cancels the previous load before it queries summaries" do
    data = Application.fetch_env!(:ex_abby, :index_test_data)
    Application.put_env(:ex_abby, :index_test_data, %{data | block?: true})

    {:ok, view, _html} = live_isolated(Phoenix.ConnTest.build_conn(), ExperimentIndexLive)
    assert_receive {:metadata_query, task}
    send(task, :continue)
    render_async(view)
    assert_receive {:summary_query, 1}

    render_click(view, "filter", %{"status" => "archived"})
    assert_receive {:metadata_query, archived_task}
    ref = Process.monitor(archived_task)
    render_click(view, "filter", %{"status" => "active"})
    assert_receive {:DOWN, ^ref, :process, ^archived_task, {:shutdown, :cancel}}
    assert_receive {:metadata_query, active_task}
    send(active_task, :continue)
    render_async(view)
    assert_receive {:summary_query, 1}
    refute_received {:summary_query, 2}

    assert has_element?(view, ".ex-abby-index__table a", "experiment_1")
    refute has_element?(view, ".ex-abby-index__table a", "experiment_2")
  end

  @tag :capture_log
  test "a query failure is displayed instead of empty results" do
    data = Application.fetch_env!(:ex_abby, :index_test_data)
    Application.put_env(:ex_abby, :index_test_data, %{data | block?: true})

    {:ok, view, _html} = live_isolated(Phoenix.ConnTest.build_conn(), ExperimentIndexLive)
    assert_receive {:metadata_query, task}

    send(task, :fail)
    html = render_async(view)
    assert html =~ "Could not load experiment results"
    refute html =~ "No experiments match"
    refute html =~ "Loading experiments"
  end

  defp experiment(id, archived_at) do
    %Experiment{
      id: id,
      name: "experiment_#{id}",
      inserted_at: ~N[2026-08-01 00:00:00],
      archived_at: archived_at,
      winner_variation_id: id * 10 + 1,
      variations: [
        %Variation{id: id * 10, name: "control", weight: 0.5},
        %Variation{id: id * 10 + 1, name: "treatment", weight: 0.5}
      ]
    }
  end
end
