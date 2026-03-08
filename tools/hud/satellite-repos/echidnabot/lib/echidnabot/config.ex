# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Echidnabot.Config do
  @moduledoc """
  Configuration loading and parsing for Echidnabot.
  """

  @default_config %{
    general: %{
      fail_fast: false,
      parallel: true
    },
    languages: [:elixir, :rescript, :ada, :julia],
    elixir: %{
      dialyzer: true,
      credo_strict: true,
      property_tests: true
    },
    rescript: %{
      strict: true
    },
    ada: %{
      gnatprove_level: 2,
      warnings_as_errors: true
    },
    julia: %{
      tests: true
    },
    attestation: %{
      sign: true,
      timestamp: "opentimestamps"
    }
  }

  @doc """
  Load configuration from .echidnabot.toml or use defaults.
  """
  def load(path) do
    config_path = Path.join(path, ".echidnabot.toml")

    if File.exists?(config_path) do
      case Toml.decode_file(config_path) do
        {:ok, config} -> deep_merge(@default_config, atomize_keys(config))
        {:error, _} -> @default_config
      end
    else
      # Auto-detect languages
      detected = detect_languages(path)
      %{@default_config | languages: detected}
    end
  end

  @doc """
  Detect which languages are present in a repository.
  """
  def detect_languages(path) do
    checks = [
      {:elixir, ["mix.exs"]},
      {:rescript, ["rescript.json", "bsconfig.json"]},
      {:ada, ["*.gpr"]},
      {:julia, ["Project.toml"]},
      {:rust, ["Cargo.toml"]}
    ]

    checks
    |> Enum.filter(fn {_lang, patterns} ->
      Enum.any?(patterns, fn pattern ->
        path
        |> Path.join(pattern)
        |> Path.wildcard()
        |> Enum.any?()
      end)
    end)
    |> Enum.map(fn {lang, _} -> lang end)
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn
      _key, base_val, override_val when is_map(base_val) and is_map(override_val) ->
        deep_merge(base_val, override_val)

      _key, _base_val, override_val ->
        override_val
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), atomize_keys(value)}
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value
end
