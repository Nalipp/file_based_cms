ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def app
    Sinatra::Application
  end

  def test_index
    create_document("about.md")
    create_document("changes.md")

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.md"
  end

  def test_history_page
    create_document("history.md", "Ruby 0.95 released")
    get "/history.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_error_message_for_page_missing
    get "/incorrect.md"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "incorrect.md does not exist."
  end

  def test_viewing_text_document
    create_document "history.txt", "1993 - Yukihiro Matsumoto"
    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto"
  end

  def test_viewing_markdown_document
    create_document "/about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  # test/cms_test.rb
  def test_editing_document
    create_document("/changes.md", %q(<button type="submit"))
    get "/changes.md/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.md", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.md has been updated"

    get "/changes.md"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_get_new_document
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status

    get last_response["location"]

    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"

  end

  def test_create_document_without_filename
    post "/create", filename: ""

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_deleteing_document
    create_document("test.txt")
    post "/test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted."

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: 'admin', password: 'secret'

    assert_equal 302, last_response.status

    get last_response["location"]

    assert_includes last_response.body, "Welcome!"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signed_in_with_bad_credentials
    post "/users/signin", username: 'baddata', password: 'incorect'
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    post "/users/signin", username: 'admin', password: 'secret'
    get last_response["location"]
    assert_includes last_response.body, "Welcome!"

    post "/users/signout"
    get last_response["location"]

    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
  end
end
