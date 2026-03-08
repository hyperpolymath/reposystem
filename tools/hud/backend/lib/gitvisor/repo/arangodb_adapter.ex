# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Repo.ArangoDB do
  @moduledoc """
  ArangoDB adapter - multi-model graph database.

  Ideal for representing repository relationships, user connections,
  and complex queries across entities.
  """

  @behaviour Gitvisor.Repo.Adapter

  @impl true
  def connect(config) do
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 8529)
    database = Keyword.get(config, :database, "gitvisor")
    username = Keyword.get(config, :username, "root")
    password = Keyword.get(config, :password, "")

    conn = %{
      endpoint: "http://#{host}:#{port}/_db/#{database}/_api",
      auth: Base.encode64("#{username}:#{password}")
    }

    # Verify connection
    case http_get(conn, "/_api/version") do
      {:ok, %{"server" => "arango"}} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :connection_failed}
    end
  end

  @impl true
  def disconnect(_conn) do
    :ok
  end

  @impl true
  def get(conn, key) do
    [collection, doc_key] = String.split(to_string(key), "/", parts: 2)

    case http_get(conn, "/document/#{collection}/#{doc_key}") do
      {:ok, doc} -> {:ok, doc}
      {:error, :not_found} -> {:ok, nil}
      error -> error
    end
  end

  @impl true
  def put(conn, key, value) do
    [collection, doc_key] = String.split(to_string(key), "/", parts: 2)
    doc = Map.put(value, "_key", doc_key)

    case http_post(conn, "/document/#{collection}?overwrite=true", doc) do
      {:ok, _} -> {:ok, :ok}
      error -> error
    end
  end

  @impl true
  def delete(conn, key) do
    [collection, doc_key] = String.split(to_string(key), "/", parts: 2)

    case http_delete(conn, "/document/#{collection}/#{doc_key}") do
      {:ok, _} -> {:ok, :ok}
      {:error, :not_found} -> {:ok, :ok}
      error -> error
    end
  end

  @impl true
  def query(conn, query_spec) when is_binary(query_spec) do
    # AQL query
    body = %{query: query_spec}

    case http_post(conn, "/cursor", body) do
      {:ok, %{"result" => results}} -> {:ok, results}
      error -> error
    end
  end

  def query(conn, query_spec) when is_map(query_spec) do
    aql = Map.get(query_spec, :aql)
    bind_vars = Map.get(query_spec, :bind_vars, %{})

    body = %{query: aql, bindVars: bind_vars}

    case http_post(conn, "/cursor", body) do
      {:ok, %{"result" => results}} -> {:ok, results}
      error -> error
    end
  end

  # Graph-specific operations

  def traverse(conn, start_vertex, direction \\ :outbound, depth \\ 1..3) do
    aql = """
    FOR v, e, p IN #{Enum.min(depth)}..#{Enum.max(depth)}
      #{direction} @start
      GRAPH 'gitvisor'
      RETURN {vertex: v, edge: e, path: p}
    """

    query(conn, %{aql: aql, bind_vars: %{start: start_vertex}})
  end

  # Private HTTP helpers

  defp http_get(conn, path) do
    Req.get(conn.endpoint <> path, headers: auth_headers(conn))
    |> handle_response()
  end

  defp http_post(conn, path, body) do
    Req.post(conn.endpoint <> path,
      json: body,
      headers: auth_headers(conn)
    )
    |> handle_response()
  end

  defp http_delete(conn, path) do
    Req.delete(conn.endpoint <> path, headers: auth_headers(conn))
    |> handle_response()
  end

  defp auth_headers(conn) do
    [{"Authorization", "Basic #{conn.auth}"}]
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404}}) do
    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
