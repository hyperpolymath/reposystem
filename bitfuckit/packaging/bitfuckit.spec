# SPDX-License-Identifier: PMPL-1.0
Name:           bitfuckit
Version:        0.1.0
Release:        1%{?dist}
Summary:        Bitbucket CLI tool written in Ada

License:        PMPL-1.0-or-later
URL:            https://github.com/hyperpolymath/bitfuckit
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc-gnat >= 12
BuildRequires:  gprbuild >= 22
Requires:       curl

%description
Bitbucket CLI tool written in Ada. They didn't make it, so I did.
Equivalent to GitHub's gh, GitLab's glab, or Codeberg's tea.

Features:
- Authentication with app passwords
- Repository CRUD operations
- GitHub to Bitbucket mirroring
- Interactive TUI mode

%prep
%autosetup

%build
gprbuild -P bitfuckit.gpr -XBUILD_MODE=release

%install
install -Dm755 bin/bitfuckit %{buildroot}%{_bindir}/bitfuckit
install -Dm644 doc/bitfuckit.1 %{buildroot}%{_mandir}/man1/bitfuckit.1
install -Dm644 completions/bitfuckit.bash %{buildroot}%{_datadir}/bash-completion/completions/bitfuckit
install -Dm644 completions/bitfuckit.zsh %{buildroot}%{_datadir}/zsh/site-functions/_bitfuckit
install -Dm644 completions/bitfuckit.fish %{buildroot}%{_datadir}/fish/vendor_completions.d/bitfuckit.fish

%files
%license LICENSE
%doc README.adoc
%{_bindir}/bitfuckit
%{_mandir}/man1/bitfuckit.1*
%{_datadir}/bash-completion/completions/bitfuckit
%{_datadir}/zsh/site-functions/_bitfuckit
%{_datadir}/fish/vendor_completions.d/bitfuckit.fish

%changelog
* Wed Dec 25 2025 hyperpolymath <hyperpolymath@users.noreply.github.com> - 0.1.0-1
- Initial release
