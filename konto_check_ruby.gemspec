# frozen_string_literal: true

require_relative "lib/konto_check_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "konto_check_ruby"
  spec.version = KontoCheckRuby::VERSION
  spec.authors = ["tickettoaster GmbH", "Peter Horn"]
  spec.email = ["ph@tickettoaster.de"]

  spec.summary = "Pure Ruby port of konto_check: German bank account and IBAN validation"
  spec.description = <<~DESC
    konto_check_ruby is a plain Ruby port (no C extension) of Michael Plugge's
    C library konto_check. It validates German bank account numbers with all
    check digit methods of the Deutsche Bundesbank (00 to E4), generates and
    validates IBANs including the Bundesbank IBAN rules, and looks up bank
    data (name, BIC, place, ...). It reads the LUT files of the original
    library as well as the bank code files (Bankleitzahlendatei) published by
    the Deutsche Bundesbank and can generate LUT files itself. The modules
    KontoCheck and KontoCheckRaw are compatible with the original konto_check gem.
  DESC
  spec.homepage = "https://github.com/provideal/konto_check_ruby"
  spec.license = "LGPL-2.1-or-later"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "data/*", "bin/*", "LICENSE", "COPYRIGHT", "README.md", "CHANGELOG.md"]
  spec.bindir = "bin"
  spec.executables = Dir["bin/*"].map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
