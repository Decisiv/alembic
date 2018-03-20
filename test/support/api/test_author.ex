defmodule Alembic.TestAuthor do
  @moduledoc """
  A schema used in examples in `Alembic`
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset

  # Constants

  @optional_fields ~w()a
  @required_fields ~w(name)a
  @allowed_fields @optional_fields ++ @required_fields

  # Schema

  schema "authors" do
    field(:name, :string)

    has_many(:posts, Alembic.TestPost, foreign_key: :author_id)
    has_one(:profile, Alembic.TestProfile, foreign_key: :author_id)
  end

  # Functions

  def changeset(changeset = %Changeset{data: %__MODULE__{}}) do
    changeset
    |> validate_length(:name, min: 2)
    |> validate_required(@required_fields)
  end

  def changeset(data, params) do
    data
    |> cast(params, @allowed_fields)
    |> changeset()
  end
end
