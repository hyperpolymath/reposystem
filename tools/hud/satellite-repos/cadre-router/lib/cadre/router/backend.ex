# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Cadre.Router.Backend do
  @moduledoc """
  Backend dispatchers for different route types.
  """

  require Logger

  @doc """
  Dispatch a connection to the appropriate backend.
  """
  def dispatch(conn, %{backend: :phoenix} = route) do
    plug = Map.get(route, :plug)
    assigns = Map.get(route, :assigns, %{})

    conn = Enum.reduce(assigns, conn, fn {k, v}, acc ->
      Plug.Conn.assign(acc, k, v)
    end)

    plug.call(conn, plug.init([]))
  end

  def dispatch(conn, %{backend: :static} = route) do
    path = Map.get(route, :path, ".")
    index = Map.get(route, :index, "index.html")

    # Strip route prefix from path
    match = Map.get(route, :match, "/")
    prefix = String.trim_trailing(to_string(match), "*")
    relative_path = String.trim_leading(conn.request_path, prefix)
    relative_path = if relative_path == "", do: index, else: relative_path

    file_path = Path.join(path, relative_path)

    if File.exists?(file_path) and not File.dir?(file_path) do
      conn
      |> Plug.Conn.put_resp_content_type(MIME.from_path(file_path))
      |> Plug.Conn.send_file(200, file_path)
    else
      # Try index.html for directory
      index_path = Path.join(file_path, index)

      if File.exists?(index_path) do
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_file(200, index_path)
      else
        conn
        |> Plug.Conn.send_resp(404, "Not Found")
      end
    end
  end

  def dispatch(conn, %{backend: :proxy} = route) do
    target = Map.get(route, :target)
    headers = Map.get(route, :headers, %{})

    # Build target URL
    url = target <> conn.request_path

    # Forward request
    case Req.request(
           method: conn.method |> String.downcase() |> String.to_atom(),
           url: url,
           headers: Map.merge(forward_headers(conn), headers),
           body: read_body(conn)
         ) do
      {:ok, response} ->
        conn
        |> put_response_headers(response.headers)
        |> Plug.Conn.send_resp(response.status, response.body)

      {:error, reason} ->
        Logger.error("Proxy error: #{inspect(reason)}")

        conn
        |> Plug.Conn.send_resp(502, "Bad Gateway")
    end
  end

  def dispatch(conn, %{backend: :redirect} = route) do
    to = Map.get(route, :to)
    status = Map.get(route, :status, 302)

    conn
    |> Plug.Conn.put_resp_header("location", to)
    |> Plug.Conn.send_resp(status, "")
  end

  def dispatch(conn, %{backend: :lambda} = route) do
    fun = Map.get(route, :fun)
    fun.(conn)
  end

  # Helpers

  defp forward_headers(conn) do
    conn.req_headers
    |> Enum.reject(fn {k, _} -> k in ["host", "content-length"] end)
    |> Map.new()
  end

  defp put_response_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {k, v}, acc ->
      Plug.Conn.put_resp_header(acc, String.downcase(k), v)
    end)
  end

  defp read_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} -> body
      _ -> ""
    end
  end
end
