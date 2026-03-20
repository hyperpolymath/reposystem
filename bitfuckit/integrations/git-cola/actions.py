# SPDX-License-Identifier: PMPL-1.0
"""
git-cola custom actions for bitfuckit integration

Installation:
    mkdir -p ~/.config/git-cola/actions
    cp actions.py ~/.config/git-cola/actions/bitfuckit.py

Or add to your existing git-cola actions config.
"""

from cola import cmds
from cola.i18n import N_
import subprocess


class BitbucketCreatePR(cmds.Command):
    """Create a Bitbucket pull request for current branch."""

    @staticmethod
    def name():
        return N_('Bitbucket: Create PR')

    def do(self):
        branch = cmds.Interaction.current_branch()
        subprocess.run(['bitfuckit', 'pr', 'create', '--branch', branch])


class BitbucketListPRs(cmds.Command):
    """List Bitbucket pull requests."""

    @staticmethod
    def name():
        return N_('Bitbucket: List PRs')

    def do(self):
        result = subprocess.run(
            ['bitfuckit', 'pr', 'list'],
            capture_output=True,
            text=True
        )
        cmds.Interaction.information(
            N_('Bitbucket Pull Requests'),
            result.stdout
        )


class BitbucketMirror(cmds.Command):
    """Mirror repository to Bitbucket."""

    @staticmethod
    def name():
        return N_('Bitbucket: Mirror Repository')

    def do(self):
        repo_name = cmds.Interaction.current_repository_name()
        subprocess.run(['bitfuckit', 'mirror', repo_name])


class BitbucketPipelineStatus(cmds.Command):
    """Check Bitbucket pipeline status."""

    @staticmethod
    def name():
        return N_('Bitbucket: Pipeline Status')

    def do(self):
        result = subprocess.run(
            ['bitfuckit', 'pipeline', 'status'],
            capture_output=True,
            text=True
        )
        cmds.Interaction.information(
            N_('Bitbucket Pipeline'),
            result.stdout
        )


class BitbucketAuthStatus(cmds.Command):
    """Show Bitbucket authentication status."""

    @staticmethod
    def name():
        return N_('Bitbucket: Auth Status')

    def do(self):
        result = subprocess.run(
            ['bitfuckit', 'auth', 'status'],
            capture_output=True,
            text=True
        )
        cmds.Interaction.information(
            N_('Bitbucket Authentication'),
            result.stdout
        )


# Register actions
ACTIONS = [
    BitbucketCreatePR,
    BitbucketListPRs,
    BitbucketMirror,
    BitbucketPipelineStatus,
    BitbucketAuthStatus,
]
