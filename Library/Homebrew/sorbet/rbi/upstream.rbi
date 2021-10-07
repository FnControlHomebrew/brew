# typed: strict

# This file contains temporary definitions for fixes that have
# been submitted upstream to https://github.com/sorbet/sorbet.

class Module
  # https://github.com/sorbet/sorbet/pull/3732
  sig do
    params(
        arg0: T.any(Symbol, String),
        arg1: T.any(Proc, Method, UnboundMethod)
    )
    .returns(Symbol)
  end
  sig do
    params(
        arg0: T.any(Symbol, String),
        blk: T.proc.bind(T.untyped).returns(T.untyped),
    )
    .returns(Symbol)
  end
  def define_method(arg0, arg1=T.unsafe(nil), &blk); end
end

class Pathname
  # https://github.com/sorbet/sorbet/issues/4688
  sig do
    type_parameters(:U).params(
        ignore_error: T::Boolean,
        blk: T.proc.params(arg0: Pathname).returns(T.type_parameter(:U)),
    )
    .returns(T.type_parameter(:U))
  end
  # sig {params(ignore_error: T::Boolean).returns(T::Enumerator[Pathname])}
  def find(ignore_error: true, &blk); end

  # https://github.com/sorbet/sorbet/pull/4686
  sig {returns(Pathname)}
  def readlink(); end
end
