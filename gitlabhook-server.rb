require "sinatra"
require "yaml"
require "digest/sha1"

require "sinatra/reloader" if development?

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

  # View helpers

  def md_link(text, url)
    format "[%s](%s)", text, url
  end

  def branch_from_ref(ref)
    ref[/\w+\z/]
  end
end

before do
  halt 400 unless request.env["CONTENT_TYPE"] == "application/json"
  halt 400 unless request.has_header? "HTTP_X_GITLAB_TOKEN"
  halt 401 unless constant_time_equal(gitlab_secret,
                                      request.env["HTTP_X_GITLAB_TOKEN"])

  # Pre-parse JSON body
  request.body.rewind
  @request_body = JSON.parse request.body.read
end

post "/push" do
  case @request_body["object_kind"]
  when "push"
    erb :push, locals: @request_body
  else
    status 400
    format "Unkown object_kind: '%s'",
           Rack::Utils.escape_html(@request_body["object_kind"])
  end
end
