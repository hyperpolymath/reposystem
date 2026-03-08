# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Rhodibot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
