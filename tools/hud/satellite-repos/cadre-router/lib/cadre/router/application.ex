# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule Cadre.Router.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Cadre.Router.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
