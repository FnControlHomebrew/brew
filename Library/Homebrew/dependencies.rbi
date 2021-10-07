# typed: strict

class Dependencies < SimpleDelegator
  include Kernel
  include EnumerableDelegator

  Elem = type_member(fixed: Dependency)
end

# Based on https://github.com/sorbet/sorbet/blob/master/rbi/stdlib/set.rbi
class Requirements < SimpleDelegator
  include Kernel
  include EnumerableDelegator

  Elem = type_member(fixed: Requirement)

  sig do
    params(
        o: Elem,
    )
    .returns(T.self_type)
  end
  def delete(o); end
end

# Based on https://github.com/sorbet/sorbet/blob/master/rbi/core/enumerable.rbi
module EnumerableDelegator
  Elem = type_member

  sig do
    params(
        blk: T.proc.params(arg0: Elem).returns(BasicObject),
    )
    .void
  end
  def each(&blk); end

  sig do
    type_parameters(:U).params(
        arg0: BasicObject,
        blk: T.proc.params(arg0: Elem).returns(T.type_parameter(:U)),
    )
    .returns(T::Array[T.type_parameter(:U)])
  end
  def grep(arg0, &blk); end

  sig do
    type_parameters(:U).params(
        blk: T.proc.params(arg0: Elem).returns(T.type_parameter(:U)),
    )
    .returns(T::Array[T.type_parameter(:U)])
  end
  def map(&blk); end

  sig do
    params(
        blk: T.proc.params(arg0: Elem).returns(BasicObject),
    )
    .returns(T::Array[Elem])
  end
  def reject(&blk); end

  sig do
    params(
        blk: T.proc.params(arg0: Elem).returns(BasicObject),
    )
    .returns(T::Array[Elem])
  end
  def select(&blk); end

  sig {returns(T::Array[Elem])}
  def to_a(); end
end
