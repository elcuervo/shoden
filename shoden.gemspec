Gem::Specification.new do |s|
  s.name              = "shoden"
  s.version           = "1.0"
  s.summary           = "Object hash mapper for postgres"
  s.description       = "Slim postgres models"
  s.authors           = ["elcuervo"]
  s.licenses          = %w[MIT HUGWARE]
  s.email             = ["yo@brunoaguirre.com"]
  s.homepage          = "http://github.com/elcuervo/shoden"
  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files test`.split("\n")

  s.add_dependency("pg", "~> 1.1")

  s.add_development_dependency("cutest", "~> 1.2")
  s.add_development_dependency("simplecov", "~> 0.16")
end
