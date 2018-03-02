ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    file_path = File.join(data_path, name)
    File.open(file_path, "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    
  end

  def test_viewing_text_document
    create_document "history.txt", "Ruby 0.95 released."

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_nonexist_document
    get "/test_nonexist_document.txt"

    assert_equal 302, last_response.status
    assert_equal "test_nonexist_document.txt does not exist.", session[:message] 
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_view_creating_document
    get '/create', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form action="
    assert_includes last_response.body, "<button type="
  end

  def test_creating_document
    post '/create', { filename: "test_file.txt", content: "new content"}, admin_session

    assert_equal 302, last_response.status

    assert_equal "test_file.txt has been created.", session[:message]
  end

  def test_fail_creating_document
    post '/create', { filename: ".txt" }, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "A file name is needed."
  end

  def test_deleting_document
    create_document "changes.txt"

    post '/changes.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been deleted.", session[:message]

    get '/'
    refute_includes last_response.body, %q(href="/changes.txt")
  end

  def test_sign_in_view
    get '/users/signin'

    assert_equal 200, last_response.status

    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "<input type=\"password\" name=\"password\" />"
  end

  def test_sucess_sign_in
    post '/users/signin', { username: 'admin', password: 'secret' }

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get '/'
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "<button type=\"=submit\">Sign out</button>"
  end

  def test_fail_sign_in
    post '/users/signin', { username: 'xxx', password: 'xxx'}

    assert_equal 422, last_response.status
    assert_equal nil, session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_equal nil, session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end
end