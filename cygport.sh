#!/bin/sh

test -r Packages.gz &&
test -r Sources.gz || 
exit 1

7<<-REC \
0<<-'BASH' \
bash
	%rec: Package
	%key: Package
	%type: Source rec Source
	%type: Binary rec Binary

	Package: $1
	Source: $1
	Binary: $1

	%rec: Binary
	%key: Package

	$(
		<Packages.gz gunzip |
		sed /^Package:\ $1$/,/^$/\!d |
		sed -z s/\\\x0a\\\x0a/\\x00/ |
		sed -z /Extra-Source/d |
		sed s/\\\x00//
	)

	%rec: Source
	%key: Package

	$(
		<Sources.gz gunzip |
		sed /^Package:\ $1$/,/^$/\!d |
		sed -z s/\\\x0a\\\x0a/\\x00/ |
		sed -z /Extra-Source/d |
		sed s/\\\x00//
	)

REC
	enable -f /usr/lib/recutils/bash-builtins/readrec.so readrec || exit 1
	{
		coproc { cat; }
		exec 3<&${COPROC[0]}- 4<&${COPROC[1]}-
		coproc { cat; }
		exec 5<&${COPROC[0]}- 6<&${COPROC[1]}-

		tr _- ^_ <&7 |
		sed s/^\ /\+\ / |
		tee >(cat >&4) > >(cat >&6) &
		exec 4<&- 6<&-
		recsel -p \
			$(
				paste -s -d, <<-'FIELDS'
					Binary_Package
					Binary_Version
					Binary_Section
					Binary_Depends
					Source_Architecture
					Source_Directory
					Source_Files
					Source_Build_Depends_Indep
					Binary_Description
				FIELDS
			) \
		<<-REC
			$( recsel -t Package -j Binary <&3 )
			$( recsel -t Package -j Source <&5 )
		REC
		wait
	} |
	while readrec
	do
		tr ^_ _- <<-CYGPORT
			# THIS IS A GENERATED CYGPORT FILE 
			NAME="$Binary_Package"
			VERSION="$(tr : % <<<${Binary_Version})"
			RELEASE=1
			CATEGORY="$Binary_Section"
			SUMMARY="$(head -n1 <<<${Binary_Description})"
			DESCRIPTION="$(tail -n+2 <<<${Binary_Description})"
			HOMEPAGE="http://sourceware.org/cygwinports/"
			SRC^URI="$(
				cut -d\  -f3 <<<${Source_Files} |
				grep . |
				sed "s%^%http://ftp.debian.org/debian/${Source_Directory}/%" |
				paste -s -d' '
			)"
			SRC^DIR="."
			PATCH^URI="$(
				tr _^ -_ <<<${Binary_Package} |
				xargs -r -I@ find -maxdepth 1 -type f -name '@.patch'
			)"
			DEBEMAIL="user@example.com"
			DEBFULLNAME="Firstname Lastname"
			# DEBUILD_DPKG_BUILDPACKAGE_OPTS="--force-sign --sign-key=0000000000000000"

			# this package contains no compiled Cygwin binaries
			# REMOVE THE FOLLOWING LINE for packages which are to be compiled for each arch
			ARCH="$(
				<<<"${Source_Architecture}" \
				sed -e /any/s/.*/i686/ -e /all/s/.*/noarch/
			)"

			$( 
				tr _? -_ <<-DEPS |
					${Source_Build_Depends_Indep}
					${Binary_Depends}
				DEPS
				perl 9<&0 0<<-'PERL'
					use Dpkg::Deps;
					open(STDIN, '<&=', 9);
					local @_=<>;
					chomp @_;
					print <<~DEPS
						# Build dependencies only
						DEPEND="@{[join ' ', map { $_->{package} } @{deps_parse($_[0])->{list}}]}"

						# runtime deps to go in setup.hint, and note the escaped newline
						REQUIRES="@{[join ' ', map { $_->{package} } @{deps_parse($_[1])->{list}}]}"
						DEPS
				PERL
			)

			inherit dpkg
		CYGPORT
	done 
BASH
