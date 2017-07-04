# frozen_string_literal: true

require "sinatra"
require "yaml"
require "json"
require "rest-client"
require "digest/sha1"

require "sinatra/reloader" if development?

def config
  @config ||= YAML.safe_load(File.read("settings.yaml"))
rescue
  abort "ERROR: settings.yaml could not be loaded. See settings.yaml.example"
end

# Validate config
%w[gitlab_secret discord_webhook_url listen_port].each do |key|
  next if config.key? key
  abort "ERROR: Configuration is missing '#{key}'. See settings.yaml.example"
end

set :port, config["listen_port"]

helpers do
  def constant_time_equal(a, b)
    Digest::SHA1.hexdigest(a) == Digest::SHA1.hexdigest(b) rescue false
  end

  def gitlab_secret
    config["gitlab_secret"]
  end

  def discord_url
    config["discord_webhook_url"]
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
    payload = JSON.dump(content: erb(:push, locals: @request_body))

    begin
      RestClient.post discord_url, payload, content_type: :json
      "OK"
    rescue RestClient::ExceptionWithResponse => err
      status 500
      "Discord Webhook returned status code #{err.response.code}"
    end
  else
    status 400
    format "Unkown object_kind: '%s'",
           Rack::Utils.escape_html(@request_body["object_kind"])
  end
end
