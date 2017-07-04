require "sinatra"
require "yaml"
require "digest/sha1"

helpers do
  def config
    @config ||= YAML.load(File.read("settings.yaml"))
  end

  def constant_time_equal(a, b)
    Digest::SHA1.hexdigest(a) == Digest::SHA1.hexdigest(b) rescue false
  end

  def gitlab_secret
    config.dig("gitlab", "secret") || raise("No gitlab secret configured!")
  end
end

before do
  halt 401 unless constant_time_equal(gitlab_secret, request.env["HTTP_X_GITLAB_TOKEN"])
end

post "/push" do
  
end
