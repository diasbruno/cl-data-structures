#!/bin/bash


sbcl --dynamic-space-size 8000 --no-sysinit --no-userinit --load run-tests.lisp --noinform
