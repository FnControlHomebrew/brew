# typed: strict
# frozen_string_literal: true

require "delegate"
require "cask_dependent"

# A collection of dependencies.
#
# @api private
class Dependencies < SimpleDelegator
  extend T::Sig

  sig { params(args: Dependency).void }
  def initialize(*args)
    super(args)
  end

  sig { params(other: BasicObject).returns(T::Boolean) }
  def eql?(other)
    self == other
  end

  sig { returns(T::Array[Dependency]) }
  def optional
    select(&:optional?)
  end

  sig { returns(T::Array[Dependency]) }
  def recommended
    select(&:recommended?)
  end

  sig { returns(T::Array[Dependency]) }
  def build
    select(&:build?)
  end

  sig { returns(T::Array[Dependency]) }
  def required
    select(&:required?)
  end

  sig { returns(T::Array[Dependency]) }
  def default
    build + required + recommended
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: #{to_a}>"
  end
end

# A collection of requirements.
#
# @api private
class Requirements < SimpleDelegator
  extend T::Sig

  sig { params(args: Requirement).void }
  def initialize(*args)
    super(Set.new(args))
  end

  sig { params(other: Requirement).returns(T.self_type) }
  def <<(other)
    if other.is_a?(Comparable)
      grep(other.class) do |req|
        return self if T.cast(req, Comparable) > other

        delete(req)
      end
    end
    super
    self
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: {#{to_a.join(", ")}}>"
  end
end
