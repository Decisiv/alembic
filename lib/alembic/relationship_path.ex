defmodule Alembic.RelationshipPath do
  @moduledoc """
  > A relationship path is a dot-separated (U+002E FULL-STOP, ".") list of relationship names.
  >
  > -- [JSON API > Fetching Data > Inclusion Of Related Resources](http://jsonapi.org/format/#fetching-includes)
  """

  alias Alembic.Fetch.Includes


  # Types

  @typedoc """
  **NOTE: Kept as a string until application can validate relationship name.**

  The name of a relationship.
  """
  @type relationship_name :: String.t

  @typedoc """
  > A relationship path is a dot-separated (U+002E FULL-STOP, ".") list of relationship names.
  >
  > -- [JSON API > Fetching Data > Inclusion Of Related Resources](http://jsonapi.org/format/#fetching-includes)
  """
  @type t :: String.t

  # Functions

  @doc """
  Separator for `relationship_names` in a `relationship_path`
  """
  def relationship_name_separator, do: "."

  @doc false

  @spec reverse_relationship_names_to_include([]) :: nil
  def reverse_relationship_names_to_include([]), do: nil

  @spec reverse_relationship_names_to_include([relationship_name, ...]) :: Includes.include
  def reverse_relationship_names_to_include(reverse_relationship_names) do
    Enum.reduce reverse_relationship_names, fn (relationship_name, include) ->
      %{relationship_name => include}
    end
  end

  @doc """
  Breaks the `relationship_path` into `relationship_name`s in a nested map to form
  `Alembic.Fetch.Include.include`

  A relationship name passes through unchanged

      iex> Alembic.RelationshipPath.to_include("comments")
      "comments"

  A relationship path becomes a (nested) map

      iex> Alembic.RelationshipPath.to_include("comments.author.posts")
      %{
        "comments" => %{
          "author" => "posts"
        }
      }

  """
  @spec to_include(t) :: Includes.include | nil
  def to_include(relationship_path) do
    relationship_path
    |> String.split(relationship_name_separator)
    |> Enum.reverse
    |> reverse_relationship_names_to_include()
  end
end
