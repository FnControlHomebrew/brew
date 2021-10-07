# typed: strict
# frozen_string_literal: true

require "compilers"

# Combination of C++ standard library and compiler.
class CxxStdlib
  extend T::Sig

  sig { params(type: T.nilable(Symbol), compiler: Symbol).returns(CxxStdlib) }
  def self.create(type, compiler)
    raise ArgumentError, "Invalid C++ stdlib type: #{type}" if type && [:libstdcxx, :libcxx].exclude?(type)

    CxxStdlib.new(type, compiler)
  end

  sig { returns(T.nilable(Symbol)) }
  attr_reader :type

  sig { returns(Symbol) }
  attr_reader :compiler

  sig { params(type: T.nilable(Symbol), compiler: Symbol).void }
  def initialize(type, compiler)
    @type = type
    @compiler = compiler
  end

  sig { returns(String) }
  def type_string
    type.to_s.gsub(/cxx$/, "c++")
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: #{compiler} #{type}>"
  end
end
