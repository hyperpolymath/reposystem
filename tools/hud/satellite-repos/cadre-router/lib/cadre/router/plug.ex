# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Cadre.Router.Plug do
  @moduledoc """
  Plug integration for CADRE Router.

  Use in your endpoint:

      plug Cadre.Router.Plug, router: MyApp.CadreRouter
  """

  @behaviour Plug

  alias Cadre.Router
  alias Cadre.Router.{Backend, Middleware}

  @impl true
  def init(opts) do
    %{
      router: Keyword.fetch!(opts, :router),
      not_found: Keyword.get(opts, :not_found, &default_not_found/1)
    }
  end

  @impl true
  def call(conn, opts) do
    conn = Middleware.run_before(conn, opts.router)

    case Router.match(opts.router, conn) do
      {:ok, route} ->
        conn
        |> Backend.dispatch(route)
        |> Middleware.run_after(opts.router)

      {:error, :not_found} ->
        opts.not_found.(conn)
    end
  end

  defp default_not_found(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(404, "Not Found")
  end
end
