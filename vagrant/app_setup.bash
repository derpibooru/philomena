#!/usr/bin/env bash

# Install Hex and Phoenix
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.4.3 --force

# Enter app dir
cd $1

# Install dependencies
mix deps.get
mix deps.compile

# Set up database
mix ecto.setup --force

# Install modules
(cd assets; npm install)
