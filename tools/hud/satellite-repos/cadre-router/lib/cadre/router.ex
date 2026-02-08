# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Cadre.Router do
  @moduledoc """
  CADRE Router - Configurable Adaptive Distributed Routing Engine.

  A flexible request routing framework supporting:
  - Phoenix integration
  - Static site serving (Serum, Zola)
  - Reverse proxy
  - Edge deployment
  """

  use GenServer
  require Logger

  @type route :: %{
          match: String.t() | Regex.t() | map(),
          backend: :phoenix | :static | :proxy | :redirect | :lambda,
          opts: keyword()
        }

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Add a route dynamically.
  """
  def add_route(router \\ __MODULE__, route) do
    GenServer.call(router, {:add_route, route})
  end

  @doc """
  Remove a route.
  """
  def remove_route(router \\ __MODULE__, match) do
    GenServer.call(router, {:remove_route, match})
  end

  @doc """
  Get all routes.
  """
  def routes(router \\ __MODULE__) do
    GenServer.call(router, :routes)
  end

  @doc """
  Match a request to a route.
  """
  def match(router \\ __MODULE__, conn) do
    GenServer.call(router, {:match, conn})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    routes = Keyword.get(opts, :routes, [])
    table = :ets.new(:cadre_routes, [:set, :protected])

    # Load initial routes
    Enum.each(routes, fn route ->
      :ets.insert(table, {route_key(route.match), route})
    end)

    state = %{
      table: table,
      middleware: Keyword.get(opts, :middleware, []),
      distributed: Keyword.get(opts, :distributed, false)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_route, route}, _from, state) do
    :ets.insert(state.table, {route_key(route.match), route})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:remove_route, match}, _from, state) do
    :ets.delete(state.table, route_key(match))
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:routes, _from, state) do
    routes = :ets.tab2list(state.table) |> Enum.map(fn {_k, v} -> v end)
    {:reply, routes, state}
  end

  @impl true
  def handle_call({:match, conn}, _from, state) do
    path = conn.request_path
    routes = :ets.tab2list(state.table)

    matched =
      routes
      |> Enum.find(fn {_key, route} -> matches?(route.match, path, conn) end)
      |> case do
        {_key, route} -> {:ok, route}
        nil -> {:error, :not_found}
      end

    {:reply, matched, state}
  end

  # Matching logic

  defp matches?(pattern, path, _conn) when is_binary(pattern) do
    cond do
      String.ends_with?(pattern, "*") ->
        prefix = String.trim_trailing(pattern, "*")
        String.starts_with?(path, prefix)

      true ->
        path == pattern
    end
  end

  defp matches?(%Regex{} = pattern, path, _conn) do
    Regex.match?(pattern, path)
  end

  defp matches?(%{host: host_pattern, path: path_pattern}, path, conn) do
    host_matches = matches?(host_pattern, conn.host, conn)
    path_matches = matches?(path_pattern, path, conn)
    host_matches and path_matches
  end

  defp route_key(match) when is_binary(match), do: match
  defp route_key(%Regex{} = match), do: Regex.source(match)
  defp route_key(%{} = match), do: inspect(match)
end
