#!/bin/bash

cpanm --installdeps --cpanfile cpan/default.cpanfile .
cpanm --installdeps --cpanfile cpan/development.cpanfile .
