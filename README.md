<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Alembic](#alembic)
  - [Installation](#installation)
  - [Contributing](#contributing)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Alembic

A JSONAPI 1.0 library fully-tested against all jsonapi.org examples.  The library generates JSONAPI errors documents whenever it encounters a malformed JSONAPI document, so that servers don't need to worry about JSONAPI format errors.  Poison.Encoder implementations ensure the structs can be turned back into JSON strings: struct->encoding->decoding->conversion to struct is tested to ensure idempotency and that the library can parse its own JSONAPI errors documents.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add alembic to your list of dependencies in `mix.exs`:

        def deps do
          [{:alembic, "~> 3.4", organization: "decisiv"}]
        end

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)
