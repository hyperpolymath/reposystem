# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Repo.XTDB do
  @moduledoc """
  XTDB adapter - immutable, temporal database.

  Perfect for audit trails and historical queries.
  Supports "as-of" queries to see data at any point in time.
  """

  @behaviour Gitvisor.Repo.Adapter

  @impl true
  def connect(config) do
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 3000)

    conn = %{endpoint: "http://#{host}:#{port}"}

    case http_get(conn, "/status") do
      {:ok, _} -> {:ok, conn}
      error -> error
    end
  end

  @impl true
  def disconnect(_conn), do: :ok

  @impl true
  def get(conn, key) do
    query = """
    {:find [(pull ?e [*])]
     :where [[?e :xt/id ~key]]}
    """

    case query(conn, String.replace(query, "~key", inspect(key))) do
      {:ok, [[result]]} -> {:ok, result}
      {:ok, []} -> {:ok, nil}
      error -> error
    end
  end

  @impl true
  def put(conn, key, value) do
    doc = Map.put(value, "xt/id", key)

    body = %{
      "tx-ops" => [["put", doc]]
    }

    case http_post(conn, "/tx", body) do
      {:ok, _} -> {:ok, :ok}
      error -> error
    end
  end

  @impl true
  def delete(conn, key) do
    body = %{
      "tx-ops" => [["delete", key]]
    }

    case http_post(conn, "/tx", body) do
      {:ok, _} -> {:ok, :ok}
      error -> error
    end
  end

  @impl true
  def query(conn, query_spec) when is_binary(query_spec) do
    body = %{query: query_spec}

    case http_post(conn, "/query", body) do
      {:ok, results} -> {:ok, results}
      error -> error
    end
  end

  def query(conn, query_spec) when is_map(query_spec) do
    query_string = Map.get(query_spec, :query)
    as_of = Map.get(query_spec, :as_of)

    body =
      if as_of do
        %{query: query_string, "valid-time" => DateTime.to_iso8601(as_of)}
      else
        %{query: query_string}
      end

    case http_post(conn, "/query", body) do
      {:ok, results} -> {:ok, results}
      error -> error
    end
  end

  # Temporal query helpers

  @doc """
  Query data as it existed at a specific point in time.
  """
  def as_of(conn, key, timestamp) do
    query_spec = %{
      query: """
      {:find [(pull ?e [*])]
       :where [[?e :xt/id ~key]]}
      """,
      as_of: timestamp
    }

    case query(conn, %{query_spec | query: String.replace(query_spec.query, "~key", inspect(key))}) do
      {:ok, [[result]]} -> {:ok, result}
      {:ok, []} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Get the full history of an entity.
  """
  def history(conn, key) do
    case http_get(conn, "/entity-history/#{URI.encode(to_string(key))}") do
      {:ok, history} -> {:ok, history}
      error -> error
    end
  end

  # Private HTTP helpers

  defp http_get(conn, path) do
    Req.get(conn.endpoint <> path)
    |> handle_response()
  end

  defp http_post(conn, path, body) do
    Req.post(conn.endpoint <> path, json: body)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
