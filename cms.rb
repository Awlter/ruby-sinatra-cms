require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require 'bcrypt'

require 'yaml'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def require_signin
  unless session.key?(:username)
    session[:message] = "You must be signed in to do that"
    redirect '/'
  end
end

def load_user_credentials
  file_path = if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end

  YAML.load_file(file_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get '/users/signin' do
  erb :signin
end

get "/create" do
  require_signin
  erb :create
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signin

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"

    redirect '/'
  else
    session[:message] = "Invalid Credentials"
    status 422

    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."

  redirect '/'
end

def create_document(name, content="")
  file_path = File.join(data_path, name)
  File.write(file_path, content)
end

post "/create" do
  require_signin

  filename = params[:filename].strip
  file, extention = filename.split('.')

  if file.nil? || file.empty?
    session[:message] = "A file name is needed."
    status 422

    erb :create
  elsif extention.nil? || !(%q(txt md).include? extention)
    session[:message] = "The extention is invalid."
    status 422

    erb :create
  else
    create_document(filename)
    session[:message] = "#{filename} has been created."
    redirect '/'
  end
end

post '/:filename/delete' do
  require_signin

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."

  redirect '/'
end

post "/:filename" do
  require_signin

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end