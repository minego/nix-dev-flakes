#!/usr/bin/env bash

function a() {
	echo $#

	A=$1; shift
	B=$1; shift
	echo "A: $A, B: $B, #: $#"
}

a $@
exit $?
