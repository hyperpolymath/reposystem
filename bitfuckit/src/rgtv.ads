-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- RGTV (Reasonably Good Token Vault) integration for bitfuckit.
--
-- Provides credential lookup via the Svalinn CLI (svalinn-cli),
-- the command-line interface to the Reasonably Good Token Vault.
-- RGTV stores credentials in a post-quantum encrypted, formally
-- verified vault with GUID-based fragment storage.
--
-- Credential lookup is performed by host (bitbucket.org) using
-- the 'svalinn-cli get-by-host' command. If the vault is locked,
-- unavailable, or the credential is not found, the lookup returns
-- No_Credentials so the caller can fall back to other sources.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package RGTV is

   -- -----------------------------------------------------------------------
   -- Types
   -- -----------------------------------------------------------------------

   -- Credential source provenance, so callers know where creds came from
   type Credential_Source is
     (Source_RGTV,           -- Svalinn vault (preferred)
      Source_Environment,    -- Environment variables
      Source_Config_File,    -- ~/.config/bitfuckit/config
      Source_Netrc,          -- ~/.netrc
      Source_None);          -- No credentials found

   -- -----------------------------------------------------------------------
   -- RGTV availability
   -- -----------------------------------------------------------------------

   -- Check whether the svalinn-cli binary is on PATH
   function Is_Available return Boolean;

   -- Check whether the vault is unlocked and ready for queries
   function Is_Unlocked return Boolean;

   -- -----------------------------------------------------------------------
   -- Credential lookup
   -- -----------------------------------------------------------------------

   -- Look up Bitbucket credentials from the Svalinn vault.
   -- Searches for identities stored against the host "bitbucket.org".
   -- Returns Config.No_Credentials if RGTV is unavailable, the vault
   -- is locked, or no matching identity is found.
   function Lookup_Credentials return Config.Credentials;

   -- -----------------------------------------------------------------------
   -- Cascaded credential resolution
   -- -----------------------------------------------------------------------

   -- Resolve credentials using the full cascade:
   --   1. RGTV (Svalinn vault)
   --   2. Environment variables (BITBUCKET_USERNAME, BITBUCKET_API_TOKEN,
   --      BITBUCKET_WORKSPACE)
   --   3. ~/.config/bitfuckit/config
   --   4. ~/.netrc (machine bitbucket.org)
   --
   -- Returns the first complete set of credentials found, along with
   -- the source they came from.
   procedure Resolve_Credentials
     (Creds  : out Config.Credentials;
      Source : out Credential_Source);

   -- Human-readable label for a credential source
   function Source_Label (S : Credential_Source) return String;

end RGTV;
