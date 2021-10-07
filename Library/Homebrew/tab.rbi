# typed: strict

class Tab
  sig { returns(T::Array[String]) }
  attr_accessor :aliases

  sig { returns(T.nilable(String)) }
  attr_accessor :arch

  sig { returns(T::Boolean) }
  attr_accessor :built_as_bottle

  sig { returns(T::Hash[String, T.nilable(String)]) }
  attr_accessor :built_on

  sig { returns(T.nilable(T::Array[String])) }
  attr_accessor :changed_files

  sig { returns(String) }
  attr_accessor :homebrew_version

  sig { returns(T::Boolean) }
  attr_accessor :installed_as_dependency

  sig { returns(T::Boolean) }
  attr_accessor :installed_on_request

  sig { returns(T::Boolean) }
  attr_accessor :poured_from_bottle

  sig { returns(T::Hash[String, T.untyped]) }
  attr_accessor :source

  sig { returns(T.nilable(String)) }
  attr_accessor :stdlib

  sig { returns(Pathname) }
  attr_accessor :tabfile

  sig { returns(T.nilable(Integer)) }
  attr_accessor :time

  sig { params(used_options: T::Array[String]).void }
  def used_options=(used_options); end

  sig { params(unused_options: T::Array[String]).void }
  def unused_options=(unused_options); end
end
