defmodule Alembic.Document do
  @moduledoc """
  JSON API refers to the top-level JSON structure as a [document](http://jsonapi.org/format/#document-structure).
  """

  alias Alembic.{
    Error,
    Errors,
    FromJson,
    Links,
    Meta,
    Pagination,
    Resource,
    ResourceLinkage,
    Source,
    ToEctoSchema,
    ToParams
  }

  # Behaviours

  @behaviour FromJson
  @behaviour ToEctoSchema
  @behaviour ToParams
  @behaviour Pagination

  # Constants

  @data_options %{
    field: :data,
    member: %{
      module: ResourceLinkage,
      name: "data"
    }
  }

  @errors_options %{
    field: :errors,
    member: %{
      name: "errors"
    }
  }

  @included_options %{
    field: :included,
    member: %{
      name: "included"
    }
  }

  @human_type "document"

  @links_options %{
    field: :links,
    member: %{
      module: Links,
      name: "links"
    }
  }

  @minimum_children ~w{data errors meta}

  @meta_options %{
    field: :meta,
    member: %{
      module: Meta,
      name: "meta"
    }
  }

  # DOES NOT include `@errors_options` because `&FromJson.from_json_array(&1, &2, Error)` cannot appear in a module
  #   attribute used in a function
  # DOES NOT include `@included_options` because `&FromJson.from_json_array(&1, &2, Resource)` cannot appear in a module
  #   attribute used in a function
  @child_options_list [
    @data_options,
    @links_options,
    @meta_options
  ]

  # Struct

  defstruct data: :unset,
            errors: nil,
            included: nil,
            jsonapi: nil,
            links: nil,
            meta: nil

  # Types

  @typedoc """
  A JSON API [Document](http://jsonapi.org/format/#document-structure).

  ## Data

  When there are no errors, `data` are returned in the document and `errors` are not returned in the document.

  | Field      | Included/Excluded/Optional |
  |------------|----------------------------|
  | `data`     | Included                   |
  | `errors`   | Excluded                   |
  | `included` | Optional                   |
  | `links`    | Optional                   |
  | `meta`     | Optional                   |

  ## Errors

  When an error occurs, `errors` are returned in the document and `data` are not returned in the document.

  | Field      | Included/Excluded/Optional |
  |------------|----------------------------|
  | `data`     | Excluded                   |
  | `errors`   | Included                   |
  | `included` | Excluded                   |
  | `links`    | Optional                   |
  | `meta`     | Optional                   |

  ## Meta

  JSON API allows a `meta` only document, in which case `data` and `errors` are not returned in the document.

  | Field      | Included/Excluded/Optional |
  |------------|----------------------------|
  | `data`     | Excluded                   |
  | `errors`   | Excluded                   |
  | `included` | Excluded                   |
  | `links`    | Optional                   |
  | `meta`     | Included                   |

  """
  @type t :: %__MODULE__{
               data: :unset,
               errors: [Error.t],
               included: nil,
               links: Links.t | nil,
               meta: Meta.t | nil
             } |
             %__MODULE__{
               data: :unset,
               errors: nil,
               included: nil,
               links: Links.t | nil,
               meta: Meta.t
             } |
             %__MODULE__{
               data: [Resource.t] | Resource.t | nil,
               errors: nil,
               included: [Resource.t] | nil,
               links: Links.t | nil,
               meta: Meta.t | nil
             }

  # Functions

  @doc """
  Tries to determine the common `Alembic.Error.t` `status` between all `errors` in the `document`.

  If it is not an errors document, `nil` is returned.

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{data: []}
      ...> )
      nil

  # Single error

  If there is one error, its status is returned.  This could be nil as no field is required in a JSONAPI error.

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{
      ...>         status: "404"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      "404"
      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{}
      ...>     ]
      ...>   }
      ...> )
      nil

  # Multiple errors

  If there are multiple errors with the same status, then that is the consensus

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{
      ...>         status: "404"
      ...>       },
      ...>       %Alembic.Error{
      ...>         status: "404"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      "404"

  If there are multiple errors, but some errors don't have statuses, they are ignored

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{},
      ...>       %Alembic.Error{
      ...>         status: "404"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      "404"

  If there are multiple errors, but they disagree within the same 100s block, then that is the consensus

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{
      ...>         status: "404"
      ...>       },
      ...>       %Alembic.Error{
      ...>         status: "422"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      "400"

  If there are multiple errors, but they disagree without the same 100s block, then the greater 100s block is the
  consensus

      iex> Alembic.Document.error_status_consensus(
      ...>   %Alembic.Document{
      ...>     errors: [
      ...>       %Alembic.Error{
      ...>         status: "422"
      ...>       },
      ...>       %Alembic.Error{
      ...>         status: "500"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      "500"

  """
  def error_status_consensus(%__MODULE__{errors: nil}), do: nil

  def error_status_consensus(%__MODULE__{errors: errors}) do
    Enum.reduce errors, nil, fn
      %Error{status: status}, nil -> status
      %Error{status: status}, status -> status
      %Error{status: status}, consensus ->
        status_block_integer = div(String.to_integer(status), 100)
        consensus_block_integer = div(String.to_integer(consensus), 100)

        max_block_integer = max(status_block_integer, consensus_block_integer)
        to_string(max_block_integer * 100)
    end
  end

  @doc """
  Converts the `errors` in `ecto_changeset` to `Alembic.Error.t` in a single `t`.

  If only `:format_key` is given in the `options`, then the other keys for
  `t:Alembic.Source.ancestor_descendants_from_ecto_changeset_path_options/0` will be derived from the
  `ecto_schema_module` of the `changeset` `:data`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> changeset = Ecto.Changeset.change(%Alembic.TestAuthor{id: 1})
      iex> Document.from_ecto_changeset(
      ...>   %Ecto.Changeset{
      ...>     changeset
      ...>     | errors: [
      ...>         {:name, {"should be at least %{count} character(s)", [count: 2, validation: :length, min: 2]}},
      ...>         {:posts, {"are still associated with this entry", []}}
      ...>       ]
      ...>   },
      ...>   %{format_key: format_key}
      ...> )
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "name should be at least 2 character(s)",
            source: %Alembic.Source{
              pointer: "/data/attributes/name"
            },
            title: "should be at least 2 character(s)"
          },
          %Alembic.Error{
            detail: "posts are still associated with this entry",
            source: %Alembic.Source{
              pointer: "/data/relationships/posts"
            },
            title: "are still associated with this entry"
          }
        ]
      }

  If the `ecto_changeset` `data` is not an `Ecto.Schema.t` struct and `__schema__/1` reflection functions are not
  supported, then you can bypass the reflection by giving the
  `t:Alembic.Source.ancestor_descendants_from_ecto_changeset_path_options/0` explicitly.  You'll also need to supply the
  `types` in `Ecto.Changeset.t` `types` key.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Document.from_ecto_changeset(
      ...>   %Ecto.Changeset{
      ...>     data: %{id: 1},
      ...>     errors: [
      ...>       {:name, {"should be at least %{count} character(s)", [count: 2, validation: :length, min: 2]}},
      ...>       {:posts, {"are still associated with this entry", []}}
      ...>     ],
      ...>     types: %{
      ...>       id: :id,
      ...>       name: :string,
      ...>       posts: {:assoc,
      ...>         %Ecto.Association.Has{
      ...>           cardinality: :many,
      ...>           field: :posts,
      ...>           on_delete: :nothing,
      ...>           on_replace: :raise,
      ...>           owner: Alembic.TestAuthor,
      ...>           owner_key: :id,
      ...>           queryable: Alembic.TestPost,
      ...>           related: Alembic.TestPost,
      ...>           related_key: :author_id,
      ...>           relationship: :child
      ...>         }},
      ...>       profile: {:assoc,
      ...>         %Ecto.Association.Has{
      ...>           cardinality: :one,
      ...>           field: :profile,
      ...>           on_delete: :nothing,
      ...>           on_replace: :raise,
      ...>           owner: Alembic.TestAuthor,
      ...>           owner_key: :id,
      ...>           queryable: Alembic.TestProfile,
      ...>           related: Alembic.TestProfile,
      ...>           related_key: :author_id,
      ...>           relationship: :child,
      ...>           unique: true
      ...>         }}
      ...>     }
      ...>   },
      ...>   %{
      ...>     association_set: MapSet.new([:posts]),
      ...>     association_by_foreign_key: %{},
      ...>     attribute_set: MapSet.new([:name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "name should be at least 2 character(s)",
            source: %Alembic.Source{
              pointer: "/data/attributes/name"
            },
            title: "should be at least 2 character(s)"
          },
          %Alembic.Error{
            detail: "posts are still associated with this entry",
            source: %Alembic.Source{
              pointer: "/data/relationships/posts"
            },
            title: "are still associated with this entry"
          }
        ]
      }

  ## Nested Errors

  Errors on nested associations and embeds are traversed and the nested JSON pointer calculated

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> post_changeset = Alembic.TestPost.changeset(%Alembic.TestPost{}, %{"text" => "too short"})
      iex> author_changeset = Alembic.TestAuthor.changeset(%Alembic.TestAuthor{}, %{"name" => "A"})
      iex> changeset = Ecto.Changeset.put_assoc(post_changeset, :author, author_changeset)
      iex> Document.from_ecto_changeset(changeset, %{format_key: format_key})
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "author name should be at least 2 character(s)",
            source: %Alembic.Source{
              pointer: "/data/relationships/author/name"
            },
            title: "should be at least 2 character(s)"
          },
          %Alembic.Error{
            detail: "text should be at least 50 character(s)",
            source: %Alembic.Source{
              pointer: "/data/attributes/text"
            },
            title: "should be at least 50 character(s)"
          }
        ]
      }

  Errors on `*_many` associations have a 0-based index assigned in the JSON pointer

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> post_changeset = Alembic.TestPost.changeset(%Alembic.TestPost{}, %{"text" => "too short"})
      iex> comment_changeset = Alembic.TestComment.changeset(%Alembic.TestComment{}, %{})
      iex> changeset = Ecto.Changeset.put_assoc(post_changeset, :comments, [comment_changeset])
      iex> Document.from_ecto_changeset(changeset, %{format_key: format_key})
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "comments 0 text can't be blank",
            source: %Alembic.Source{
              pointer: "/data/relationships/comments/0/text"
            },
            title: "can't be blank"
          },
          %Alembic.Error{
            detail: "text should be at least 50 character(s)",
            source: %Alembic.Source{
              pointer: "/data/attributes/text"
            },
            title: "should be at least 50 character(s)"
          }
        ]
      }

  """
  @spec from_ecto_changeset(
          Ecto.Changeset.t(),
          Source.ancestor_descendants_from_ecto_changeset_path_options()
        ) :: t()
  def from_ecto_changeset(
        changeset = %Ecto.Changeset{},
        options = %{
          association_set: _,
          association_by_foreign_key: _,
          attribute_set: _,
          format_key: _
        }
      ) do
    errors = Errors.from_ecto_changeset(changeset, options)

    %__MODULE__{errors: errors}
  end

  @spec from_ecto_changeset(Ecto.Changeset.t(), %{required(:format_key) => (atom -> String.t())}) :: t
  def from_ecto_changeset(
        ecto_changeset = %Ecto.Changeset{data: %ecto_schema_module{}},
        options = %{format_key: _}
      ) do
    full_options =
      Map.merge(
        options,
        Source.ancestor_descendants_from_ecto_changeset_path_options_from_ecto_schema_module(ecto_schema_module)
      )

    from_ecto_changeset(ecto_changeset, full_options)
  end

  @doc """
  Converts a JSON object into a JSON API Document, `t`.

  ## Data documents

  ### Single

  An empty single resource can represented as `"data": null` in encoded JSON, so it comes into `from_json` as
  `data: nil`

      iex> Alembic.Document.from_json(
      ...>   %{ "data" => nil },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: nil
        }
      }

  A present single can be a resource

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "attributes" => %{
      ...>         "text" => "First Post!"
      ...>       },
      ...>       "id" => "1",
      ...>       "type" => "post"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :client
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: %Alembic.Resource{
            attributes: %{
              "text" => "First Post!"
            },
            id: "1",
            type: "post"
          }
        }
      }

  ... or a present single can be just a resource identifier

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "id" => "1",
      ...>       "type" => "post"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: %Alembic.ResourceIdentifier{
            id: "1",
            type: "post"
          }
        }
      }

  You notice that whether a JSON object in `"data"` is treated as a `Alembic.Resource.t` or
  `Alembic.ResourceIdentifier.t` hinges on whether `"attributes"` or `"relationships"` is present as those
  members are only allowed for resources.

  ### Collection

  #### Resources

  A collection can be a list of resources

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "attributes" => %{
      ...>           "text" => "First Post!"
      ...>         },
      ...>         "id" => "1",
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => [
      ...>               %{
      ...>                 "id" => "1",
      ...>                 "type" => "comment"
      ...>               }
      ...>             ]
      ...>           }
      ...>         },
      ...>         "type" => "post"
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :client
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: [
            %Alembic.Resource{
              attributes: %{
                "text" => "First Post!"
              },
              id: "1",
              relationships: %{
                "comments" => %Alembic.Relationship{
                  data: [
                    %Alembic.ResourceIdentifier{
                      id: "1",
                      type: "comment"
                    }
                  ]
                }
              },
              type: "post"
            }
          ]
        }
      }

  With `"relationships"`, a resources collection can optionally have `"included"` for the attributes for the resource
  identifiers.  If `"included"` is not given or the `"id"` and `"type"` for a resource identifier, then the resource
  identifier should just be considered a foreign key reference that needs to be fetched with another API query.

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "attributes" => %{
      ...>           "text" => "First Post!"
      ...>         },
      ...>         "id" => "1",
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => [
      ...>               %{
      ...>                 "id" => "1",
      ...>                 "type" => "comment"
      ...>               }
      ...>             ]
      ...>           }
      ...>         },
      ...>         "type" => "post"
      ...>       }
      ...>     ],
      ...>     "included" => [
      ...>       %{
      ...>         "attributes" => %{
      ...>           "text" => "First Comment!"
      ...>         },
      ...>         "id" => "1",
      ...>         "type" => "comment"
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :client
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: [
            %Alembic.Resource{
              attributes: %{
                "text" => "First Post!"
              },
              id: "1",
              relationships: %{
                "comments" => %Alembic.Relationship{
                  data: [
                    %Alembic.ResourceIdentifier{
                      id: "1",
                      type: "comment"
                    }
                  ]
                }
              },
              type: "post"
            }
          ],
          included: [
            %Alembic.Resource{
              attributes: %{
                "text" => "First Comment!"
              },
              id: "1",
              type: "comment"
            }
          ]
        }
      }

  #### Resource Identifiers

  Or a list of resource identifiers

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "id" => "1",
      ...>         "type" => "post"
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: [
            %Alembic.ResourceIdentifier{
              id: "1",
              type: "post"
            }
          ]
        }
      }

  #### Empty

  An empty collection can be signified with `[]`.  Because there is no type information, it's not possible to tell
  whether it is an empty list of `Alembic.Resource.t` or `Alembic.ResourceIdentifier.t`.

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => []
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          data: []
        }
      }

  ## Errors documents

  Errors from the sender must have an `"errors"` key set to a list of errors.

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "errors" => [
      ...>       %{
      ...>         "code" => "1",
      ...>         "detail" => "There was an error in data",
      ...>         "id" => "2",
      ...>         "links" => %{
      ...>           "about" => %{
      ...>             "href" => "/errors/2",
      ...>             "meta" => %{
      ...>               "extra" => "about meta"
      ...>             }
      ...>           }
      ...>         },
      ...>         "meta" => %{
      ...>           "extra" => "error meta"
      ...>         },
      ...>         "source" => %{
      ...>           "pointer" => "/data"
      ...>         },
      ...>         "status" => "422",
      ...>         "title" => "There was an error"
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              code: "1",
              detail: "There was an error in data",
              id: "2",
              links: %{
                "about" => %Alembic.Link{
                  href: "/errors/2",
                  meta: %{
                    "extra" => "about meta"
                  }
                }
              },
              meta: %{
                "extra" => "error meta"
              },
              source: %Alembic.Source{
                pointer: "/data"
              },
              status: "422",
              title: "There was an error"
            }
          ]
        }
      }

  Error objects **MUST** be returned as an *array* keyed by `"errors"` in the top level of a JSON API document.

      iex> Alembic.Document.from_json(
      ...>   %{"errors" => "Lots of errors"},
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/errors` type is not array",
              meta: %{
                "type" => "array"
              },
              source: %Alembic.Source{
                pointer: "/errors"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ## Meta documents

  Returned documents can contain just `"meta"` with neither `"data"` nor `"errors"`

      iex> Alembic.Document.from_json(
      ...>   %{
      ...>     "meta" => %{
      ...>       "copyright" => "2016"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Document{
          meta: %{
            "copyright" => "2016"
          }
        }
      }

  ## Incomplete documents

  If neither `"errors"`, `"data"`, nor `"meta"` is present, then the document is invalid and an `:error` tuple will be
  returned.  In the tuple with `:error` is an `Alembic.Document.t` that is a proper JSONAPI errors document that can
  be set back to the sender.

      iex> Alembic.Document.from_json(
      ...>   %{},
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "At least one of the following children of `` must be present:\\n" <>
                      "data\\n" <>
                      "errors\\n" <>
                      "meta",
              meta: %{
                "children" => [
                  "data",
                  "errors",
                  "meta"
                ]
              },
              source: %Alembic.Source{
                pointer: ""
              },
              status: "422",
              title: "Not enough children"
            }
          ],
        }
      }

  """
  def from_json(json, error_template)

  def from_json(json = %{}, error_template) do
    parent = %{error_template: error_template, json: json}

    child_options_list()
    |> Stream.map(&Map.put(&1, :parent, parent))
    |> Stream.map(&FromJson.from_parent_json_to_field_result/1)
    |> FromJson.reduce({:ok, %__MODULE__{}})
    |> validate_minimum_children(json, error_template)
  end

  def from_json(_, error_template) do
    {
      :error,
      %__MODULE__{
        errors: [
          Error.type(error_template, @human_type)
        ]
      }
    }
  end

  @doc """
  Lookup table of `included` resources, so that `Alembic.ResourceIdentifier.t` can be
  converted to full `Alembic.Resource.t`.

  ## No included resources

  With no included resources, an empty map is returned

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "type" => "post",
      ...>       "id" => "1"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      ...> Alembic.Document.included_resource_by_id_by_type(document)
      %{}

  ## Included resources

  With included resources, a nest map is built with the outer layer keyed by the `Alembic.Resource.type`,
  then the next layer keyed by the `Alembic.Resource.id` with the values being the full
  `Alembic.Resource.t`

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "type" => "articles",
      ...>         "id" => "1",
      ...>         "relationships" => %{
      ...>           "author" => %{
      ...>             "data" => %{
      ...>               "type" => "people",
      ...>               "id" => "9"
      ...>             }
      ...>           },
      ...>           "comments" => %{
      ...>             "data" => [
      ...>               %{
      ...>                 "type" => "comments",
      ...>                 "id" => "5"
      ...>               },
      ...>               %{
      ...>                 "type" => "comments",
      ...>                 "id" => "12"
      ...>               }
      ...>             ]
      ...>           }
      ...>         }
      ...>       }
      ...>     ],
      ...>     "included" => [
      ...>       %{
      ...>         "type" => "people",
      ...>         "id" => "9",
      ...>         "attributes" => %{
      ...>           "first-name" => "Dan",
      ...>           "last-name" => "Gebhardt",
      ...>           "twitter" => "dgeb"
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "comments",
      ...>         "id" => "5",
      ...>         "attributes" => %{
      ...>           "body" => "First!"
      ...>         },
      ...>         "relationships" => %{
      ...>           "author" => %{
      ...>             "data" => %{
      ...>               "type" => "people",
      ...>               "id" => "2"
      ...>             }
      ...>           }
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "comments",
      ...>         "id" => "12",
      ...>         "attributes" => %{
      ...>           "body" => "I like XML better"
      ...>         },
      ...>         "relationships" => %{
      ...>           "author" => %{
      ...>             "data" => %{
      ...>               "type" => "people",
      ...>               "id" => "9"
      ...>             }
      ...>           }
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      ...> Alembic.Document.included_resource_by_id_by_type(document)
      %{
        "comments" => %{
          "12" => %Alembic.Resource{
            attributes: %{
              "body" => "I like XML better"
            },
            id: "12",
            relationships: %{
              "author" => %Alembic.Relationship{
                data: %Alembic.ResourceIdentifier{
                  id: "9",
                  type: "people"
                }
              }
            },
            type: "comments"
          },
          "5" => %Alembic.Resource{
            attributes: %{
              "body" => "First!"
            },
            id: "5",
            relationships: %{
              "author" => %Alembic.Relationship{
                data: %Alembic.ResourceIdentifier{
                  id: "2",
                  type: "people"
                }
              }
            },
            type: "comments"
          }
        },
        "people" => %{
          "9" => %Alembic.Resource{
            attributes: %{
              "first-name" => "Dan",
              "last-name" => "Gebhardt",
              "twitter" => "dgeb"
            },
            id: "9",
            type: "people"
          }
        }
      }

  """
  @spec included_resource_by_id_by_type(t) :: ToParams.resource_by_id_by_type

  def included_resource_by_id_by_type(%__MODULE__{included: nil}), do: %{}

  def included_resource_by_id_by_type(%__MODULE__{included: included}) do
    Enum.reduce(
      included,
      %{},
      fn (resource = %Resource{id: id, type: type}, resource_by_id_by_type) ->
        resource_by_id_by_type
        |> Map.put_new(type, %{})
        |> put_in([type, id], resource)
      end
    )
  end

  @doc """
  Merges the errors from two documents together.

  The errors from the second document are prepended to the errors of the first document so that the errors as a whole
  can be reversed with `reverse/1`
  """
  def merge(first, second)

  @spec merge(%__MODULE__{errors: [Error.t]}, %__MODULE__{errors: [Error.t]}) :: %__MODULE__{errors: [Error.t]}
  def merge(%__MODULE__{errors: first_errors}, %__MODULE__{errors: second_errors}) when is_list(first_errors) and
                                                                                        is_list(second_errors) do
    %__MODULE__{
      # Don't use Enum.into as it will reverse the list immediately, which is more reversing that necessary since
      # merge is called a bunch of time in sequence.
      errors: Enum.reduce(
        second_errors,
        first_errors,
        fn (second_error, acc_errors) ->
          [second_error | acc_errors]
        end
      )
    }
  end

  @doc """
  Since `merge/2` adds the second `errors` to the beginning of a `first` document's `errors` list, the final merged
  `errors` needs to be reversed to maintain the original order.

      iex> merged = %Alembic.Document{
      ...>   errors: [
      ...>     %Alembic.Error{
      ...>       detail: "The index `2` of `/data` is not a resource",
      ...>       source: %Alembic.Source{
      ...>         pointer: "/data/2"
      ...>       },
      ...>       title: "Element is not a resource"
      ...>     },
      ...>     %Alembic.Error{
      ...>       detail: "The index `1` of `/data` is not a resource",
      ...>       source: %Alembic.Source{
      ...>         pointer: "/data/1"
      ...>       },
      ...>       title: "Element is not a resource"
      ...>     }
      ...>   ]
      ...> }
      iex> Alembic.Document.reverse(merged)
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "The index `1` of `/data` is not a resource",
            source: %Alembic.Source{
              pointer: "/data/1"
            },
            title: "Element is not a resource"
          },
          %Alembic.Error{
            detail: "The index `2` of `/data` is not a resource",
            source: %Alembic.Source{
              pointer: "/data/2"
            },
            title: "Element is not a resource"
          }
        ]
      }

  """
  def reverse(document = %__MODULE__{errors: errors}) when is_list(errors) do
    %__MODULE__{document | errors: Enum.reverse(errors)}
  end

  @doc """
  Converts a document into one or more [`Ecto.Schema.t`](http://hexdocs.pm/ecto/Ecto.Schema.html#t:t/0) structs.

  ## Parameters
  * `document` - supplies resource attributes and associations (through `included`)
  * `ecto_schema_module_by_type` - Maps the `Alembic.Resource.t` `type` `String.t` to the `Ecto.Schema`
    module to use with [`Ecto.Changeset.cast/4`](http://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4).

  ## Returns
  * `{:ok, nil}` - an empty single resource
  * `{:ok, struct}` - a single resource
  * `{:ok, []}` - an empty resource collection
  * `{:ok, [struct]}` - a non-empty resource collection
  * `{:error, t}` - the `document` have errors and so won't be converted to struct(s).

  ## Examples

  ### No resource

  No resource has to return `nil` for Ecto schema because the type is not present.

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => nil
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_ecto_schema(document, %{})
      {:ok, nil}

  ### Single resource

  A single resource is converted to a single Ecto schema struct corresponding to the type.

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "attributes" => %{
      ...>         "name" => "Thing 1"
      ...>       },
      ...>       "id" => "1",
      ...>       "type" => "thing"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_ecto_schema(
      ...>   document,
      ...>   %{
      ...>     "thing" => Alembic.TestThing
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.TestThing{
          __meta__: %Ecto.Schema.Metadata{
            source: {nil, "things"},
            state: :built
          },
          id: 1,
          name: "Thing 1"
        }
      }

  #### Relationships

  Relationships are merged into the struct for the resource

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "attributes" => %{
      ...>         "name" => "Thing 1"
      ...>       },
      ...>       "relationships" => %{
      ...>         "shirt" => %{
      ...>           "data" => %{
      ...>             "attributes" => %{
      ...>               "size" => "L"
      ...>             },
      ...>             "type" => "shirt"
      ...>           }
      ...>         }
      ...>       },
      ...>       "type" => "thing"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :client
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_ecto_schema(
      ...>   document,
      ...>   %{
      ...>     "shirt" => Alembic.TestShirt,
      ...>     "thing" => Alembic.TestThing
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.TestThing{
          __meta__: %Ecto.Schema.Metadata{
            source: {nil, "things"},
            state: :built
          },
          name: "Thing 1",
          shirt: %Alembic.TestShirt{
            __meta__: %Ecto.Schema.Metadata{
              source: {nil, "shirts"},
              state: :built
            },
            size: "L"
          }
        }
      }

  ### Multiple resources

  Multiple resources are converted to a struct list where each element is a struct that combines the id and attributes

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "1",
      ...>         "attributes" => %{
      ...>           "text" => "Welcome"
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "2",
      ...>         "attributes" => %{
      ...>           "text" => "It's been awhile"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_ecto_schema(
      ...>   document,
      ...>   %{
      ...>     "post" => Alembic.TestPost
      ...>   }
      ...> )
      {
        :ok,
        [
          %Alembic.TestPost{
            __meta__: %Ecto.Schema.Metadata{
              source: {nil, "posts"},
              state: :built
            },
            author: %Ecto.Association.NotLoaded{
              __cardinality__: :one,
              __field__: :author,
              __owner__: Alembic.TestPost
            },
            author_id: nil,
            id: 1,
            text: "Welcome"
          },
          %Alembic.TestPost{
            __meta__: %Ecto.Schema.Metadata{
              source: {nil, "posts"},
              state: :built
            },
            author: %Ecto.Association.NotLoaded{
              __cardinality__: :one,
              __field__: :author,
              __owner__: Alembic.TestPost
            },
            author_id: nil,
            id: 2,
            text: "It's been awhile"
          }
        ]
      }

  #### Relationships

  Relationships are merged into the structs for the corresponding resource

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "1",
      ...>         "attributes" => %{
      ...>           "text" => "Welcome"
      ...>         },
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => [
      ...>               %{
      ...>                 "type" => "comment",
      ...>                 "id" => "3"
      ...>               }
      ...>             ]
      ...>           }
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "2",
      ...>         "attributes" => %{
      ...>           "text" => "It's been awhile"
      ...>         },
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => []
      ...>           }
      ...>         }
      ...>       }
      ...>     ],
      ...>     "included" => [
      ...>       %{
      ...>         "type" => "comment",
      ...>         "id" => "3",
      ...>         "attributes" => %{
      ...>           "text" => "First!"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_ecto_schema(
      ...>   document,
      ...>   %{
      ...>     "comment" => Alembic.TestComment,
      ...>     "post" => Alembic.TestPost
      ...>   }
      ...> )
      {
        :ok,
        [
          %Alembic.TestPost{
            __meta__: %Ecto.Schema.Metadata{
              source: {nil, "posts"},
              state: :built
            },
            author: %Ecto.Association.NotLoaded{
              __cardinality__: :one,
              __field__: :author,
              __owner__: Alembic.TestPost
            },
            author_id: nil,
            comments: [
              %Alembic.TestComment{
                __meta__: %Ecto.Schema.Metadata{
                  source: {nil, "comments"},
                  state: :built
                },
                id: 3,
                post: %Ecto.Association.NotLoaded{
                  __cardinality__: :one,
                  __field__: :post,
                  __owner__: Alembic.TestComment
                },
                post_id: nil,
                text: "First!"
              }
            ],
            id: 1,
            text: "Welcome"
          },
          %Alembic.TestPost{
            __meta__: %Ecto.Schema.Metadata{
              source: {nil, "posts"},
              state: :built
            },
            author: %Ecto.Association.NotLoaded{
              __cardinality__: :one,
              __field__: :author,
              __owner__: Alembic.TestPost
            },
            author_id: nil,
            comments: [],
            id: 2,
            text: "It's been awhile"
          }
        ]
      }

  """
  @spec to_ecto_schema(%__MODULE__{}, %{String.t => module}) :: {:ok, nil | struct | [] | [struct]} | {:error, t}
  def to_ecto_schema(document = %__MODULE__{errors: errors}, %{}) when not is_nil(errors) do
    {:error, document}
  end

  def to_ecto_schema(%__MODULE__{data: nil}, %{}), do: {:ok, nil}
  def to_ecto_schema(%__MODULE__{data: []}, %{}), do: {:ok, []}

  def to_ecto_schema(document = %__MODULE__{}, ecto_schema_module_by_type) do
    {:ok, to_ecto_schema(document, included_resource_by_id_by_type(document), ecto_schema_module_by_type)}
  end

  @doc """
  Call `to_ecto_schema/2` instead to automatically generate `attributes_by_id_by_type`
  """
  @spec to_ecto_schema(
          %__MODULE__{data: [Resource.t] | Resource.t},
          ToParams.resource_by_id_by_type,
          ToEctoSchema.ecto_schema_module_by_type
        ) :: [struct] | struct

  def to_ecto_schema(
        %__MODULE__{data: resource = %Resource{}},
        resource_by_id_by_type,
        ecto_schema_module_by_type
      ) do
    Resource.to_ecto_schema(resource, resource_by_id_by_type, ecto_schema_module_by_type)
  end

  def to_ecto_schema(
        %__MODULE__{data: resources},
        resource_by_id_by_type,
        ecto_schema_module_by_type
      ) when is_list(resources) do
    Enum.map resources, &Resource.to_ecto_schema(&1, resource_by_id_by_type, ecto_schema_module_by_type)
  end

  @doc """
  Extract paged pagination information.

  To support pagination, a document at minimum must have a `"record_count"` `meta` entry.

      iex> Alembic.Document.to_pagination(
      ...>   %Alembic.Document{meta: %{ "record_count" => 10 }}
      ...> )
      %Alembic.Pagination{ total_size: 10 }

  Without it, the `"record_count"` `meta` entry, the pagination will be `nil`

      iex> Alembic.Document.to_pagination(%Alembic.Document{})
      nil

  ## Single Page

  When there is only one page, there will be a `"first"` and `"last"` link pointing to the same page, but no
  "next" or "prev" links.  The `total_size` as given by the `meta` `"record_count"` will between `0` and
  the page size because the last is not necessarily full.

      iex> Alembic.Document.to_pagination(
      ...>   %Alembic.Document{
      ...>     links: %{
      ...>       "first" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10",
      ...>       "last" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10"
      ...>     },
      ...>     meta: %{ "record_count" => 5 }
      ...>   }
      ...> )
      %Alembic.Pagination{
        first: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        last: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        total_size: 5
      }

  ## Multiple Pages

  When there are multiple pages, every page will have a `"first"` and `"last"` link pointing to the respective,
  different pages.  The `total_size` as given by the `meta` `"record_count"` will be between
  `(last.number - 1)  * last.size` and  `last.number * last.size` because the last page is not necessarily full.

  On the first page, the `"next"` link will be set, but not the `"prev"` link.

      iex> Alembic.Document.to_pagination(
      ...>   %Alembic.Document{
      ...>     links: %{
      ...>       "first" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10",
      ...>       "last" => "https://example.com/api/v1/users?page%5Bnumber%5D=3&page%5Bsize%5D=10",
      ...>       "next" => "https://example.com/api/v1/users?page%5Bnumber%5D=2&page%5Bsize%5D=10"
      ...>     },
      ...>     meta: %{ "record_count" => 25 }
      ...>   }
      ...> )
      %Alembic.Pagination{
        first: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        last: %Alembic.Pagination.Page{
          number: 3,
          size: 10
        },
        next: %Alembic.Pagination.Page{
          number: 2,
          size: 10
        },
        total_size: 25
      }

  On any middle page, both the `"next"` and `"prev"` links will be set.

      iex> Alembic.Document.to_pagination(
      ...>   %Alembic.Document{
      ...>     links: %{
      ...>       "first" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10",
      ...>       "last" => "https://example.com/api/v1/users?page%5Bnumber%5D=3&page%5Bsize%5D=10",
      ...>       "next" => "https://example.com/api/v1/users?page%5Bnumber%5D=3&page%5Bsize%5D=10",
      ...>       "prev" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10"
      ...>     },
      ...>     meta: %{ "record_count" => 25 }
      ...>   }
      ...> )
      %Alembic.Pagination{
        first: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        last: %Alembic.Pagination.Page{
          number: 3,
          size: 10
        },
        next: %Alembic.Pagination.Page{
          number: 3,
          size: 10
        },
        previous: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        total_size: 25
      }

  On the last page, the `"prev"` link will be set, but not the `"next"` link.

      iex> Alembic.Document.to_pagination(
      ...>   %Alembic.Document{
      ...>     links: %{
      ...>       "first" => "https://example.com/api/v1/users?page%5Bnumber%5D=1&page%5Bsize%5D=10",
      ...>       "last" => "https://example.com/api/v1/users?page%5Bnumber%5D=3&page%5Bsize%5D=10",
      ...>       "prev" => "https://example.com/api/v1/users?page%5Bnumber%5D=2&page%5Bsize%5D=10"
      ...>     },
      ...>     meta: %{ "record_count" => 25 }
      ...>   }
      ...> )
      %Alembic.Pagination{
        first: %Alembic.Pagination.Page{
          number: 1,
          size: 10
        },
        last: %Alembic.Pagination.Page{
          number: 3,
          size: 10
        },
        previous: %Alembic.Pagination.Page{
          number: 2,
          size: 10
        },
        total_size: 25
      }

  """
  @spec to_pagination(t) :: Pagination.t | nil

  def to_pagination(
        %__MODULE__{
          links: links,
          meta: %{
            "record_count" => total_size
          }
        }
      ) do
    document_pagination = %Pagination{total_size: total_size}

    case Links.to_pagination(links) do
      nil ->
        document_pagination
      %Pagination{first: first, last: last, next: next, previous: previous} ->
        %{document_pagination | first: first, last: last, next: next, previous: previous}
    end
  end

  def to_pagination(%__MODULE__{}), do: nil

  @doc """
  Transforms a `t` into the nested params format used by
  [`Ecto.Changeset.cast/4`](http://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4).

  ## No resource

  No resource is transformed to an empty map

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => nil
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_params(document)
      %{}

  ## Single resource

  A single resource is converted to a params map that combines the id and attributes.

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "attributes" => %{
      ...>         "name" => "Thing 1"
      ...>       },
      ...>       "id" => "1",
      ...>       "type" => "thing"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_params(document)
      %{
        "id" => "1",
        "name" => "Thing 1"
      }

  ### Relationships

  Relationships are merged into the params for the resource

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => %{
      ...>       "attributes" => %{
      ...>         "name" => "Thing 1"
      ...>       },
      ...>       "id" => "1",
      ...>       "relationships" => %{
      ...>         "shirt" => %{
      ...>           "data" => %{
      ...>             "attributes" => %{
      ...>               "size" => "L"
      ...>             },
      ...>             "type" => "shirt"
      ...>           }
      ...>         }
      ...>       },
      ...>       "type" => "thing"
      ...>     }
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :create,
      ...>       "sender" => :client
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_params(document)
      %{
        "id" => "1",
        "name" => "Thing 1",
        "shirt" => %{
          "size" => "L"
        }
      }

  ## Multiple resources

  Multiple resources are converted to a params list where each element is a map that combines the id and attributes

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "1",
      ...>         "attributes" => %{
      ...>           "text" => "Welcome"
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "2",
      ...>         "attributes" => %{
      ...>           "text" => "It's been awhile"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_params(document)
      [
        %{
          "id" => "1",
          "text" => "Welcome"
        },
        %{
          "id" => "2",
          "text" => "It's been awhile"
        }
      ]

  ### Relationships

  Relationships are merged into the params for the corresponding resource

      iex> {:ok, document} = Alembic.Document.from_json(
      ...>   %{
      ...>     "data" => [
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "1",
      ...>         "attributes" => %{
      ...>           "text" => "Welcome"
      ...>         },
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => [
      ...>               %{
      ...>                 "type" => "comment",
      ...>                 "id" => "1"
      ...>               }
      ...>             ]
      ...>           }
      ...>         }
      ...>       },
      ...>       %{
      ...>         "type" => "post",
      ...>         "id" => "2",
      ...>         "attributes" => %{
      ...>           "text" => "It's been awhile"
      ...>         },
      ...>         "relationships" => %{
      ...>           "comments" => %{
      ...>             "data" => []
      ...>           }
      ...>         }
      ...>       }
      ...>     ],
      ...>     "included" => [
      ...>       %{
      ...>         "type" => "comment",
      ...>         "id" => "1",
      ...>         "attributes" => %{
      ...>           "text" => "First!"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   %Alembic.Error{
      ...>     meta: %{
      ...>       "action" => :fetch,
      ...>       "sender" => :server
      ...>     },
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   }
      ...> )
      iex> Alembic.Document.to_params(document)
      [
        %{
          "id" => "1",
          "text" => "Welcome",
          "comments" => [
            %{
              "id" => "1",
              "text" => "First!"
            }
          ]
        },
        %{
          "id" => "2",
          "text" => "It's been awhile",
          "comments" => []
        }
      ]

  """
  @spec to_params(t) :: [map] | map
  def to_params(document = %__MODULE__{}) do
    resource_by_id_by_type = included_resource_by_id_by_type(document)
    to_params(document, resource_by_id_by_type, %{})
  end

  @doc """
  Transforms a `t` into the nested params format used by
  [`Ecto.Changeset.cast/4`](http://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4) using the given
  `resources_by_id_by_type`.

  See `Alembic.Document.to_params/1`
  """
  @spec to_params(
          %__MODULE__{data: [Resource.t] | Resource.t | nil},
          ToParams.resource_by_id_by_type
        ) :: ToParams.params
  def to_params(document, resource_by_id_by_type), do: to_params(document, resource_by_id_by_type, %{})

  @doc """
  Transforms a `t` into the nested params format used by
  [`Ecto.Changeset.cast/4`](http://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4) using the given
  `resources_by_id_by_type` and `converted_by_id_by_type`.

  See `Alembic.Document.to_params/1`
  """
  @spec to_params(
          %__MODULE__{data: [Resource.t] | Resource.t | nil},
          ToParams.resource_by_id_by_type,
          ToParams.converted_by_id_by_type
        ) :: ToParams.params
  def to_params(%__MODULE__{data: data}, resource_by_id_by_type, converted_by_id_by_type) when is_list(data) do
    Enum.map(data, &Resource.to_params(&1, resource_by_id_by_type, converted_by_id_by_type))
  end

  def to_params(%__MODULE__{data: resource = %Resource{}}, resource_by_id_by_type, converted_by_id_by_type) do
    Resource.to_params(resource, resource_by_id_by_type, converted_by_id_by_type)
  end

  def to_params(%__MODULE__{data: nil}, _, _), do: %{}

  ## Private functions

  @spec child_options_list :: [map, ...]
  defp child_options_list do
    [errors_options(), included_options() | @child_options_list]
  end

  @spec errors_options :: map
  defp errors_options do
    put_in @errors_options[:member][:from_json], &FromJson.from_json_array(&1, &2, Error)
  end

  @spec included_options :: map
  defp included_options do
    put_in @included_options[:member][:from_json], &FromJson.from_json_array(&1, &2, Resource)
  end

  # Whether `json` has at least one of `"data"`, `"errors"`, `"meta"`
  @spec minimum_children?(Alembic.json_object) :: boolean
  defp minimum_children?(json), do: Enum.any? @minimum_children, &Map.has_key?(json, &1)

  @spec minimum_children_error(Error.t) :: FromJson.error
  defp minimum_children_error(error_template) do
    {
      :error,
      %__MODULE__{
        errors: [
          Error.minimum_children(error_template, @minimum_children)
        ]
      }
    }
  end

  @spec validate_minimum_children({:ok, t}, Alembic.json_object, Error.t) :: {:ok, t} | FromJson.error
  @spec validate_minimum_children({:error, t}, Alembic.json_object, Error.t) :: FromJson.error
  defp validate_minimum_children(collectable_result, json, error_template) do
    if minimum_children?(json) do
      collectable_result
    else
      FromJson.merge(collectable_result, minimum_children_error(error_template))
    end
  end

  # Protocol Implementations

  defimpl Poison.Encoder do
    @doc """
    ## Data

    A `nil` data is preserved as `"data": null` in JSON API represents an empty single resource as long as there aren't
    `errors`.

        iex> Poison.encode(
        ...>   %Alembic.Document{
        ...>     data: nil
        ...>   }
        ...> )
        {:ok, "{\\"data\\":null}"}

    ## Errors

    When there are `errors`, an `:unset` `data` is not encoded as `errors` are exclusive from `data`

        iex> Poison.encode(
        ...>   %Alembic.Document{
        ...>     data: :unset,
        ...>     errors: [
        ...>       %Alembic.Error{
        ...>         source: %Alembic.Source{
        ...>           pointer: ""
        ...>         }
        ...>       }
        ...>     ]
        ...>   }
        ...> )
        {:ok, "{\\"errors\\":[{\\"source\\":{\\"pointer\\":\\"\\"}}]}"}

    ## JSONAPI

    The JSONAPI version information can be set in the document and it will be encoded

        iex> Poison.encode(
        ...>   %Alembic.Document{
        ...>     jsonapi: %{
        ...>       "version" => "1.0"
        ...>     },
        ...>     data: nil
        ...>   }
        ...> )
        {:ok, "{\\"jsonapi\\":{\\"version\\":\\"1.0\\"},\\"data\\":null}"}

    ## Meta

    Since `"meta"` can be sent with either `"data"` or `"errors"` to get an encoding with only `"meta"`, you need
    to have data in its default value, `:unset`.

        iex> Poison.encode(
        ...>   %Alembic.Document{
        ...>     meta: %{
        ...>       "copyright" => "2016"
        ...>     }
        ...>   }
        ...> )
        {:ok, "{\\"meta\\":{\\"copyright\\":\\"2016\\"}}"}

    ## Invalid

    `"data"` and `"errors"` cannot exist in the same JSON API document, so they will fail to encode

        iex> try do
        ...>   Poison.encode(
        ...>     %Alembic.Document{
        ...>       data: [],
        ...>       errors: [
        ...>         %Alembic.Error{
        ...>           source: %Alembic.Source{
        ...>             pointer: ""
        ...>           }
        ...>         }
        ...>       ]
        ...>     }
        ...>   )
        ...> rescue
        ...>   e in ArgumentError -> e
        ...> end
        %ArgumentError{
           message: "`data` and `errors` is exclusive in JSON API, but both are set: data is `[]` and errors is " <>
                    "`[%Alembic.Error{code: nil, detail: nil, id: nil, links: nil, meta: nil, " <>
                    "source: %Alembic.Source{parameter: nil, pointer: \\"\\"}, " <>
                    "status: nil, title: nil}]`"
        }

    """

    def encode(%@for{data: data, errors: errors}, _) when data != :unset and not is_nil(errors) do
      raise ArgumentError,
            "`data` and `errors` is exclusive in JSON API, but both are set: data is `#{inspect data}` and errors " <>
            "is `#{inspect errors}`"
    end

    def encode(document = %@for{}, options) do
      # `data: nil` is allowed to be encoded as `"data": null` because `null` `"data"` is an empty single resource,
      # so data field being unset is signalled with `:unset`
      map = for {field, value} <- Map.from_struct(document),
                (field == :data && value != :unset) || (field != :data && value != nil),
                into: %{},
                do: {field, value}

      Poison.Encoder.Map.encode(map, options)
    end
  end
end
