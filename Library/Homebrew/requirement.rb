# typed: true
# frozen_string_literal: true

require "dependable"
require "dependency"
require "dependencies"
require "build_environment"

# A base class for non-formula requirements needed by formulae.
# A fatal requirement is one that will fail the build if it is not present.
# By default, requirements are non-fatal.
#
# @api private
class Requirement
  extend T::Sig

  include Dependable
  extend Cachable

  sig { override.returns(Array) }
  attr_reader :tags

  sig { returns(T.nilable(String)) }
  attr_reader :cask

  sig { returns(T.nilable(String)) }
  attr_reader :download

  sig { params(tags: T::Array[T.untyped]).void }
  def initialize(tags = [])
    @cask = T.let(self.class.cask, T.nilable(String))
    @download = T.let(self.class.download, T.nilable(String))
    tags.each do |tag|
      next unless tag.is_a? Hash

      @cask ||= tag[:cask]
      @download ||= tag[:download]
    end
    @tags = tags
    @tags << :build if self.class.build
  end

  sig { returns(String) }
  def name
    @name = T.let(@name, T.nilable(String))
    @name ||= infer_name
  end

  sig { override.returns(T::Array[String]) }
  def option_names
    [name]
  end

  # The message to show when the requirement is not met.
  sig { returns(String) }
  def message
    _, _, class_name = self.class.to_s.rpartition "::"
    s = "#{class_name} unsatisfied!\n"
    if cask
      s += <<~EOS
        You can install the necessary cask with:
          brew install --cask #{cask}
      EOS
    end

    if download
      s += <<~EOS
        You can download from:
          #{Formatter.url(download)}
      EOS
    end
    s
  end

  # Overriding {#satisfied?} is unsupported.
  # Pass a block or boolean to the satisfy DSL method instead.
  sig {
    params(
      env:          T.nilable(String),
      cc:           T.nilable(String),
      build_bottle: T::Boolean,
      bottle_arch:  T.nilable(String),
    ).returns(T::Boolean)
  }
  def satisfied?(env: nil, cc: nil, build_bottle: false, bottle_arch: nil)
    satisfy = self.class.satisfy
    return true unless satisfy

    @satisfied_result =
      satisfy.yielder(env: env, cc: cc, build_bottle: build_bottle, bottle_arch: bottle_arch) do |p|
        instance_eval(&p)
      end
    return false unless @satisfied_result

    true
  end

  # Overriding {#fatal?} is unsupported.
  # Pass a boolean to the fatal DSL method instead.
  sig { returns(T::Boolean) }
  def fatal?
    self.class.fatal || false
  end

  sig { returns(T.nilable(Pathname)) }
  def satisfied_result_parent
    return unless @satisfied_result.is_a?(Pathname)

    parent = @satisfied_result.resolved_path.parent
    if parent.to_s =~ %r{^#{Regexp.escape(HOMEBREW_CELLAR)}/([\w+-.@]+)/[^/]+/(s?bin)/?$}o
      parent = HOMEBREW_PREFIX/"opt/#{Regexp.last_match(1)}/#{Regexp.last_match(2)}"
    end
    parent
  end

  # Overriding {#modify_build_environment} is unsupported.
  # Pass a block to the env DSL method instead.
  sig {
    params(
      env:          T.nilable(String),
      cc:           T.nilable(String),
      build_bottle: T::Boolean,
      bottle_arch:  T.nilable(String),
    ).void
  }
  def modify_build_environment(env: nil, cc: nil, build_bottle: false, bottle_arch: nil)
    satisfied?(env: env, cc: cc, build_bottle: build_bottle, bottle_arch: bottle_arch)
    env_proc&.yield_self { |env_proc| instance_eval(&env_proc) }

    # XXX If the satisfy block returns a Pathname, then make sure that it
    # remains available on the PATH. This makes requirements like
    #   satisfy { which("executable") }
    # work, even under superenv where "executable" wouldn't normally be on the
    # PATH.
    parent = satisfied_result_parent
    return unless parent
    return if ["#{HOMEBREW_PREFIX}/bin", "#{HOMEBREW_PREFIX}/bin"].include?(parent.to_s)
    return if PATH.new(ENV["PATH"]).include?(parent.to_s)

    ENV.prepend_path("PATH", parent)
  end

  def env
    self.class.env
  end

  sig { returns(T.nilable(Proc)) }
  def env_proc
    self.class.env_proc
  end

  sig { params(other: Object).returns(T::Boolean) }
  def ==(other)
    other.is_a?(self.class) && name == other.name && tags == other.tags
  end
  alias eql? ==

  sig { returns(Integer) }
  def hash
    name.hash ^ tags.hash
  end

  sig { returns(String) }
  def inspect
    "#<#{self.class.name}: #{tags.inspect}>"
  end

  sig { returns(String) }
  def display_s
    name.capitalize
  end

  sig {
    type_parameters(:U).params(
      block: T.proc.params(mktemp: Mktemp).returns(T.type_parameter(:U))
    ).returns(T.type_parameter(:U))
  }
  def mktemp(&block)
    Mktemp.new(name).run(&block)
  end

  private

  sig { returns(String) }
  def infer_name
    klass = self.class.name || self.class.to_s
    klass = klass.sub(/(Dependency|Requirement)$/, "")
                 .sub(/^(\w+::)*/, "")
    return klass.downcase if klass.present?

    return @cask if @cask.present?

    ""
  end

  def which(cmd)
    super(cmd, PATH.new(ORIGINAL_PATHS))
  end

  def which_all(cmd)
    super(cmd, PATH.new(ORIGINAL_PATHS))
  end

  class << self
    extend T::Sig

    include BuildEnvironment::DSL

    sig { returns(T.nilable(Proc)) }
    attr_reader :env_proc

    sig { returns(T.nilable(T::Boolean)) }
    attr_reader :build

    # sig { returns(T.nilable(T::Boolean)) }
    attr_rw :fatal

    # sig { returns(T.nilable(String)) }
    attr_rw :cask

    # sig { returns(T.nilable(String)) }
    attr_rw :download

    sig { params(options: T.nilable(T.any(Hash, T::Boolean, Pathname)), block: T.nilable(Proc)).returns(T.nilable(Satisfier)) }
    def satisfy(options = nil, &block)
      @satisifed = T.let(@satisfied, T.nilable(Satisfier))
      return @satisfied if options.nil? && !block

      options = {} if options.nil?
      @satisfied = Satisfier.new(options, &block)
    end

    def env(*settings, &block)
      if block
        @env_proc = block
      else
        super
      end
    end
  end

  # Helper class for evaluating whether a requirement is satisfied.
  class Satisfier
    extend T::Sig

    sig { params(options: T.any(Hash, T::Boolean, Pathname), block: T.nilable(Proc)).void }
    def initialize(options, &block)
      case options
      when Hash
        @options = { build_env: true }
        @options.merge!(options)
        # TODO: raise an error if no block is given?
      else
        @satisfied = options
      end
      @proc = block
    end

    sig {
      params(
        env:          T.nilable(String),
        cc:           T.nilable(String),
        build_bottle: T::Boolean,
        bottle_arch:  T.nilable(String),
        _block:       T.proc.params(p: Proc).returns(T::Boolean),
      ).returns(T.any(T::Boolean, Pathname))
    }
    def yielder(env: nil, cc: nil, build_bottle: false, bottle_arch: nil, &_block)
      if instance_variable_defined?(:@satisfied)
        @satisfied
      elsif @options[:build_env]
        require "extend/ENV"
        ENV.with_build_environment(
          env: env, cc: cc, build_bottle: build_bottle, bottle_arch: bottle_arch,
        ) do
          yield T.must(@proc)
        end
      else
        yield T.must(@proc)
      end
    end
  end
  private_constant :Satisfier

  class << self
    # Expand the requirements of dependent recursively, optionally yielding
    # `[dependent, req]` pairs to allow callers to apply arbitrary filters to
    # the list.
    # The default filter, which is applied when a block is not given, omits
    # optionals and recommendeds based on what the dependent has asked for.
    sig {
      params(
        dependent: T.any(Formula, CaskDependent, SoftwareSpec),
        cache_key: T.nilable(String),
        block:     T.nilable(
          T.proc.params(dependent: T.any(Formula, CaskDependent, SoftwareSpec), req: Requirement).void,
        ),
      ).returns(Requirements)
    }
    def expand(dependent, cache_key: nil, &block)
      if cache_key.present?
        cache[cache_key] ||= {}
        return cache[cache_key][cache_id dependent].dup if cache[cache_key][cache_id dependent]
      end

      reqs = Requirements.new

      formulae = dependent.recursive_dependencies.map(&:to_formula)
      formulae.unshift(dependent)

      formulae.each do |f|
        f.requirements.each do |req|
          next if prune?(f, req, &block)

          reqs << req
        end
      end

      cache[cache_key][cache_id dependent] = reqs.dup if cache_key.present?
      reqs
    end

    sig {
      params(
        dependent: T.any(Formula, CaskDependent, SoftwareSpec),
        req:       Requirement,
        block:     T.nilable(
          T.proc.params(dependent: T.any(Formula, CaskDependent, SoftwareSpec), req: Requirement).void,
        ),
      ).returns(T.nilable(T::Boolean))
    }
    def prune?(dependent, req, &block)
      catch(:prune) do
        if block
          yield dependent, req
          nil
        elsif req.optional? || req.recommended?
          dependent = T.cast(dependent, T.any(Formula, SoftwareSpec))
          prune unless dependent.build.with?(req)
        end
      end
    end

    # Used to prune requirements when calling expand with a block.
    sig { void }
    def prune
      throw(:prune, true)
    end

    private

    def cache_id(dependent)
      "#{dependent.full_name}_#{dependent.class}"
    end
  end
end
