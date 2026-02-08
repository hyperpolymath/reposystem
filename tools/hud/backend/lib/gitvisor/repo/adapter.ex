# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Repo.Adapter do
  @moduledoc """
  Behaviour for database adapters.

  All database adapters must implement this behaviour to provide
  a consistent interface across different backends.
  """

  @type conn :: term()
  @type key :: String.t() | atom()
  @type value :: term()
  @type query_spec :: map() | String.t()
  @type result(t) :: {:ok, t} | {:error, term()}

  @callback connect(config :: keyword()) :: result(conn)
  @callback disconnect(conn) :: :ok | {:error, term()}
  @callback get(conn, key) :: result(value | nil)
  @callback put(conn, key, value) :: result(:ok)
  @callback delete(conn, key) :: result(:ok)
  @callback query(conn, query_spec) :: result([value])

  @optional_callbacks [query: 2]
end
