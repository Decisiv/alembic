<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Changelog](#changelog)
  - [v3.4.0](#v340)
    - [Enhancements](#enhancements)
    - [Bug Fixes](#bug-fixes)
  - [v3.3.0](#v330)
    - [Enhancements](#enhancements-1)
    - [Bug Fixes](#bug-fixes-1)
  - [v3.2.0](#v320)
    - [Enhancements](#enhancements-2)
    - [Bug Fixes](#bug-fixes-2)
  - [v3.1.1](#v311)
    - [Bug Fixes](#bug-fixes-3)
  - [v3.1.0](#v310)
    - [Enhancements](#enhancements-3)
    - [Bug Fixes](#bug-fixes-4)
  - [v3.0.0](#v300)
    - [Enhancements](#enhancements-4)
    - [Bug Fixes](#bug-fixes-5)
    - [Incompatible Changes](#incompatible-changes)
  - [v2.4.0](#v240)
    - [Enhancements](#enhancements-5)
  - [v2.3.0](#v230)
    - [Enhancements](#enhancements-6)
    - [Bug Fixes](#bug-fixes-6)
  - [v2.2.0](#v220)
    - [Enhancements](#enhancements-7)
  - [v2.1.1](#v211)
    - [Bug Fixes](#bug-fixes-7)
  - [v2.1.0](#v210)
    - [Enhancements](#enhancements-8)
    - [Bug Fixes](#bug-fixes-8)
  - [v2.0.1](#v201)
    - [Bug Fixes](#bug-fixes-9)
  - [v2.0.0](#v200)
    - [Enhancements](#enhancements-9)
    - [Bug Fixes](#bug-fixes-10)
    - [Incompatible Changes](#incompatible-changes-1)
  - [v1.0.0](#v100)
    - [Enhancements](#enhancements-10)
    - [Incompatible Changes](#incompatible-changes-2)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Changelog

## v3.4.1
* [#52](https://github.com/C-S-D/alembic/pull/52) - [@KronicDeth](https://github.com/KronicDeth)
  * Remove references to `(InterpreterServer.)Api` that were leftover from when `Alembic` was open-sourced and extracted from `interpreter-server`.
    * Replace references to `Api.json_pointer` with `Alembic.json_pointer` as they couldn't be resolved and triggered an `Unknown Type: Elixir.Api.json_pointer` when dialyzer is used in dependent projects.

## v3.4.0

### Enhancements
* [#44](https://github.com/C-S-D/alembic/pull/44) - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.Document.from_ecto_changeset/2` converts the `errors` in `ecto_changeset` to `Alembic.Error.t` in a single `Alembic.Document.t`.  Bypasses a [bug in `JaSerializer`](https://github.com/vt-elixir/ja_serializer/blob/b5d9f1da736c3a9c6b42da34d35dafb7ce93879e/lib/ja_serializer/ecto_error_serializer.ex#L73-L81) where it assumes all fields that don't end in `_id` are attribute names, which leads to association names (as opposed to their foreign key) being put under `/data/attributes`.  `Alembic.Document.from_ecto_changeset` reflects on the `Ecto.Changeset.t` `data` struct module to get the `__schema__/1` information from the `Ecto.Schema.t`.  It also assumes that if the field maps to no known attribute, association or foreign key, then the error should not have an `Alembic.Source.t` instead of defaulting to `/data/attributes`.
  * Update `circle.yml`
      * Erlang `19.3`
      * Elixir `1.4.2`
* [#45](https://github.com/C-S-D/alembic/pull/45) - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.Pagination.Page.count` calculates the number of pages given the page `size` and the `total_size` of resources to be paginated.
  * `Alembic.Pagination.Page.first` returns the `Alembic.Pagination.Page.t` for the `first` for `Alembic.Pagination.t` given any page and the page count.
  * `Alembic.Pagination.Page.last` is the last page for `Alembic.Pagination.t` given any page and the page count.
  * `Alembic.Pagination.Page.next` is the next page after the current `page`.  If `page` `number` matches `count`, then it must be the last page and so next will be `nil`.
  * `Alembic.Paginaton.Page.previous` is the previous page to the current `page`.  If the `page` `number` is `1`, then it is the first page, and the previous page is `nil`.
  * `Alembic.Pagination.Page.to_pagination` takes the current `page` and the `total_size` of resources to paginated and produces the `Alembic.Pagination` with `first`, `last`, `next`, and
  `previous` around that `page`.  If `page` `number` is greater than the calculated page count `{:error, Alembic.Document.t}` is returned instead of `{:ok, Alembic.Pagination.t}`.
  * `Alembic.FromJson.integer_from_json`
  * `Alembic.FromJson.integer_to_positive_integer` takes an integer and returns it if positive, otherwise returns error `Document` if `0` or below.
  * `Alembic.Pagination.Page.from_params` parses param format with quoted integer page number and size or JSON format with integer page number and size.
  * Allow pagination opt-out with `%{"page" => nil}`.  `Alembic.Pagination.Page.from_params(%{"page" => nil})` will return `{:ok, :all}` while no `"page"` param will return `{:ok, nil}`.
  * Update dependencies
    * Update `ex_doc` to `0.16.1`
    * Update `excoveralls` to `0.7.0`
    * Update `credo` to `0.8.1`
* [#46](https://github.com/C-S-D/alembic/pull/46) - Use IntelliJ Elixir formatter for make the formatting consistent - [@KronicDeth](https://github.com/KronicDeth)
* [#47](https://github.com/C-S-D/alembic/pull/47) - [@KronicDeth](https://github.com/KronicDeth)
  * Convert to CircleCI 2.0
    * Turn on workflows, so that `build`, which includes `mix deps.get` and `mix compile` is a dependency of all, but `mix dialyze`, `mix docs`, `mix inch.report`, and `mix coveralls.circleci` can run in parallel after it.
* [#48](https://github.com/C-S-D/alembic/pull/48) - Wrap `}` after wrapped keys - [@KronicDeth](https://github.com/KronicDeth)
* [#49](https://github.com/C-S-D/alembic/pull/49)
    * Support `many_to_many` associations in `Alembic.ToEctoSchema.to_ecto_schema/2` - [@jeffutter](https://github.com/jeffutter)
    * `Alembic.ToEctoSchema.to_ecto_schema/2` `doctest`s - [@KronicDeth](https:/github.com/KronicDeth)
      * Increase code coverage to 95.5%
      * Cover new `many_to_many` support
    * Update dependencies - [@KronicDeth](https:/github.com/KronicDeth)
      * `credo` `0.8.5`
      * `ecto` `2.1.6`
      * `ex_doc` `0.16.2`
      * `excoveralls` `0.7.2`

### Bug Fixes
* [#45](https://github.com/C-S-D/alembic/pull/45) - [@KronicDeth](https://github.com/KronicDeth)
  * Allow `next` and `previous` to be `nil` in `Pagination.t` `@type` since they were already allowed to be `nil` in use for the last and first page, respectively.
  * `Alembic.Pagination.Page` `number` is `pos_integer` because `non_neg_integer` allows 0, but that's not valid because `number` is 1-based, not 0-based.
  * Remove extra blank lines from `@doc`s
  * Switch to github version of `earmark` to get bug fix in pragdave/earmark#144.
  * Remove spaces inside `{ }`.

## v3.3.0

### Enhancements
* [#44](https://github.com/C-S-D/alembic/pull/44) - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.Document.from_ecto_changeset/2` converts the `errors` in `ecto_changeset` to `Alembic.Error.t` in a single `Alembic.Document.t`.  Bypasses a [bug in `JaSerializer`](https://github.com/vt-elixir/ja_serializer/blob/b5d9f1da736c3a9c6b42da34d35dafb7ce93879e/lib/ja_serializer/ecto_error_serializer.ex#L73-L81) where it assumes all fields that don't end in `_id` are attribute names, which leads to association names (as opposed to their foreign key) being put under `/data/attributes`.  `Alembic.Document.from_ecto_changeset` reflects on the `Ecto.Changeset.t` `data` struct module to get the `__schema__/1` information from the `Ecto.Schema.t`.  It also assumes that if the field maps to no known attribute, association or foreign key, then the error should not have an `Alembic.Source.t` instead of defaulting to `/data/attributes`.
  * Update `circle.yml`
    * Erlang `19.3`
    * Elixir `1.4.1`

### Bug Fixes
* [#43](https://github.com/C-S-D/alembic/pull/43) - [@KronicDeth](https://github.com/KronicDeth)
  * Allow `Alembic.Error.t` `source` to be `nil`
  * Lower minimum coverage because coverage number varies from run to run.

## v3.2.0

### Enhancements
* [#42](https://github.com/C-S-D/alembic/pull/42) - [@KronicDeth](https://github.com/KronicDeth)
  * Switch from `coverex` to `excoveralls`, so coverage data can be published to Coveralls.io.
  * Update dependencies
    * `ex_doc` to `0.15.1`
    * `inch_ex` to `0.5.6`
    *  `ecto` to `2.1.4`
    * `junit_formatter` to `1.3.0`
    * `credo` to `0.7.3`
  * Allow `poison` to include `~> 3.0`

### Bug Fixes
* [#42](https://github.com/C-S-D/alembic/pull/42) - [@KronicDeth](https://github.com/KronicDeth)
  * Fix Elixir 1.4 warnings

## v3.1.1

### Bug Fixes
* [#41](https://github.com/C-S-D/alembic/pull/41) - [@KronicDeth](https://github.com/KronicDeth)
  * Allow `atom` for `Alembic.Error.t` `:meta` value as `atom` is used for `"action"` and `"sender"` values in error templates.
  * `Alembic.Source.t` needs to be clarified to show that either the `:parameter` is a `String.t` and `:pointer` is `nil` OR `:parameter` is `nil` and `:pointer` is a JSON pointer.

## v3.1.0

### Enhancements
* [#40](https://github.com/C-S-D/alembic/pull/40) - `Alembic.Fetch.from_params`, in addition to parsing out the includes will not also parse out the sorts in the `"sort"` parameter using `Alembic.Fetch.Sorts.from_params`.  To transform the `Alembic.Fetch.Sorts.t` back to the string format in `"sort"`, you can use `Alembic.Fetch.Sorts.to_string/1`. - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#40](https://github.com/C-S-D/alembic/pull/40) - Change `:include` to `:includes` in the `@typedoc` for `Alembic.Fetch.t` - [@KronicDeth](https://github.com/KronicDeth)

## v3.0.0

### Enhancements

* [#39](https://github.com/C-S-D/alembic/pull/39) - [@KronicDeth](https://github.com/KronicDeth)
  * Update dependencies
    * `credo` to `0.5.2`
    * `ex_doc` to `0.14.3`
    * `inch_ex` to `0.5.5`
    * `junit_formatter` to `1.1.0`
  * Build with Erlang 19.1 and Elixir 1.3.4 on CircleCI.

### Bug Fixes
* [#39](https://github.com/C-S-D/alembic/pull/39) - [@KronicDeth](https://github.com/KronicDeth)
  * Ecto 2.1 makes the warning about `cast/4` instead of `cast/3` noisy, but Ecto 1.X had the opposite warning to use `cast/4` instead of `cast/3`, so use `cast/3`.
  * Fix all Erlang 19.1 dialyzer warnings.

### Incompatible Changes
* [#39](https://github.com/C-S-D/alembic/pull/39) - Drop Ecto 1.0 since Ecto 1.0's `cast/3` is different than Ecto 2.0's `cast/3.` - [@KronicDeth](https://github.com/KronicDeth)

## v2.4.0

### Enhancements
* [#38](https://github.com/C-S-D/alembic/pull/38) - CodeClimate just added credo support to their beta engines channel.  Running on CodeClimate will allow the credo tests to run in parallel with CircleCI, leading to faster overall build times. - [@KronicDeth](https://github.com/KronicDeth)

## v2.3.0

### Enhancements
* [#32](https://github.com/C-S-D/alembic/pull/32) - `Alembic.Pagination.to_links/2` allows converting `Alembic.Pagination.t` from `Alembic.Links.to_pagination` back to `Alembic.Links.t` with urls. - [@KronicDeth](https://github.com/KronicDeth)
* [#33](https://github.com/C-S-D/alembic/pull/33) - [@KronicDeth](https://github.com/KronicDeth)
  * Update `coverex` to `1.4.10`
  * Update `credo` to `0.4.11`
  * Update `ecto` to `2.0.5`
  * Update `hackney` to `1.6.1`
  * Update `httpoison` to `0.9.1`
  * Update `inch_ex` to `0.5.4`
  * Update `junit_formatter` to `1.1.0`
    * JUnit output location changed from `_build/test/test-junit-report.xml` to `_build/test/lib/alembic/test-junit-report.xml`

### Bug Fixes
* [#32](https://github.com/C-S-D/alembic/pull/32) - Fix `alias` that wasn't renamed - [@KronicDeth](https://github.com/KronicDeth)

## v2.2.0

### Enhancements
* [#31](https://github.com/C-S-D/alembic/pull/30) - [@KronicDeth](https://github.com/KronicDeth)
  - Update `ex_doc` to `0.12.0`
  - Update `credo` to `0.4.5`
  - Update `ecto` to `2.0.2`.  Compatibility range is changed from `~> 1.1` to `~> 1.1 or ~> 2.0`, so no incompatibility is introduced for runtime dependencies.

## v2.1.1

### Bug Fixes
* [#30](https://github.com/C-S-D/alembic/pull/30) - Elixir 1.3.0 compatibility - [@KronicDeth](https://github.com/KronicDeth)
  - Work-around [elixir-lang/elixir#4874)](https://github.com/elixir-lang/elixir/issues/4874) by aliasing `Alembic.Source` and using `Source.t` instead of `@for.t`.
  - Use Erlang 18.3 instead of Erlang 19.0 until dialyer bug (http://bugs.erlang.org/browse/ERL-177) is fixed.

## v2.1.0

### Enhancements
* [#27](https://github.com/C-S-D/alembic/pull/25) - Add more doctests to Alembic.ToParams.nested_to_foreign_keys - [@KronicDeth](https://github.com/KronicDeth)
  * `nil` for the nested parameters converts to a `nil` foreign key parameter
  * When the nested parameters are not even present, the foreign key won't be added
  *` has_many` nested params are unchanged

### Bug Fixes
* [#27](https://github.com/C-S-D/alembic/pull/25) - Convert `nil` nested params to `nil` foreign key - [@KronicDeth](https://github.com/KronicDeth)

## v2.0.1

### Bug Fixes
* [#25](https://github.com/C-S-D/alembic/pull/25) - Documentation formatting - [@KronicDeth](https://github.com/KronicDeth)
  * Wrong number of spaces and missing closing backquotes led to some doctests not being rendered correctly.
  * Fix docs for FromJson.from_json callback
    * Use `<name> :: <type>` format for parameters, so they don't appear as
  `arg0` and `arg1` in the generated docs.
    * Use those names in the Paramaters section and code block teh format of
    the error template.

## v2.0.0

### Enhancements
* [#10](https://github.com/C-S-D/alembic/pull/10) - `ToEctoSchema` and `ToParams` - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.Document.to_params/1` takes an `Alembic.Document.t` and converts it to the params format used by `Ecto.Changset.cast/4`
  * `Alembic.Document.to_ecto_schema/2` takes an `Alembic.Document.t` and converts it to `Ecto.Schema` structs that an be used in the rest of an application.
* [#11](https://github.com/C-S-D/alembic/pull/11) - Parse include params - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.Fetch.from_params` can extract and normalize params for controlling JSON API fetching into an `%Alembic.Fetch{}`.
  * `Alembic.Fetch.Includes.to_preloads` can convert the normalized includes to a list of preloads for `Ecto.Repo.preload` or `Ecto.Query.preload`.
  * `Alembic.Fetch.to_query` will add the preloads for `%Alembic.Fetch{}` includes to a query.
* [#12](https://github.com/C-S-D/alembic/pull/12) - Fetch.Include.preload and preload_by_include types - [@KronicDeth](https://github.com/KronicDeth)
  * Use `Fetch.Include.preload` and `preload_by_include types` types instead of generic `term` and `map`.
* [#14](https://github.com/C-S-D/alembic/pull/14) - Allow `jsonapi` field in `Document.t`, so that jsonapi can be set to `%{ "version" => "1.0" }` to match `JaSerializer` output. - [@KronicDeth](https://github.com/KronicDeth)
* [#15](https://github.com/C-S-D/alembic/pull/15) - `ToParams.nest_to_foreign_keys/2` converts nested parameters for `belongs_to` associations to a foreign key parameter. - [@KronicDeth](https://github.com/KronicDeth)
* [#16](https://github.com/C-S-D/alembic/pull/16) - Check for "Closing unclosed backquotes" from `mix docs` on CircleCI  - [@KronicDeth](https://github.com/KronicDeth)
* [#17](https://github.com/C-S-D/alembic/pull/17) - Pagination - [@KronicDeth](https://github.com/KronicDeth)
  * `Pagination.Page` can store the `page[number]` and `page[size]` from a `URI`.
  * `Link.to_page` can convert a URL to an `Pagination.Page`
  * `Pagination` can store the `first`, `last`, `next`, and `previous` `Pagination.Page`s
  * `Document.to_pagination` will extract the `first`, `last`, and `next`, and `previous` `Pagination.Page` from the `"first"`, `"last"`, `"next"`, and `"prev"` top-level `links`.  The `total_size` will be extracted from the top-level `meta` `"record_count"`.  This gives compatibility with the paged paginator in `JSONAPI::Resources` with `config.top_level_meta_include_record_count = true`.
* [#18](https://github.com/C-S-D/alembic/pull/18) - Document.error_status_consensus - [@KronicDeth](https://github.com/KronicDeth)
  * `Document.error_status_consensus(document :: Document.t) :: String.t` returns the consensus `Error.t` `status` for all the `errors` in the `document`.  If there are no errors or statuses, then it is `nil`; otherwise, the consensus is the status shared between all (non-`nil`) errors or the max 100s status.  For example, `"404"` and `"422"` would have a consensus of `"400"` because `400` covers both errors.  For `"404"` and `"500"` the consensus would be `"500"` because `"500"` is more serious than any 4XX error.
* [#20](https://github.com/C-S-D/alembic/pull/20) - Indirect relationships - [@KronicDeth](https://github.com/KronicDeth)
  * `ToEctoSchema.to_ecto_schema(params, module)` recursively converts nested params to the associated structs
  * `Fetch.Includes.to_string` will take a list of includes and convert it back to the common-separated string format used by JSONAPI query parameters.
* [#23](https://github.com/C-S-D/alembic/pull/23) - Allow Poison ~> 1.5 or ~> 2.0 - [@KronicDeth](https://github.com/KronicDeth)
  * Allow compatibility with projects that haven't upgraded to Poison 2.0. Nothing in the `Poison.Encoder` implementations is 2.0 specific, so allow both major versions.

### Bug Fixes
* [#10](https://github.com/C-S-D/alembic/pull/10) - `ToEctoSchema` and `ToParams` - [@KronicDeth](https://github.com/KronicDeth)
  * Use `Alembic.ResourceIdentifier.t` in `Alembic.Relationship.t` for `data`'s value type.
  * Use `Alembic.Meta.t` in `Alembic.Relationship.t` for `meta`'s value type.
* [#13](https://github.com/C-S-D/alembic/pull/13) - [@KronicDeth](https://github.com/KronicDeth)
  * Use `:unset` instead of `nil` for unset `%Alembic.Document{}` `data` as it was too difficult to properly infer when `nil` was unset and when it was a singleton that was not present.
  * `Alembic.Resource.to_params` now treats `nil` `%Alembic.Resource{}` `attributes` as `%{}` when building the params so invalid input from user does not cause an exception.
* [#14](https://github.com/C-S-D/alembic/pull/14) - Don't encode `ResourceIdentifier.meta` when it is `nil`, so that `"meta":null` doesn't occur in the encoded version. - [@KronicDeth](https://github.com/KronicDeth)
* [#16](https://github.com/C-S-D/alembic/pull/16) - Add missing backquotes - [@KronicDeth](https://github.com/KronicDeth)
* [#19](https://github.com/C-S-D/alembic/pull/19) - [@KronicDeth](https://github.com/KronicDeth)
  * `Resource.to_ecto_schema` now ignores relationships that don't map to known associations, which manifested as an `ArgumentError` to `String.to_existing_atom`.
  * `Resource.to_ecto_schema` only sets the foreign key when the relationship is present, which prevent running `nil.id`.
* [#20](https://github.com/C-S-D/alembic/pull/20) - Indirect relationships - [@KronicDeth](https://github.com/KronicDeth)
  * `to_params` and `to_ecto_schema` properly handles indirect relationships.
* [#21](https://github.com/C-S-D/alembic/pull/21) - Fix deprecation warnings for Ecto 1.1 - [@KronicDeth](https://github.com/KronicDeth)
  * Use `Ecto.Changeset.cast/4` instead of `cast/3` to eliminate deprecation warning.
* [#22](https://github.com/C-S-D/alembic/pull/22) - Represent no relationship data different than null data - [@KronicDeth](https://github.com/KronicDeth)
  * Like `Document`, `Relationship` needs to differentiate between `"data":null` in the JSON and no data key at all, so have `Relationship.t` default to `:unset` instead of `nil`, the same way `Document.t` works now.  This means adding a `Poison.Encoder` implementation to not encode the `:unset` and changing the `ToParams` behaviour to allow for an `{:error, :unset}` return that the `Relationship.to_params` can return when `data` is `:unset`, so that `Relationships.to_params` will skip including the output in the map of all relationship params.

### Incompatible Changes
* [#10](https://github.com/C-S-D/alembic/pull/10) - `ToEctoSchema` and `ToParams` - [@KronicDeth](https://github.com/KronicDeth)
  * Removed the `Alembic.Relationship.resource_identifier` type that was made obsolete by `Alembic.ResourceIdentifier.t`
  * Updating relations by nesting attributes is no longer supported as it is not supported in the JSONAPI spec.
* [#17](https://github.com/C-S-D/alembic/pull/17) - Make `Link.href_from_json` private as it should have alway been. - [@KronicDeth](https://github.com/KronicDeth)
* [#20](https://github.com/C-S-D/alembic/pull/20) - Indirect relationships - [@KronicDeth](https://github.com/KronicDeth)
  * `ToParams` behaviour now requires `to_params/3` in addition to `to_params/2`
  * Remove `to_ecto_schema/3` that are no longer called because of recursion in `ToEctoSchema.to_ecto_schema/2`
    * `Relationship`
    * `Relationships`
    * `ResourceIdentifier`
    * `ResourceLinkage`

## v1.0.0

### Enhancements
* [#1](https://github.com/C-S-D/alembic/pull/1) - [@KronicDeth](https://github.com/KronicDeth)
  * CircleCI build setup
  * JUnit formatter for CircleCI's test output parsing
* [#2](https://github.com/C-S-D/alembic/pull/2) - [@KronicDeth](https://github.com/KronicDeth)
  * `mix test --cover` with CoverEx
  * Archive coverage reports on CircleCI
* [#3](https://github.com/C-S-D/alembic/pull/3) - [@KronicDeth](https://github.com/KronicDeth)
  * Use `ex_doc` and `earmark` to generate documentation with `mix docs`
  * Use `mix inch (--pedantic)` to see coverage for documentation
* [#4](https://github.com/C-S-D/alembic/pull/4) - [@KronicDeth](https://github.com/KronicDeth)
  * Add repository to [hexfaktor](http://hexfaktor.org/), so that outdated hex dependencies are automatically notified through CI.
  * Add [hexfaktor](http://hexfaktor.org/) badge to [README.md](README.md)
* [#5](https://github.com/C-S-D/alembic/pull/5) - [@KronicDeth](https://github.com/KronicDeth)
  * Configure `mix credo` to run against `lib` and `test` to maintain consistency with Ruby projects that use `rubocop` on `lib` and `spec`.
  * Run `mix credo --strict` on CircleCI to check style and consistency in CI
* [#6](https://github.com/C-S-D/alembic/pull/6) - [@KronicDeth](https://github.com/KronicDeth)
  * Use [`dialyze`](https://github.com/fishcakez/dialyze) for dialyzer access with `mix dialyze`
* [#7](https://github.com/C-S-D/alembic/pull/7) - Validation and conversion of JSON API errors Documents - [@KronicDeth](https://github.com/KronicDeth)
  * JSON API errors documents can be validated and converted to `%Alembic.Document{}` using `Alembic.Document.from_json/2`.  Invalid documents return `{:error, %Alembic.Document{}}`.  The `%Alembic.Document{}` can be sent back to the sender, which can be validated on the other end using `from_json/2`.  Valid documents return `{:ok, %Alembic.Document{}}`.
* [#8](https://github.com/C-S-D/alembic/pull/8) - JSON API (non-errors) Documents - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.ResourceIdentifier`
  * `Alembic.ResourceLinkage`
  * `Alembic.Relationship`
  * `Alembic.Relationships`
  * `Alembic.Resource`
  * `Alembic.Document` can parse `from_json`, represent, and encode with `Poison.encode` all document format, including `data` and `meta`, in addition to the prior support for `errors`
  * `assert_idempotent` is defined in a module, `Alembic.FromJsonCase` under `test/support`, so it's no longer necessary to run `mix test <file> test/interpreter_server/api/from_json_test.exs` to get access to `assert_idempotent` in `<file>`.

### Incompatible Changes
* [#8](https://github.com/C-S-D/alembic/pull/8) - JSON API (non-errors) Documents - [@KronicDeth](https://github.com/KronicDeth)
  * `Alembic.FromJsonTest.assert_idempotent` has moved to `Alembic.FromJsonCase`.
