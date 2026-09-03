import Ecto.Query

alias ExAbby.{Experiment, Experiments, Trial, Variation}
alias ExampleApp.Repo

# Fabricated, idempotent data used to capture the README screenshots. It never
# deletes data; rerunning it updates only the same `readme_*` demo trials.
scenarios = [
  %{
    name: "readme_checkout_progress",
    description:
      "Fabricated checkout completion demo: current checkout, concise checklist, or timeline guidance.",
    variations: [{"control", 1 / 3}, {"concise", 1 / 3}, {"timeline", 1 / 3}],
    labels: [success1_label: "Checkout", success2_label: "Paid order"],
    start_time: "30 days ago",
    arms: [
      {"control", 2_000, 152, 70, 4_480.0},
      {"concise", 2_000, 185, 82, 4_920.0},
      {"timeline", 2_000, 360, 200, 15_200.0}
    ]
  },
  %{
    name: "readme_search_prompt",
    description: "Fabricated search prompt demo with too little traffic to call.",
    variations: [{"control", 0.5}, {"suggested_queries", 0.5}],
    labels: [success1_label: "Search success"],
    start_time: "6 days ago",
    arms: [
      {"control", 24, 3, 0, 0.0},
      {"suggested_queries", 24, 4, 0, 0.0}
    ]
  },
  %{
    name: "readme_pricing_copy",
    description: "Fabricated completed pricing-message experiment.",
    variations: [{"control", 0.5}, {"value_first", 0.5}],
    labels: [success1_label: "Start trial", success2_label: "Subscription"],
    start_time: "45 days ago",
    archived: true,
    winner: "value_first",
    arms: [
      {"control", 800, 96, 41, 1_640.0},
      {"value_first", 800, 138, 68, 3_400.0}
    ]
  }
]

for scenario <- scenarios do
  opts = Keyword.merge([update_weights: false], scenario.labels)

  opts =
    if scenario[:archived],
      do: Keyword.merge(opts, archived: true, winner: scenario.winner),
      else: opts

  {:ok, _experiment} =
    Experiments.upsert_experiment_and_update_weights(
      scenario.name,
      scenario.description,
      scenario.variations,
      opts
    )

  experiment =
    scenario.name
    |> Experiments.get_experiment_by_name()
    |> Repo.preload(:variations)

  for {variation_name, weight} <- scenario.variations do
    variation =
      Enum.find(experiment.variations, &(&1.name == variation_name)) ||
        raise "missing #{variation_name} variation for #{scenario.name}"

    Experiments.update_weight(variation, weight)
  end

  {:ok, _experiment} =
    Experiments.update_experiment(experiment, %{start_time: scenario.start_time})

  variation_ids =
    Map.new(experiment.variations, fn %Variation{name: name, id: id} -> {name, id} end)

  now = DateTime.utc_now() |> DateTime.truncate(:second)
  timestamp = DateTime.to_naive(now)

  rows =
    for {variation_name, trials, checkouts, paid_orders, paid_amount} <- scenario.arms,
        sequence <- 1..trials do
      checked_out? = sequence <= checkouts
      paid? = sequence <= paid_orders

      %{
        experiment_id: experiment.id,
        variation_id: Map.fetch!(variation_ids, variation_name),
        session_id: "#{scenario.name}-#{variation_name}-#{sequence}",
        success1_count: if(checked_out?, do: 1, else: 0),
        success1_date: if(checked_out?, do: now, else: nil),
        success2_count: if(paid?, do: 1, else: 0),
        success2_date: if(paid?, do: now, else: nil),
        success2_amount: if(paid?, do: paid_amount / paid_orders, else: 0.0),
        inserted_at: timestamp,
        updated_at: timestamp
      }
    end

  {inserted, _} =
    Repo.insert_all(Trial, rows, on_conflict: :nothing)

  for {variation_name, trials, checkouts, paid_orders, paid_amount} <- scenario.arms do
    session_ids = for sequence <- 1..trials, do: "#{scenario.name}-#{variation_name}-#{sequence}"

    checkout_session_ids =
      for sequence <- 1..checkouts, do: "#{scenario.name}-#{variation_name}-#{sequence}"

    paid_session_ids =
      if paid_orders > 0 do
        for sequence <- 1..paid_orders, do: "#{scenario.name}-#{variation_name}-#{sequence}"
      else
        []
      end

    query =
      from trial in Trial,
        where: trial.experiment_id == ^experiment.id and trial.session_id in ^session_ids

    Repo.update_all(query,
      set: [
        success1_count: 0,
        success1_date: nil,
        success2_count: 0,
        success2_date: nil,
        success2_amount: 0.0,
        updated_at: timestamp
      ]
    )

    Repo.update_all(
      from(trial in Trial,
        where: trial.experiment_id == ^experiment.id and trial.session_id in ^checkout_session_ids
      ),
      set: [success1_count: 1, success1_date: now, updated_at: timestamp]
    )

    if paid_orders > 0 do
      Repo.update_all(
        from(trial in Trial,
          where: trial.experiment_id == ^experiment.id and trial.session_id in ^paid_session_ids
        ),
        set: [
          success2_count: 1,
          success2_date: now,
          success2_amount: paid_amount / paid_orders,
          updated_at: timestamp
        ]
      )
    end
  end

  IO.puts("#{scenario.name}: inserted #{inserted} fabricated trials")
end

demo_names = Enum.map(scenarios, & &1.name)

for %Experiment{name: name, id: id} <-
      Repo.all(from experiment in Experiment, where: experiment.name in ^demo_names) do
  trial_count = Repo.aggregate(from(trial in Trial, where: trial.experiment_id == ^id), :count)
  IO.puts("#{name}: #{trial_count} total fabricated trials")
end
