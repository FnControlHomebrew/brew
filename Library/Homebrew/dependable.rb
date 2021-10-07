# typed: true
# frozen_string_literal: true

require "options"

# Shared functions for classes which can be depended upon.
#
# @api private
module Dependable
  extend T::Sig
  extend T::Helpers

  abstract!

  # `:run` and `:linked` are no longer used but keep them here to avoid their
  # misuse in future.
  RESERVED_TAGS = [:build, :optional, :recommended, :run, :test, :linked].freeze

  sig { abstract.returns(T::Array[String]) }
  def option_names; end

  sig { abstract.returns(Array) }
  def tags; end

  sig { returns(T::Boolean) }
  def build?
    tags.include? :build
  end

  sig { returns(T::Boolean) }
  def optional?
    tags.include? :optional
  end

  sig { returns(T::Boolean) }
  def recommended?
    tags.include? :recommended
  end

  sig { returns(T::Boolean) }
  def test?
    tags.include? :test
  end

  sig { returns(T::Boolean) }
  def required?
    !build? && !test? && !optional? && !recommended?
  end

  sig { returns(T::Array[T.untyped]) }
  def option_tags
    tags - RESERVED_TAGS
  end

  sig { returns(Options) }
  def options
    Options.create(option_tags)
  end

  sig { params(build: BuildOptions).returns(T::Boolean) }
  def prune_from_option?(build)
    return false if !optional? && !recommended?

    build.without?(self)
  end

  sig { params(dependent: T.any(Formula, CaskDependent), formula: T.nilable(Formula)).returns(T::Boolean) }
  def prune_if_build_and_not_dependent?(dependent, formula = nil)
    return false unless build?
    return dependent.any_version_installed? unless formula

    dependent != formula
  end
end
