defmodule ExAbby.Live.ExperimentShowLive do
  @moduledoc """
  Shows a single experiment's variations, plus editing of weights.
  """
  alias ExAbby.Experiments
  use Phoenix.LiveView
  use Phoenix.Component

  def mount(%{"id" => id}, _session, socket) do
    experiment = Experiments.get_experiment(String.to_integer(id))

    if experiment do
      summary = Experiments.experiment_summary(experiment.name)

      {:ok,
       socket
       |> assign(:experiment, experiment)
       |> assign(:summary, summary)
       |> assign(:updated?, false)
       |> assign(:weights_form, build_weights_form(experiment.variations))}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <h2 class="text-2xl font-bold mb-4">Experiment: <%= @experiment.name %></h2>
      <p class="mb-6 text-gray-600"><%= @experiment.description %></p>

      <h3 class="text-xl font-semibold mb-4">Variations</h3>
      <div class="overflow-x-auto mb-8">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Variation</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Trials</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Successes</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Conversion Rate</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
          <%= for row <- @summary do %>
            <tr>
              <td class="px-6 py-4 whitespace-nowrap"><%= row.variation_name %></td>
              <td class="px-6 py-4 whitespace-nowrap"><%= row.trials %></td>
              <td class="px-6 py-4 whitespace-nowrap"><%= row.successes %></td>
              <td class="px-6 py-4 whitespace-nowrap"><%= Float.round(row.conversion_rate * 100, 2) %>%</td>
            </tr>
          <% end %>
          </tbody>
        </table>
      </div>

      <h3 class="text-xl font-semibold mb-4">Edit Variation Weights</h3>
      <h3 class="text-xl font-semibold mb-4">Edit Variation Weights</h3>
    <form phx-submit="save_weights" class="space-y-4">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Variation</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Weight</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for {v_id, name, w} <- @weights_form do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap"><%= name %></td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <input type="number"
                    name={"weights[weight_#{v_id}]"}
                    value={w}
                    step="0.01"
                    min="0"
                    max="1"
                    class="mt-1 block w-32 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <button type="submit" class="mt-4 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
        Save
      </button>
    </form>

    <%= if @updated? do %>
      <div class="mt-4 p-4 bg-green-100 text-green-700 rounded-md">Weights updated!</div>
    <% end %>
    </div>
    """
  end

  def handle_event("save_weights", %{"weights" => weights_params}, socket) do
    experiment = socket.assigns.experiment

    parsed =
      weights_params
      |> Enum.map(fn
        {"weight_" <> var_id_str, weight_str} ->
          var_id = String.to_integer(var_id_str)
          variation = Enum.find(experiment.variations, &(&1.id == var_id))
          {variation.name, String.to_float(weight_str)}
      end)

    {:ok, _experiment} =
      Experiments.upsert_experiment_and_update_weights(
        experiment.name,
        experiment.description,
        parsed
      )

    summary = Experiments.experiment_summary(experiment.name)
    {:noreply, assign(socket, :summary, summary) |> assign(:updated?, true)}
  end

  defp build_weights_form(variations) do
    for v <- variations, do: {v.id, v.name, v.weight}
  end
end
