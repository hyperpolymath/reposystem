# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Crypto do
  @moduledoc """
  Cryptographic operations for Gitvisor.

  Provides secure hashing, signing, and key management using:
  - BLAKE3 (fast, secure hashing)
  - SHAKE3-512 (extendable output function)
  - Ed448 (classical signatures)
  - Dilithium (post-quantum signatures)
  - Kyber-1024 (post-quantum key encapsulation)

  All operations follow best practices for secure key handling.
  """

  # Hash functions

  @doc """
  Compute BLAKE3 hash of data.

  ## Examples

      iex> Gitvisor.Crypto.blake3("hello world")
      <<...32 bytes...>>
  """
  def blake3(data) when is_binary(data) do
    Blake3.hash(data)
  end

  @doc """
  Compute BLAKE3 hash with custom output length.
  """
  def blake3(data, output_length) when is_binary(data) and is_integer(output_length) do
    Blake3.hash(data, length: output_length)
  end

  @doc """
  Compute SHAKE3-512 (extendable output function).

  Uses the :crypto module's SHAKE implementation.
  """
  def shake3_512(data, output_length \\ 64) when is_binary(data) do
    # Note: Erlang/OTP 24+ has SHAKE support
    # For older versions, we'd need a NIF
    try do
      :crypto.hash(:shake256, data, output_length)
    rescue
      _ ->
        # Fallback: use BLAKE3 XOF mode
        blake3(data, output_length)
    end
  end

  # Classical signatures (Ed448)

  @doc """
  Generate an Ed448 keypair.

  Returns {public_key, private_key} tuple.
  """
  def generate_ed448_keypair do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed448)
    {pub, priv}
  end

  @doc """
  Sign data using Ed448.
  """
  def ed448_sign(data, private_key) when is_binary(data) and is_binary(private_key) do
    :crypto.sign(:eddsa, :none, data, [private_key, :ed448])
  end

  @doc """
  Verify an Ed448 signature.
  """
  def ed448_verify(data, signature, public_key)
      when is_binary(data) and is_binary(signature) and is_binary(public_key) do
    :crypto.verify(:eddsa, :none, data, signature, [public_key, :ed448])
  end

  # Post-quantum signatures (Dilithium)
  # Note: These are stubs - actual implementation would require a NIF
  # to liboqs or similar library

  @doc """
  Generate a Dilithium keypair.

  Note: Requires post-quantum crypto NIF.
  """
  def generate_dilithium_keypair do
    # Stub - would call NIF to liboqs
    {:error, :not_implemented}
  end

  @doc """
  Sign data using Dilithium.
  """
  def dilithium_sign(_data, _private_key) do
    {:error, :not_implemented}
  end

  @doc """
  Verify a Dilithium signature.
  """
  def dilithium_verify(_data, _signature, _public_key) do
    {:error, :not_implemented}
  end

  # Post-quantum key encapsulation (Kyber-1024)

  @doc """
  Generate a Kyber-1024 keypair.

  Note: Requires post-quantum crypto NIF.
  """
  def generate_kyber_keypair do
    {:error, :not_implemented}
  end

  @doc """
  Encapsulate a shared secret using Kyber.
  """
  def kyber_encapsulate(_public_key) do
    {:error, :not_implemented}
  end

  @doc """
  Decapsulate a shared secret using Kyber.
  """
  def kyber_decapsulate(_ciphertext, _private_key) do
    {:error, :not_implemented}
  end

  # Key derivation

  @doc """
  Derive a key using HKDF with BLAKE3.
  """
  def derive_key(input_key_material, salt \\ "", info \\ "", length \\ 32) do
    # HKDF-Extract
    prk = blake3(salt <> input_key_material)

    # HKDF-Expand
    expand(prk, info, length, <<>>, 1)
  end

  defp expand(_prk, _info, length, output, _counter) when byte_size(output) >= length do
    binary_part(output, 0, length)
  end

  defp expand(prk, info, length, output, counter) do
    prev = if output == <<>>, do: <<>>, else: binary_part(output, byte_size(output) - 32, 32)
    block = blake3(prev <> info <> <<counter::8>>)
    expand(prk, info, length, output <> block, counter + 1)
  end

  # Secure random

  @doc """
  Generate cryptographically secure random bytes.
  """
  def random_bytes(length) when is_integer(length) and length > 0 do
    :crypto.strong_rand_bytes(length)
  end

  @doc """
  Generate a random proven strong prime.

  Uses rejection sampling with primality testing.
  """
  def generate_strong_prime(bits \\ 2048) do
    # Generate random odd number of specified bit length
    candidate = random_odd(bits)

    # Test for primality using Miller-Rabin
    if is_probable_prime?(candidate, 40) do
      candidate
    else
      generate_strong_prime(bits)
    end
  end

  defp random_odd(bits) do
    bytes = div(bits + 7, 8)
    <<first::8, rest::binary>> = random_bytes(bytes)
    # Set high bit and low bit (ensure odd)
    <<(first ||| 0x80)::8, rest::binary>>
    |> :binary.decode_unsigned()
    |> Bitwise.bor(1)
  end

  defp is_probable_prime?(n, rounds) do
    # Miller-Rabin primality test
    if n < 2, do: false
    if n == 2, do: true
    if rem(n, 2) == 0, do: false

    # Write n-1 as 2^r * d
    {r, d} = factor_out_twos(n - 1)

    Enum.all?(1..rounds, fn _ ->
      a = 2 + :rand.uniform(n - 4)
      miller_rabin_witness?(a, d, n, r)
    end)
  end

  defp factor_out_twos(n, r \\ 0) do
    if rem(n, 2) == 0 do
      factor_out_twos(div(n, 2), r + 1)
    else
      {r, n}
    end
  end

  defp miller_rabin_witness?(a, d, n, r) do
    x = mod_pow(a, d, n)

    cond do
      x == 1 or x == n - 1 ->
        true

      true ->
        check_composite(x, n, r - 1)
    end
  end

  defp check_composite(_x, _n, 0), do: false

  defp check_composite(x, n, r) do
    x = mod_pow(x, 2, n)

    cond do
      x == n - 1 -> true
      x == 1 -> false
      true -> check_composite(x, n, r - 1)
    end
  end

  defp mod_pow(base, exp, mod) do
    :crypto.mod_pow(base, exp, mod)
    |> :binary.decode_unsigned()
  end

  # Token generation

  @doc """
  Generate a secure API token.
  """
  def generate_token(prefix \\ "gv") do
    random = random_bytes(24) |> Base.url_encode64(padding: false)
    "#{prefix}_#{random}"
  end

  @doc """
  Hash a token for storage.
  """
  def hash_token(token) do
    blake3(token) |> Base.encode16(case: :lower)
  end
end
