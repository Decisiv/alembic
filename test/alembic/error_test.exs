defmodule Alembic.ErrorTest do
  @moduledoc """
  Runs doctests for `Alembic.Error`
  """

  use ExUnit.Case, async: true

  alias Alembic.{Error, FromJsonCase, Source}

  # Constants

  # Tests

  doctest Error

  test "conflicting -> Poison.encode -> Poison.decode -> from_json is idempotent" do
    %Error{
      source: %Source{
        pointer: "/errors/0/source"
      }
    }
    |> Error.conflicting(~w{parameter pointer})
    |> assert_idempotent
  end

  test "missing -> Poison.encode -> Poison.decode -> from_json is idempotent" do
    %Error{
      source: %Source{
        pointer: ""
      }
    }
    |> Error.missing("data")
    |> assert_idempotent
  end

  test "type -> Poison.encode -> Poison.decode -> from_json is idempotent" do
    %Error{
      source: %Source{
        pointer: "/errors"
      }
    }
    |> Error.type("array")
    |> assert_idempotent
  end

  # Private Functions

  defp assert_idempotent(original) do
    FromJsonCase.assert_idempotent error_template: %Error{
                                                     source: %Source{
                                                       pointer: "/errors/0"
                                                     }
                                                   },
                                   module: Error,
                                   original: original
  end
end
