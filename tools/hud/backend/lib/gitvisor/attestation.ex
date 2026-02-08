# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Attestation do
  @moduledoc """
  Comprehensive attestation framework for Gitvisor.

  Supports multiple attestation methods across different trust levels:

  ## Attestation Categories

  ### Provenance (Build Origin)
  - SLSA provenance attestations
  - in-toto supply chain attestations

  ### Software Bill of Materials
  - SPDX (license-focused)
  - CycloneDX (security-focused)

  ### Cryptographic Signing
  - Sigstore/Cosign (keyless)
  - GPG/PGP (traditional)
  - Ed448/Dilithium (post-quantum ready)

  ### Timestamping
  - OpenTimestamps (Bitcoin aggregated, eco-friendly)
  - RFC 3161 TSA (traditional)
  - Direct blockchain (critical items only)

  ### Transparency Logs
  - Rekor (Sigstore)
  - GitHub Artifact Attestations

  ### Formal Verification
  - SPARK proofs (for Ada components)
  - Property-based testing results (echidnabot)
  - Reproducible build verification

  ## Usage

      # Automatic attestation on release
      Gitvisor.Attestation.attest_release(release_artifact, opts)

      # Verify attestations
      Gitvisor.Attestation.verify(artifact, attestations)
  """

  alias Gitvisor.Crypto

  @type attestation_type ::
          :slsa_provenance
          | :intoto
          | :spdx_sbom
          | :cyclonedx_sbom
          | :sigstore
          | :gpg
          | :opentimestamps
          | :rfc3161
          | :blockchain
          | :rekor
          | :github_attestation
          | :spark_proof
          | :property_test

  @type criticality :: :low | :medium | :high | :critical

  @type attestation :: %{
          type: attestation_type(),
          timestamp: DateTime.t(),
          subject_hash: binary(),
          signature: binary() | nil,
          proof: binary() | nil,
          metadata: map()
        }

  # Configuration for automatic attestation based on criticality
  @auto_attestations %{
    low: [:opentimestamps],
    medium: [:opentimestamps, :sigstore, :spdx_sbom],
    high: [:opentimestamps, :sigstore, :slsa_provenance, :cyclonedx_sbom, :rekor],
    critical: [
      :opentimestamps,
      :blockchain,
      :sigstore,
      :slsa_provenance,
      :cyclonedx_sbom,
      :rekor,
      :spark_proof
    ]
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generate attestations for an artifact based on criticality level.
  """
  def attest(artifact, criticality \\ :medium, opts \\ []) do
    types = Map.get(@auto_attestations, criticality, [])

    attestations =
      types
      |> Enum.map(&generate_attestation(&1, artifact, opts))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, att} -> att end)

    {:ok, attestations}
  end

  @doc """
  Generate a specific attestation type.
  """
  def generate_attestation(type, artifact, opts \\ [])

  def generate_attestation(:opentimestamps, artifact, _opts) do
    hash = Crypto.blake3(artifact)

    case submit_to_ots(hash) do
      {:ok, proof} ->
        {:ok,
         %{
           type: :opentimestamps,
           timestamp: DateTime.utc_now(),
           subject_hash: hash,
           signature: nil,
           proof: proof,
           metadata: %{status: :pending, calendar: "https://alice.btc.calendar.opentimestamps.org"}
         }}

      error ->
        error
    end
  end

  def generate_attestation(:sigstore, artifact, opts) do
    hash = Crypto.blake3(artifact)
    identity = Keyword.get(opts, :identity)

    case sign_with_sigstore(hash, identity) do
      {:ok, bundle} ->
        {:ok,
         %{
           type: :sigstore,
           timestamp: DateTime.utc_now(),
           subject_hash: hash,
           signature: bundle.signature,
           proof: bundle.certificate,
           metadata: %{
             transparency_log: bundle.rekor_entry,
             identity: identity
           }
         }}

      error ->
        error
    end
  end

  def generate_attestation(:slsa_provenance, artifact, opts) do
    hash = Crypto.blake3(artifact)

    provenance = %{
      "_type" => "https://in-toto.io/Statement/v0.1",
      "subject" => [
        %{
          "name" => Keyword.get(opts, :name, "artifact"),
          "digest" => %{"blake3" => Base.encode16(hash, case: :lower)}
        }
      ],
      "predicateType" => "https://slsa.dev/provenance/v1",
      "predicate" => %{
        "buildDefinition" => %{
          "buildType" => "https://gitvisor.dev/build/v1",
          "externalParameters" => Keyword.get(opts, :params, %{}),
          "internalParameters" => %{},
          "resolvedDependencies" => []
        },
        "runDetails" => %{
          "builder" => %{"id" => "https://gitvisor.dev"},
          "metadata" => %{
            "invocationId" => Crypto.generate_token("inv"),
            "startedOn" => DateTime.to_iso8601(DateTime.utc_now())
          }
        }
      }
    }

    {:ok,
     %{
       type: :slsa_provenance,
       timestamp: DateTime.utc_now(),
       subject_hash: hash,
       signature: nil,
       proof: Jason.encode!(provenance),
       metadata: %{slsa_level: 2}
     }}
  end

  def generate_attestation(:spdx_sbom, _artifact, opts) do
    sbom = generate_spdx_sbom(opts)

    {:ok,
     %{
       type: :spdx_sbom,
       timestamp: DateTime.utc_now(),
       subject_hash: Crypto.blake3(sbom),
       signature: nil,
       proof: sbom,
       metadata: %{format: "SPDX-2.3", spec: "https://spdx.dev"}
     }}
  end

  def generate_attestation(:cyclonedx_sbom, _artifact, opts) do
    sbom = generate_cyclonedx_sbom(opts)

    {:ok,
     %{
       type: :cyclonedx_sbom,
       timestamp: DateTime.utc_now(),
       subject_hash: Crypto.blake3(sbom),
       signature: nil,
       proof: sbom,
       metadata: %{format: "CycloneDX-1.5", spec: "https://cyclonedx.org"}
     }}
  end

  def generate_attestation(:blockchain, artifact, opts) do
    hash = Crypto.blake3(artifact)
    chain = Keyword.get(opts, :chain, :bitcoin)

    # Direct blockchain timestamp - use sparingly
    case submit_to_blockchain(hash, chain) do
      {:ok, tx_id} ->
        {:ok,
         %{
           type: :blockchain,
           timestamp: DateTime.utc_now(),
           subject_hash: hash,
           signature: nil,
           proof: tx_id,
           metadata: %{chain: chain, status: :pending_confirmation}
         }}

      error ->
        error
    end
  end

  def generate_attestation(:spark_proof, artifact, opts) do
    # For Ada/SPARK components - reference proof artifacts
    proof_file = Keyword.get(opts, :proof_file)

    if proof_file && File.exists?(proof_file) do
      proof_content = File.read!(proof_file)

      {:ok,
       %{
         type: :spark_proof,
         timestamp: DateTime.utc_now(),
         subject_hash: Crypto.blake3(artifact),
         signature: nil,
         proof: proof_content,
         metadata: %{
           tool: "gnatprove",
           level: Keyword.get(opts, :level, 2)
         }
       }}
    else
      {:error, :no_spark_proof}
    end
  end

  def generate_attestation(:property_test, artifact, opts) do
    # Echidnabot / property-based test results
    test_results = Keyword.get(opts, :test_results, %{})

    {:ok,
     %{
       type: :property_test,
       timestamp: DateTime.utc_now(),
       subject_hash: Crypto.blake3(artifact),
       signature: nil,
       proof: Jason.encode!(test_results),
       metadata: %{
         tool: Keyword.get(opts, :tool, "echidnabot"),
         properties_checked: Map.get(test_results, :properties, 0),
         passed: Map.get(test_results, :passed, false)
       }
     }}
  end

  def generate_attestation(type, _artifact, _opts) do
    {:error, {:unsupported_attestation_type, type}}
  end

  @doc """
  Verify all attestations for an artifact.
  """
  def verify(artifact, attestations) when is_list(attestations) do
    results =
      attestations
      |> Enum.map(&verify_single(artifact, &1))

    all_valid = Enum.all?(results, fn {status, _} -> status == :ok end)

    if all_valid do
      {:ok, results}
    else
      {:error, results}
    end
  end

  defp verify_single(artifact, %{type: :opentimestamps} = att) do
    hash = Crypto.blake3(artifact)

    if hash == att.subject_hash do
      # Verify OTS proof against Bitcoin
      case verify_ots_proof(att.proof) do
        {:ok, bitcoin_time} -> {:ok, %{type: :opentimestamps, verified_at: bitcoin_time}}
        error -> error
      end
    else
      {:error, :hash_mismatch}
    end
  end

  defp verify_single(artifact, %{type: :sigstore} = att) do
    hash = Crypto.blake3(artifact)

    if hash == att.subject_hash do
      # Verify Sigstore bundle
      case verify_sigstore_bundle(att.signature, att.proof, att.metadata.transparency_log) do
        :ok -> {:ok, %{type: :sigstore, identity: att.metadata.identity}}
        error -> error
      end
    else
      {:error, :hash_mismatch}
    end
  end

  defp verify_single(artifact, %{type: type} = att) do
    hash = Crypto.blake3(artifact)

    if hash == att.subject_hash do
      {:ok, %{type: type, verified: :hash_match}}
    else
      {:error, :hash_mismatch}
    end
  end

  # ============================================================================
  # Private Implementation (Stubs for actual integrations)
  # ============================================================================

  defp submit_to_ots(_hash) do
    # TODO: Integrate with OpenTimestamps calendar servers
    # POST to https://alice.btc.calendar.opentimestamps.org/digest
    {:ok, <<>>}
  end

  defp sign_with_sigstore(_hash, _identity) do
    # TODO: Integrate with Sigstore/Cosign
    {:ok, %{signature: <<>>, certificate: <<>>, rekor_entry: nil}}
  end

  defp submit_to_blockchain(_hash, _chain) do
    # TODO: Direct blockchain submission (use sparingly!)
    {:error, :not_implemented}
  end

  defp verify_ots_proof(_proof) do
    # TODO: Verify OTS proof against Bitcoin
    {:ok, DateTime.utc_now()}
  end

  defp verify_sigstore_bundle(_sig, _cert, _rekor) do
    # TODO: Verify Sigstore bundle
    :ok
  end

  defp generate_spdx_sbom(opts) do
    name = Keyword.get(opts, :name, "gitvisor")
    version = Keyword.get(opts, :version, "0.1.0")

    """
    SPDXVersion: SPDX-2.3
    DataLicense: CC0-1.0
    SPDXID: SPDXRef-DOCUMENT
    DocumentName: #{name}
    DocumentNamespace: https://gitvisor.dev/spdx/#{name}-#{version}
    Creator: Tool: gitvisor-attestation
    Created: #{DateTime.to_iso8601(DateTime.utc_now())}

    PackageName: #{name}
    SPDXID: SPDXRef-Package
    PackageVersion: #{version}
    PackageDownloadLocation: https://github.com/hyperpolymath/gitvisor
    FilesAnalyzed: false
    PackageLicenseConcluded: (MIT OR AGPL-3.0-or-later)
    PackageLicenseDeclared: (MIT OR AGPL-3.0-or-later)
    PackageCopyrightText: NOASSERTION
    """
  end

  defp generate_cyclonedx_sbom(opts) do
    name = Keyword.get(opts, :name, "gitvisor")
    version = Keyword.get(opts, :version, "0.1.0")

    %{
      "bomFormat" => "CycloneDX",
      "specVersion" => "1.5",
      "serialNumber" => "urn:uuid:#{UUID.uuid4()}",
      "version" => 1,
      "metadata" => %{
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
        "tools" => [%{"name" => "gitvisor-attestation", "version" => "0.1.0"}],
        "component" => %{
          "type" => "application",
          "name" => name,
          "version" => version
        }
      },
      "components" => []
    }
    |> Jason.encode!()
  end
end
