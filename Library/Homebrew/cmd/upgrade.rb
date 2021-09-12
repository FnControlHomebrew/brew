# typed: false
# frozen_string_literal: true

require "cli/parser"
require "formula_installer"
require "install"
require "upgrade"
require "cask/cmd"
require "cask/utils"
require "cask/macos"
require "api"

module Homebrew
  extend T::Sig

  module_function

  sig { returns(CLI::Parser) }
  def upgrade_args
    Homebrew::CLI::Parser.new do
      description <<~EOS
        Upgrade outdated casks and outdated, unpinned formulae using the same options they were originally
        installed with, plus any appended brew formula options. If <cask> or <formula> are specified,
        upgrade only the given <cask> or <formula> kegs (unless they are pinned; see `pin`, `unpin`).

        Unless `HOMEBREW_NO_INSTALL_CLEANUP` is set, `brew cleanup` will then be run for the
        upgraded formulae or, every 30 days, for all formulae.
      EOS
      switch "-d", "--debug",
             description: "If brewing fails, open an interactive debugging session with access to IRB "\
                          "or a shell inside the temporary build directory."
      switch "-f", "--force",
             description: "Install formulae without checking for previously installed keg-only or "\
                          "non-migrated versions. When installing casks, overwrite existing files "\
                          "(binaries and symlinks are excluded, unless originally from the same cask)."
      switch "-v", "--verbose",
             description: "Print the verification and postinstall steps."
      switch "-n", "--dry-run",
             description: "Show what would be upgraded, but do not actually upgrade anything."
      [
        [:switch, "--formula", "--formulae", {
          description: "Treat all named arguments as formulae. If no named arguments " \
                       "are specified, upgrade only outdated formulae.",
        }],
        [:switch, "-s", "--build-from-source", {
          description: "Compile <formula> from source even if a bottle is available.",
        }],
        [:switch, "-i", "--interactive", {
          description: "Download and patch <formula>, then open a shell. This allows the user to "\
                       "run `./configure --help` and otherwise determine how to turn the software "\
                       "package into a Homebrew package.",
        }],
        [:switch, "--force-bottle", {
          description: "Install from a bottle if it exists for the current or newest version of "\
                       "macOS, even if it would not normally be used for installation.",
        }],
        [:switch, "--fetch-HEAD", {
          description: "Fetch the upstream repository to detect if the HEAD installation of the "\
                       "formula is outdated. Otherwise, the repository's HEAD will only be checked for "\
                       "updates when a new stable or development version has been released.",
        }],
        [:switch, "--ignore-pinned", {
          description: "Set a successful exit status even if pinned formulae are not upgraded.",
        }],
        [:switch, "--keep-tmp", {
          description: "Retain the temporary files created during installation.",
        }],
        [:switch, "--display-times", {
          env:         :display_install_times,
          description: "Print install times for each package at the end of the run.",
        }],
      ].each do |options|
        send(*options)
        conflicts "--cask", options[-2]
      end
      formula_options
      [
        [:switch, "--cask", "--casks", {
          description: "Treat all named arguments as casks. If no named arguments " \
                       "are specified, upgrade only outdated casks.",
        }],
        *Cask::Cmd::AbstractCommand::OPTIONS,
        *Cask::Cmd::Upgrade::OPTIONS,
      ].each do |options|
        send(*options)
        conflicts "--formula", options[-2]
      end
      cask_options

      conflicts "--build-from-source", "--force-bottle"

      named_args [:outdated_formula, :outdated_cask]
    end
  end

  sig { void }
  def upgrade
    args = upgrade_args.parse

    formulae, casks = args.named.to_resolved_formulae_to_casks
    # If one or more formulae are specified, but no casks were
    # specified, we want to make note of that so we don't
    # try to upgrade all outdated casks.
    only_upgrade_formulae = formulae.present? && casks.blank?
    only_upgrade_casks = casks.present? && formulae.blank?

    formula_installers = if only_upgrade_casks
      []
    else
      create_formula_installers(formulae, args: args)
    end

    cask_installers = if only_upgrade_formulae
      []
    else
      create_cask_installers(casks, args: args)
    end

    display_outdated_packages(formula_installers, cask_installers, args: args)
    fetch_outdated_formulae(formula_installers, args: args)
    fetch_outdated_casks(cask_installers, args: args)
    upgrade_outdated_formulae(formula_installers, args: args)
    upgrade_outdated_casks(cask_installers, args: args)

    Homebrew.messages.display_messages(display_times: args.display_times?)
  end

  def display_outdated_packages(formula_installers, cask_installers, args:)
    if formula_installers.empty? && cask_installers.empty?
      oh1 "No packages to upgrade"
      return
    end
    verb = args.dry_run? ? "Would upgrade" : "Upgrading"
    count = formula_installers.count + cask_installers.count
    oh1 "#{verb} #{count} outdated #{"package".pluralize(count)}:"
    formula_installers.each do |fi|
      f = fi.formula
      if f.optlinked?
        puts "#{f.full_specified_name} #{Keg.new(f.opt_prefix).version} -> #{f.pkg_version}"
      else
        puts "#{f.full_specified_name} #{f.pkg_version}"
      end
    end
    cask_installers.each do |(old_cask_installer, new_cask_installer)|
      old_cask = old_cask_installer.cask
      new_cask = new_cask_installer.cask
      puts "#{new_cask.full_name} #{old_cask.version} -> #{new_cask.version}"
    end
  end

  sig { params(formulae: T::Array[Formula], args: CLI::Args).returns(T::Array[FormulaInstaller]) }
  def create_formula_installers(formulae, args:)
    return [] if args.cask?

    if args.build_from_source? && !DevelopmentTools.installed?
      raise BuildFlagsError.new(["--build-from-source"], bottled: formulae.all?(&:bottled?))
    end

    Install.perform_preinstall_checks

    if formulae.blank?
      outdated = Formula.installed.select do |f|
        f.outdated?(fetch_head: args.fetch_HEAD?)
      end
    else
      outdated, not_outdated = formulae.partition do |f|
        f.outdated?(fetch_head: args.fetch_HEAD?)
      end

      not_outdated.each do |f|
        versions = f.installed_kegs.map(&:version)
        if versions.empty?
          ofail "#{f.full_specified_name} not installed"
        else
          version = versions.max
          opoo "#{f.full_specified_name} #{version} already installed"
        end
      end
    end

    return [] if outdated.blank?

    pinned = outdated.select(&:pinned?)
    outdated -= pinned
    formulae_to_install = outdated.map do |f|
      f_latest = f.latest_formula
      if f_latest.latest_version_installed?
        f
      else
        f_latest
      end
    end

    if !pinned.empty? && !args.ignore_pinned?
      ofail "Not upgrading #{pinned.count} pinned #{"package".pluralize(pinned.count)}:"
      puts pinned.map { |f| "#{f.full_specified_name} #{f.pkg_version}" } * ", "
    end

    if ENV["HOMEBREW_INSTALL_FROM_API"].present?
      formulae_to_install.map! do |formula|
        next formula if formula.tap.present? && !formula.core_formula?
        next formula unless Homebrew::API::Bottle.available?(formula.name)

        Homebrew::API::Bottle.fetch_bottles(formula.name)
        Formulary.factory(formula.name)
      rescue FormulaUnavailableError
        formula
      end
    end

    Upgrade.create_formula_installers(
      formulae_to_install,
      flags:                      args.flags_only,
      dry_run:                    args.dry_run?,
      installed_on_request:       args.named.present?,
      force_bottle:               args.force_bottle?,
      build_from_source_formulae: args.build_from_source_formulae,
      interactive:                args.interactive?,
      keep_tmp:                   args.keep_tmp?,
      force:                      args.force?,
      debug:                      args.debug?,
      quiet:                      args.quiet?,
      verbose:                    args.verbose?,
    )
  end

  def fetch_outdated_formulae(formula_installers, args:)
    return if args.dry_run?

    Upgrade.fetch_formulae(formula_installers)
  end

  def upgrade_outdated_formulae(formula_installers, args:)
    Upgrade.upgrade_formulae(formula_installers, dry_run: args.dry_run?, verbose: args.verbose?)

    Upgrade.check_installed_dependents(
      formula_installers.map(&:formula),
      flags:                      args.flags_only,
      dry_run:                    args.dry_run?,
      installed_on_request:       args.named.present?,
      force_bottle:               args.force_bottle?,
      build_from_source_formulae: args.build_from_source_formulae,
      interactive:                args.interactive?,
      keep_tmp:                   args.keep_tmp?,
      force:                      args.force?,
      debug:                      args.debug?,
      quiet:                      args.quiet?,
      verbose:                    args.verbose?,
    )
  end

  sig { params(casks: T::Array[Cask::Cask], args: CLI::Args).returns(T::Array[T::Array[Cask::Installer]]) }
  def create_cask_installers(casks, args:)
    return [] if args.formula?

    if ENV["HOMEBREW_INSTALL_FROM_API"].present?
      casks = casks.map do |cask|
        next cask if cask.tap.present? && cask.tap != "homebrew/cask"
        next cask unless Homebrew::API::CaskSource.available?(cask.token)

        Cask::CaskLoader.load Homebrew::API::CaskSource.fetch(cask.token)
      end
    end

    Cask::Cmd::Upgrade.create_cask_installers(
      *casks,
      force:          args.force?,
      greedy:         args.greedy?,
      dry_run:        args.dry_run?,
      binaries:       args.binaries?,
      quarantine:     args.quarantine?,
      require_sha:    args.require_sha?,
      skip_cask_deps: args.skip_cask_deps?,
      verbose:        args.verbose?,
      args:           args,
    )
  end

  def fetch_outdated_casks(cask_installers, args:)
    return if args.dry_run?

    Cask::Cmd::Upgrade.fetch_casks(cask_installers) do |exception|
      ofail exception.message
    end
  end

  def upgrade_outdated_casks(cask_installers, args:)
    return if args.dry_run?

    Cask::Cmd::Upgrade.upgrade_casks(cask_installers) do |exception|
      ofail exception.message
    end
  end
end
