# List of experiments and their variations
experiments = [
  {
    "button_color_test",
    "button color test",
    [
      {"control", 0.33},
      {"green", 0.33},
      {"blue", 0.33}
    ]
  },
  # Add more experiments as needed
]

# Seed or update experiments without modifying weights
Enum.each(experiments, fn {name, description, variations} ->
  ExAbby.Experiments.upsert_experiment_and_update_weights(name, description, variations, false)
end)
