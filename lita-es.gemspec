Gem::Specification.new do |spec|
  spec.name          = "lita-es"
  spec.version       = "0.1.0"
  spec.authors       = ["Johan van den Dorpe"]
  spec.email         = ["johan.vandendorpe@sohonet.com"]
  spec.description   = "Elasticsearch LITA"
  spec.summary       = "Elasticsearch LITA"
  spec.homepage      = "https://github.com/sohonet/lita-elasticsearch"
  spec.license       = "All Rights Reserved"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.8"
  spec.add_runtime_dependency "elasticsearch", "7.1.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  if RUBY_PLATFORM != 'java'
    spec.add_development_dependency "pry-byebug"
  end
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end
