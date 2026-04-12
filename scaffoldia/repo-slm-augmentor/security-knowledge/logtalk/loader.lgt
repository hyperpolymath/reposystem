% SPDX-License-Identifier: PMPL-1.0-or-later
% Logtalk loader for Security Knowledge Base
%
% Usage:
%   ?- logtalk_load(loader).
%   ?- security_error_catalog::get_critical_errors(E).
%   ?- security_error_catalog::get_sha_for_action('actions/checkout', 'v4.2.2', SHA).

:- initialization((
    logtalk_load([
        security_errors
    ])
)).
