defmodule ExAbby.BotDetectorTest do
  use ExUnit.Case, async: false

  alias ExAbby.BotDetector
  alias ExAbby.BotDetector.Context
  import ExUnit.CaptureLog

  defmodule FirstHumanDetector do
    @moduledoc false

    def detect(context) do
      send(self(), {:first_human_detector, context})
      :human
    end
  end

  defmodule ContextBotDetector do
    @moduledoc false

    def detect(%Context{} = context) do
      send(self(), {:context_bot_detector, context})
      {:bot, :cloudflare_verified_bot}
    end
  end

  defmodule InvalidNameDetector do
    @moduledoc false

    def detect(%Context{user_agent: user_agent}) do
      {:bot, "untrusted-#{user_agent}"}
    end
  end

  defmodule RaisingDetector do
    @moduledoc false

    def detect(%Context{user_agent: user_agent}) do
      raise "detector failed for #{user_agent}"
    end
  end

  defmodule ThrowingDetector do
    @moduledoc false

    def detect(%Context{user_agent: user_agent}) do
      throw({:detector_failed, user_agent})
    end
  end

  setup do
    original_config = Application.get_env(:ex_abby, :bot_detection, :missing)

    on_exit(fn ->
      case original_config do
        :missing -> Application.delete_env(:ex_abby, :bot_detection)
        config -> Application.put_env(:ex_abby, :bot_detection, config)
      end
    end)

    Application.delete_env(:ex_abby, :bot_detection)

    :ok
  end

  test "detects known bots from every built-in category" do
    assert BotDetector.detect("Googlebot/2.1 (+https://www.google.com/bot.html)") ==
             {:bot, :googlebot}

    assert BotDetector.detect("GPTBot/1.0 (+https://openai.com/gptbot)") == {:bot, :gptbot}
    assert BotDetector.detect("facebookexternalhit/1.1") == {:bot, :facebookexternalhit}
    assert BotDetector.detect("Pingdom.com_bot_version_1.4") == {:bot, :pingdom}
    assert BotDetector.detect("Mozilla/5.0 (compatible; AhrefsBot/7.0)") == {:bot, :ahrefsbot}
    assert BotDetector.detect("ExampleCrawler/1.0") == {:bot, :generic_crawler}
  end

  test "detects audited production crawlers without classifying operational clients" do
    assert BotDetector.detect("GoogleImageProxy") == {:bot, :google_image_proxy}
    assert BotDetector.detect("AdsBot-Google-Mobile") == {:bot, :adsbot_google}
    assert BotDetector.detect("Amazonbot/0.1") == {:bot, :amazonbot}
    assert BotDetector.detect("PetalBot") == {:bot, :petalbot}
    assert BotDetector.detect("TikTokSpider") == {:bot, :tiktokspider}
    assert BotDetector.detect("meta-webindexer/1.1") == {:bot, :meta_webindexer}

    assert BotDetector.detect("Consul Health Check") == :human
  end

  test "treats ordinary, empty, and malformed user agents as human" do
    assert BotDetector.detect(
             "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
           ) ==
             :human

    assert BotDetector.detect("") == :human
    assert BotDetector.detect(nil) == :human
    assert BotDetector.detect(<<255, 254, 253>>) == :human
    assert BotDetector.detect("Mozilla/5.0 (Linux; Android 10; CUBOT_X30 Build/QP1A)") == :human
  end

  test "normalizes a connection to context for built-in and custom detectors" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Conn.put_req_header("user-agent", "Cloudflare Verified Bot")

    Application.put_env(
      :ex_abby,
      :bot_detection,
      detectors: [FirstHumanDetector, ContextBotDetector]
    )

    assert BotDetector.detect(conn) == {:bot, :cloudflare_verified_bot}

    assert_receive {:first_human_detector,
                    %Context{user_agent: "Cloudflare Verified Bot", conn: ^conn}}

    assert_receive {:context_bot_detector,
                    %Context{user_agent: "Cloudflare Verified Bot", conn: ^conn}}
  end

  test "normalizes a raw user agent to the same public context shape" do
    Application.put_env(
      :ex_abby,
      :bot_detection,
      detectors: [FirstHumanDetector, ContextBotDetector]
    )

    assert BotDetector.detect("Cloudflare Verified Bot") == {:bot, :cloudflare_verified_bot}

    assert_receive {:first_human_detector,
                    %Context{user_agent: "Cloudflare Verified Bot", conn: nil}}

    assert_receive {:context_bot_detector,
                    %Context{user_agent: "Cloudflare Verified Bot", conn: nil}}
  end

  test "can disable detection with config" do
    Application.put_env(:ex_abby, :bot_detection, enabled: false)

    assert BotDetector.detect("Googlebot/2.1") == :human
  end

  test "rejects invalid detector output instead of returning request-derived binary evidence" do
    Application.put_env(:ex_abby, :bot_detection, detectors: [InvalidNameDetector])

    assert BotDetector.detect("untrusted user agent") == :human
  end

  test "reports detector failures without exposing request data" do
    handler_id = "bot-detector-error-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:ex_abby, :bot_detector, :error],
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:detector_error, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    Application.put_env(:ex_abby, :bot_detection, detectors: [RaisingDetector])

    log =
      capture_log(fn ->
        assert BotDetector.detect("private-user-agent") == :human
      end)

    assert log =~ inspect(RaisingDetector)
    refute log =~ "private-user-agent"

    assert_receive {:detector_error, [:ex_abby, :bot_detector, :error], %{count: 1}, metadata}

    assert metadata == %{detector: RaisingDetector, kind: :error, error: RuntimeError}
  end

  test "reports thrown detector failures without exposing request data" do
    handler_id = "bot-detector-throw-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:ex_abby, :bot_detector, :error],
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:detector_error, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    Application.put_env(:ex_abby, :bot_detection, detectors: [ThrowingDetector])

    log =
      capture_log(fn ->
        assert BotDetector.detect("private-user-agent") == :human
      end)

    assert log =~ inspect(ThrowingDetector)
    refute log =~ "private-user-agent"

    assert_receive {:detector_error, [:ex_abby, :bot_detector, :error], %{count: 1}, metadata}

    # A thrown non-struct value has no exception module, so :error stays nil.
    assert metadata == %{detector: ThrowingDetector, kind: :throw, error: nil}
  end

  test "returns the documented default configuration" do
    assert BotDetector.config() ==
             [
               enabled: true,
               detectors: [ExAbby.BotDetector.UserAgent],
               fallback_variation: "control"
             ]
  end
end
