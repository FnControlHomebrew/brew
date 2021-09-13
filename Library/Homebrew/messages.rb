# typed: true
# frozen_string_literal: true

# A {Messages} object collects messages that may need to be displayed together
# at the end of a multi-step `brew` command run.
class Messages
  extend T::Sig

  attr_reader :caveats, :package_count, :install_times

  sig { void }
  def initialize
    @caveats = []
    @package_count = 0
    @install_times = []
    @caught_exceptions = []
  end

  def record_caveats(package, caveats)
    @caveats.push(package: package, caveats: caveats)
  end

  def package_installed(package, elapsed_time)
    @package_count += 1
    @install_times.push(package: package, time: elapsed_time)
  end

  def display_messages(display_times: false)
    display_caveats
    display_install_times if display_times
  end

  def display_caveats
    return if @package_count <= 1
    return if @caveats.empty?

    oh1 "Caveats"
    @caveats.each do |c|
      ohai c[:package], c[:caveats]
    end
  end

  def display_install_times
    return if install_times.empty?

    oh1 "Installation times"
    install_times.each do |t|
      puts format("%<package>-20s %<time>10.3f s", t)
    end
  end

  def catch_exception(package, exception, display_message:)
    exception = exception.exception("#{package}: #{exception}")
    @caught_exceptions << exception
    onoe exception.message if display_message
    Homebrew.failed = true
  end

  def raise_caught_exceptions
    return if @package_count <= 1
    return if @caught_exceptions.empty?
    raise MultiplePackageErrors, @caught_exceptions if @caught_exceptions.count > 1
    raise @caught_exceptions.first if @caught_exceptions.count == 1
  end
end
