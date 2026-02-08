# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Cadre.Router.Middleware do
  @moduledoc """
  Middleware pipeline for CADRE Router.
  """

  def run_before(conn, _router) do
    # TODO: Load middleware from router config
    conn
  end

  def run_after(conn, _router) do
    conn
  end
end

defmodule Cadre.Middleware.SecurityHeaders do
  @moduledoc """
  Add security headers to responses.
  """

  @behaviour Plug

  @default_headers %{
    "x-content-type-options" => "nosniff",
    "x-frame-options" => "DENY",
    "x-xss-protection" => "1; mode=block",
    "referrer-policy" => "strict-origin-when-cross-origin"
  }

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    headers = Keyword.get(opts, :headers, @default_headers)

    Enum.reduce(headers, conn, fn {k, v}, acc ->
      Plug.Conn.put_resp_header(acc, k, v)
    end)
  end
end

defmodule Cadre.Middleware.CORS do
  @moduledoc """
  CORS middleware.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    origin = Keyword.get(opts, :origin, "*")
    methods = Keyword.get(opts, :methods, "GET, POST, PUT, DELETE, OPTIONS")
    headers_allowed = Keyword.get(opts, :headers, "Content-Type, Authorization")

    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", origin)
    |> Plug.Conn.put_resp_header("access-control-allow-methods", methods)
    |> Plug.Conn.put_resp_header("access-control-allow-headers", headers_allowed)
  end
end

defmodule Cadre.Middleware.RateLimit do
  @moduledoc """
  Simple rate limiting middleware.
  """

  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 100),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      table: :ets.new(:rate_limit, [:set, :public])
    }
  end

  @impl true
  def call(conn, opts) do
    key = client_key(conn)
    now = System.system_time(:millisecond)
    window_start = now - opts.window_ms

    # Clean old entries and count
    case :ets.lookup(opts.table, key) do
      [{^key, count, timestamp}] when timestamp > window_start ->
        if count >= opts.limit do
          conn
          |> Plug.Conn.put_resp_header("retry-after", "60")
          |> Plug.Conn.send_resp(429, "Too Many Requests")
          |> Plug.Conn.halt()
        else
          :ets.insert(opts.table, {key, count + 1, timestamp})
          conn
        end

      _ ->
        :ets.insert(opts.table, {key, 1, now})
        conn
    end
  end

  defp client_key(conn) do
    conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
  end
end
