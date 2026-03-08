# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule GitvisorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :gitvisor

  # GraphQL subscriptions via WebSocket
  socket "/socket", GitvisorWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve static files (if hosting frontend)
  plug Plug.Static,
    at: "/",
    from: :gitvisor,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt .well-known)

  # Request logging
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Body parsing
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_gitvisor_key", signing_salt: "gitvisor_salt"

  # CORS for API access
  plug CORSPlug

  plug GitvisorWeb.Router

  @doc """
  Callback invoked for dynamically configuring the endpoint.
  """
  def init(_key, config) do
    {:ok, config}
  end
end
