Gem::Specification.new do |s|
  s.authors = "Irenej Marc"
  s.name = %q{commands}
  s.version = "0.0.1"
  s.date = %q{2020-06-19}
  s.summary = %q{Fancy commands with fancy logging}
  s.license = "MIT"
  s.homepage = "https://github.com/IrenejMarc/commands"
  s.files = [
    "lib/commands.rb"
  ]
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rails", '> 4'
end
