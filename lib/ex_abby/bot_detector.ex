defmodule ExAbby.BotDetector do
  @moduledoc """
  Configurable, transient bot classification for request-aware integrations.

  Detectors receive an `ExAbby.BotDetector.Context` and return either `:human`
  or `{:bot, static_atom_name}`. The returned atom is safe to place in a
  session; user-agent and connection data stay in the transient context.
  """

  alias ExAbby.BotDetector.Context

  @default_config [
    enabled: true,
    detectors: [ExAbby.BotDetector.UserAgent],
    fallback_variation: "control"
  ]

  @doc """
  Classifies a raw user-agent string or `Plug.Conn` as `:human` or a bot.

  Configured detector modules are called in order with a normalized context.
  Invalid detector responses are ignored so request-derived data cannot become
  bot status.
  """
  @spec detect(String.t() | Plug.Conn.t() | Context.t() | nil | term()) ::
          :human | {:bot, atom()}
  def detect(input) do
    context = Context.new(input)
    config = config()

    if Keyword.get(config, :enabled, true) do
      config
      |> Keyword.get(:detectors, [])
      |> List.wrap()
      |> detect_with(context)
    else
      :human
    end
  end

  @doc """
  Returns the effective bot detection configuration.

  Detection is enabled by default with the built-in user-agent detector and a
  `"control"` fallback variation.
  """
  @spec config() :: keyword()
  def config do
    configured = Application.get_env(:ex_abby, :bot_detection, [])

    if Keyword.keyword?(configured) do
      Keyword.merge(@default_config, configured)
    else
      @default_config
    end
  end

  defp detect_with(detectors, context) do
    Enum.reduce_while(detectors, :human, fn detector, _status ->
      case detector |> call_detector(context) |> validate_status() do
        {:bot, _bot_name} = status -> {:halt, status}
        :human -> {:cont, :human}
      end
    end)
  end

  defp call_detector(detector, context) when is_atom(detector) do
    with {:module, _module} <- Code.ensure_loaded(detector),
         true <- function_exported?(detector, :detect, 1) do
      detector.detect(context)
    else
      _ -> :human
    end
  rescue
    _exception -> :human
  catch
    _kind, _value -> :human
  end

  defp call_detector(_detector, _context), do: :human

  defp validate_status(:human), do: :human

  defp validate_status({:bot, bot_name})
       when is_atom(bot_name) and bot_name not in [nil, true, false, :human] do
    {:bot, bot_name}
  end

  defp validate_status(_invalid_status), do: :human
end

defmodule ExAbby.BotDetector.UserAgent do
  @moduledoc false

  alias ExAbby.BotDetector.Context

  # Search engines
  @patterns [
    {:googlebot, ["googlebot"]},
    {:bingbot, ["bingbot"]},
    {:slurp, ["slurp"]},
    {:duckduckbot, ["duckduckbot"]},
    {:baiduspider, ["baiduspider"]},
    {:yandexbot, ["yandexbot"]},
    {:applebot, ["applebot"]},
    {:adsbot_google, ["adsbot-google"]},
    {:google_image_proxy, ["googleimageproxy"]},
    {:google_read_aloud, ["google-read-aloud"]},
    {:google_notebooklm, ["google-notebooklm"]},
    # AI crawlers and agents
    {:gptbot, ["gptbot"]},
    {:chatgpt_user, ["chatgpt-user"]},
    {:oai_searchbot, ["oai-searchbot"]},
    {:claudebot, ["claudebot"]},
    {:claude_web, ["claude-web"]},
    {:claude_user, ["claude-user"]},
    {:anthropic_ai, ["anthropic-ai"]},
    {:perplexitybot, ["perplexitybot"]},
    {:perplexity_user, ["perplexity-user"]},
    {:youbot, ["youbot"]},
    {:bytespider, ["bytespider"]},
    {:cohere_ai, ["cohere-ai"]},
    {:google_extended, ["google-extended"]},
    {:googleagent_mariner, ["googleagent-mariner"]},
    {:googleother, ["googleother"]},
    {:google_cloud_vertexbot, ["google-cloudvertexbot"]},
    {:bingpreview, ["bingpreview"]},
    {:microsoftpreview, ["microsoftpreview"]},
    {:ccbot, ["ccbot"]},
    {:diffbot, ["diffbot"]},
    {:meta_externalagent, ["meta-externalagent"]},
    {:meta_externalfetcher, ["meta-externalfetcher"]},
    {:meta_webindexer, ["meta-webindexer"]},
    # Social preview crawlers
    {:facebookexternalhit, ["facebookexternalhit"]},
    {:facebot, ["facebot"]},
    {:twitterbot, ["twitterbot"]},
    {:linkedinbot, ["linkedinbot"]},
    {:whatsapp, ["whatsapp"]},
    {:telegrambot, ["telegrambot"]},
    {:discordbot, ["discordbot"]},
    {:slackbot, ["slackbot"]},
    {:pinterestbot, ["pinterestbot"]},
    # Monitoring services
    {:pingdom, ["pingdom"]},
    {:uptimerobot, ["uptimerobot"]},
    {:statuscake, ["statuscake"]},
    {:site24x7, ["site24x7"]},
    {:datadog, ["datadog"]},
    {:newrelic, ["newrelic"]},
    # SEO tooling
    {:ahrefsbot, ["ahrefsbot"]},
    {:semrushbot, ["semrushbot"]},
    {:mj12bot, ["mj12bot"]},
    {:dotbot, ["dotbot"]},
    {:rogerbot, ["rogerbot"]},
    {:screaming_frog, ["screaming frog"]},
    {:blexbot, ["blexbot"]},
    # Crawlers observed in production traffic that do not match the generic
    # word-boundary rule because their names end in "bot" or "spider".
    {:amazonbot, ["amazonbot"]},
    {:petalbot, ["petalbot"]},
    {:tiktokspider, ["tiktokspider"]},
    {:duckassistbot, ["duckassistbot"]},
    {:shapbot, ["shapbot"]},
    {:maintouchbot, ["maintouchbot"]},
    {:awariobot, ["awariobot"]},
    {:sleepbot, ["sleepbot"]}
  ]

  @generic_markers ["crawler", "spider", "scraper", "crawl"]
  @generic_bot_pattern ~r/(?:^|[^[:alnum:]_])bot(?:$|[^[:alnum:]_])/u

  @spec detect(Context.t()) :: :human | {:bot, atom()}
  def detect(%Context{user_agent: user_agent}) when is_binary(user_agent) do
    user_agent
    |> lowercase()
    |> classify()
  end

  def detect(_context), do: :human

  defp classify(user_agent) do
    case Enum.find(@patterns, fn {_bot_name, patterns} -> matches_any?(user_agent, patterns) end) do
      {bot_name, _patterns} ->
        {:bot, bot_name}

      nil ->
        if matches_any?(user_agent, @generic_markers) or generic_bot?(user_agent),
          do: {:bot, :generic_crawler},
          else: :human
    end
  end

  defp lowercase(user_agent) do
    if String.valid?(user_agent), do: String.downcase(user_agent), else: ""
  end

  defp matches_any?(user_agent, patterns) do
    Enum.any?(patterns, &(:binary.match(user_agent, &1) != :nomatch))
  end

  defp generic_bot?(user_agent), do: Regex.match?(@generic_bot_pattern, user_agent)
end
