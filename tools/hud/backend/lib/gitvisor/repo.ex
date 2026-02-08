# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Repo do
  @moduledoc """
  Primary repository abstraction for Gitvisor.

  Supports multiple database backends:
  - ArangoDB (graph database for relationships)
  - CubDB (embedded key-value store)
  - XTDB (temporal database for audit trails)
  - SurrealDB (multi-model)
  - LMDB (high-performance cache)
  - Dragonfly (Redis-compatible)
  """

  use GenServer

  @type adapter :: :arangodb | :cubdb | :xtdb | :surrealdb | :lmdb | :virtuoso

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    adapter = Keyword.get(opts, :adapter, Gitvisor.Repo.CubDB)
    config = Keyword.get(opts, :config, [])

    case adapter.connect(config) do
      {:ok, conn} ->
        {:ok, %{adapter: adapter, conn: conn}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  # Public API

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def query(query_spec) do
    GenServer.call(__MODULE__, {:query, query_spec})
  end

  # GenServer callbacks

  @impl true
  def handle_call({:get, key}, _from, %{adapter: adapter, conn: conn} = state) do
    result = adapter.get(conn, key)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, %{adapter: adapter, conn: conn} = state) do
    result = adapter.put(conn, key, value)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, %{adapter: adapter, conn: conn} = state) do
    result = adapter.delete(conn, key)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:query, query_spec}, _from, %{adapter: adapter, conn: conn} = state) do
    result = adapter.query(conn, query_spec)
    {:reply, result, state}
  end
end
