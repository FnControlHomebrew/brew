# typed: strict
# frozen_string_literal: true

# An adapter for casks to provide dependency information in a formula-like interface.
class CaskDependent
  extend T::Sig

  sig { params(cask: Cask::Cask).void }
  def initialize(cask)
    @cask = cask
  end

  sig { returns(String) }
  def name
    @cask.token
  end

  sig { returns(String) }
  def full_name
    @cask.full_name
  end

  sig { params(ignore_missing: T::Boolean).returns(T::Array[Dependency]) }
  def runtime_dependencies(ignore_missing: false)
    recursive_dependencies(ignore_missing: ignore_missing).reject do |dependency|
      tags = dependency.tags
      tags.include?(:build) || tags.include?(:test)
    end
  end

  sig { returns(T::Array[Dependency]) }
  def deps
    @deps = T.let(@deps, T.nilable(T::Array[Dependency]))
    @deps ||= @cask.depends_on.formula.map do |f|
      Dependency.new f
    end
  end

  sig { returns(T::Array[Requirement]) }
  def requirements
    @requirements = T.let(@requirements, T.nilable(T::Array[Requirement]))
    @requirements ||= begin
      requirements = []
      dsl_reqs = @cask.depends_on

      dsl_reqs.arch&.each do |arch|
        requirements << ArchRequirement.new([:x86_64]) if arch[:bits] == 64
        requirements << ArchRequirement.new([arch[:type]])
      end
      dsl_reqs.cask.each do |cask_ref|
        requirements << Requirement.new([{ cask: cask_ref }])
      end
      requirements << dsl_reqs.macos if dsl_reqs.macos

      requirements
    end
  end

  sig {
    params(
      ignore_missing: T::Boolean,
      block:          T.nilable(T.proc.params(dependent: T.any(Formula, CaskDependent), dep: Dependency).void),
    ).returns(T::Array[Dependency])
  }
  def recursive_dependencies(ignore_missing: false, &block)
    Dependency.expand(self, ignore_missing: ignore_missing, &block)
  end

  sig {
    params(
      block: T.nilable(T.proc.params(dependent: T.any(Formula, CaskDependent, SoftwareSpec), req: Requirement).void),
    ).returns(Requirements)
  }
  def recursive_requirements(&block)
    Requirement.expand(self, &block)
  end

  sig { returns(T::Boolean) }
  def any_version_installed?
    @cask.installed?
  end
end
