# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule Echidnabot.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Echidnabot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
