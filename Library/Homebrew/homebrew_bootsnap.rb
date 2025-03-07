# typed: false
# frozen_string_literal: true

homebrew_bootsnap_enabled = !ENV["HOMEBREW_NO_BOOTSNAP"] &&
                            ENV["HOMEBREW_BOOTSNAP"] &&
                            # portable ruby doesn't play nice with bootsnap
                            !ENV["HOMEBREW_FORCE_VENDOR_RUBY"] &&
                            (!ENV["HOMEBREW_MACOS_VERSION"] || ENV["HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH"]) &&
                            # Apple Silicon doesn't play nice with bootsnap
                            (ENV["HOMEBREW_PROCESSOR"] == "Intel")

# we need some development tools to build bootsnap native code
development_tools_installed = if !homebrew_bootsnap_enabled
  false
elsif RbConfig::CONFIG["host_os"].include? "darwin"
  File.directory?("/Applications/Xcode.app") || File.directory?("/Library/Developer/CommandLineTools")
else
  File.executable?("/usr/bin/clang") || File.executable?("/usr/bin/gcc")
end

if homebrew_bootsnap_enabled && development_tools_installed
  require "rubygems"

  begin
    require "bootsnap"
  rescue LoadError
    unless ENV["HOMEBREW_BOOTSNAP_RETRY"]
      require "utils/gems"
      Homebrew.install_bundler_gems!

      ENV["HOMEBREW_BOOTSNAP_RETRY"] = "1"
      exec ENV["HOMEBREW_BREW_FILE"], *ARGV
    end
  end

  ENV.delete("HOMEBREW_BOOTSNAP_RETRY")

  if defined?(Bootsnap)
    cache = ENV["HOMEBREW_CACHE"] || ENV["HOMEBREW_DEFAULT_CACHE"]
    # Can't use .blank? here because we haven't required active_support yet.
    raise "Needs HOMEBREW_CACHE or HOMEBREW_DEFAULT_CACHE!" if cache.nil? || cache.empty? # rubocop:disable Rails/Blank

    Bootsnap.setup(
      cache_dir:          cache,
      load_path_cache:    true,
      compile_cache_iseq: true,
      compile_cache_yaml: true,
    )
  else
    $stderr.puts "Error: HOMEBREW_BOOTSNAP could not `require \"bootsnap\"`!\n\n"
  end
end
