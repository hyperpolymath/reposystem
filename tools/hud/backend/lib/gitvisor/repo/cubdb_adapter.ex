# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Repo.CubDB do
  @moduledoc """
  CubDB adapter - embedded key-value store.

  Perfect for development and single-node deployments.
  Provides ACID transactions and snapshot isolation.
  """

  @behaviour Gitvisor.Repo.Adapter

  @impl true
  def connect(config) do
    data_dir = Keyword.get(config, :data_dir, "priv/data/cubdb")
    File.mkdir_p!(data_dir)

    case CubDB.start_link(data_dir: data_dir) do
      {:ok, db} -> {:ok, db}
      {:error, {:already_started, db}} -> {:ok, db}
      error -> error
    end
  end

  @impl true
  def disconnect(db) do
    CubDB.stop(db)
    :ok
  end

  @impl true
  def get(db, key) do
    {:ok, CubDB.get(db, key)}
  end

  @impl true
  def put(db, key, value) do
    CubDB.put(db, key, value)
    {:ok, :ok}
  end

  @impl true
  def delete(db, key) do
    CubDB.delete(db, key)
    {:ok, :ok}
  end

  @impl true
  def query(db, query_spec) when is_map(query_spec) do
    prefix = Map.get(query_spec, :prefix)
    limit = Map.get(query_spec, :limit, 100)

    results =
      if prefix do
        db
        |> CubDB.select(min_key: prefix, max_key: prefix <> <<255>>)
        |> Enum.take(limit)
        |> Enum.map(fn {_k, v} -> v end)
      else
        db
        |> CubDB.select()
        |> Enum.take(limit)
        |> Enum.map(fn {_k, v} -> v end)
      end

    {:ok, results}
  end
end
