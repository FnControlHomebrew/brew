# typed: strict
# frozen_string_literal: true

# A formula option.
#
# @api private
class Option
  extend T::Sig

  sig { returns(String) }
  attr_reader :name, :description, :flag

  sig { params(name: String, description: String).void }
  def initialize(name, description = "")
    @name = name
    @flag = T.let("--#{name}", String)
    @description = description
  end

  sig { returns(String) }
  def to_s
    flag
  end

  sig { params(other: Object).returns(T.nilable(Integer)) }
  def <=>(other)
    return unless other.is_a?(Option)

    name <=> other.name
  end

  sig { params(other: Object).returns(T::Boolean) }
  def ==(other)
    other.is_a?(Option) && name == other.name
  end
  alias eql? ==

  sig { returns(Integer) }
  def hash
    name.hash
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: #{flag.inspect}>"
  end
end

# A deprecated formula option.
#
# @api private
class DeprecatedOption
  extend T::Sig

  sig { returns(String) }
  attr_reader :old, :current

  sig { params(old: String, current: String).void }
  def initialize(old, current)
    @old = old
    @current = current
  end

  sig { returns(String) }
  def old_flag
    "--#{old}"
  end

  sig { returns(String) }
  def current_flag
    "--#{current}"
  end

  sig { params(other: Object).returns(T::Boolean) }
  def ==(other)
    other.is_a?(DeprecatedOption) && old == other.old && current == other.current
  end
  alias eql? ==
end

# A collection of formula options.
#
# @api private
class Options
  extend T::Sig
  extend T::Generic

  include Enumerable

  Elem = type_member(fixed: Option) # rubocop:disable Style/MutableConstant

  sig { params(array: T.nilable(T::Array[String])).returns(Options) }
  def self.create(array)
    new Array(array).map { |e| Option.new(e[/^--([^=]+=?)(.+)?$/, 1] || e) }
  end

  sig { params(enum: T.nilable(T::Enumerable[Option])).void }
  def initialize(enum = nil)
    @options = T.let(Set.new(enum), T::Set[Option])
  end

  sig { override.params(block: T.proc.params(opt: Option).returns(BasicObject)).returns(T::Set[Option]) }
  def each(&block)
    @options.each(&block)
  end

  sig { params(other: Option).returns(Options) }
  def <<(other)
    @options << other
    self
  end

  sig { params(other: T::Enumerable[Option]).returns(Options) }
  def +(other)
    self.class.new(@options + other)
  end

  sig { params(other: T::Enumerable[Option]).returns(Options) }
  def -(other)
    self.class.new(@options - other)
  end

  sig { params(other: T::Enumerable[Option]).returns(Options) }
  def &(other)
    self.class.new(@options & other)
  end

  sig { params(other: T::Enumerable[Option]).returns(Options) }
  def |(other)
    self.class.new(@options | other)
  end

  # sig { params(other: Integer).returns(T::Array[Option]) }
  # sig { params(other: String).returns(String) }
  sig { params(other: T.untyped).returns(T.untyped) }
  def *(other)
    @options.to_a * other
  end

  sig { params(other: Object).returns(T::Boolean) }
  def ==(other)
    other.is_a?(Options) &&
      to_a == other.to_a
  end
  alias eql? ==

  sig { returns(T::Boolean) }
  def empty?
    @options.empty?
  end

  sig { returns(T::Array[String]) }
  def as_flags
    map(&:flag)
  end

  sig { params(o: Object).returns(T::Boolean) }
  def include?(o)
    any? { |opt| opt == o || opt.name == o || opt.flag == o }
  end

  sig { returns(T::Array[Option]) }
  def to_ary
    to_a
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: #{to_a.inspect}>"
  end

  sig { params(f: Formula).void }
  def self.dump_for_formula(f)
    f.options.sort_by(&:flag).each do |opt|
      puts "#{opt.flag}\n\t#{opt.description}"
    end
    puts "--HEAD\n\tInstall HEAD version" if f.head
  end
end
