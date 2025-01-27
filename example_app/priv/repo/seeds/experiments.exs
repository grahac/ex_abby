experiments = [
  {
    "button_color_test",
    "test button colors",
    [
      {"control", 0.33},
      {"green", 0.33},
      {"blue", 0.33}
    ],
    [success1_label: "Signup", success2_label: "Purchase", update_weights: false]
  },
    {
    "landing_page_test",
    "simple landing page text",
    [
      {"hello_world", 0.5},
      {"control", 0.5}
    ],
    [success1_label: "Signup", success2_label: "Purchase", update_weights: false]
  },

  # Add more experiments as needed
]

# Seed or update experiments without modifying weights
Enum.each(experiments, fn {name, description, variations, opts} ->
  ExAbby.Experiments.upsert_experiment_and_update_weights(name, description, variations, opts)
end)
