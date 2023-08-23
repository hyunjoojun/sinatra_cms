ENV['RACK_ENV'] = 'test'

require 'fileutils'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class CMSTest < Minitest::Test
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

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_text_document
    create_document('history.txt', 'Yukihiro Matsumoto dreams up Ruby.')

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'Yukihiro Matsumoto dreams up Ruby.'
  end

  def test_document_not_found
    get '/nofile.txt'

    assert_equal 302, last_response.status
    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'nofile.txt does not exist'

    get '/'
    refute_includes last_response.body, 'nofile.txt does not exist'
  end

  def test_viewing_markdown_document
    create_document('about.md', '# Ruby is...')

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_editing_document
    create_document 'about.md'

    get '/about.md/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status
    get last_response['Location']

    assert_includes last_response.body, 'changes.txt has been updated.'

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_view_new_document_form
    get '/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post '/create', filename: 'test.txt'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'test.txt has been created.'

    get '/'
    assert_includes last_response.body, 'test.txt'
  end

  def test_create_new_document_without_filename
    post '/create', filename: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_delete_document
    create_document 'testfile.txt'
    post '/testfile.txt/delete'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'testfile.txt has been deleted.'

    get '/'
    refute_includes last_response.body, 'testfile.txt'
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'Welcome!'
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_signin_with_bad_credentials
    post '/users/signin', username: 'guest', password: 'password'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_signout
    post '/users/signin', username: 'admin', password: 'secret'
    get last_response['Location']
    assert_includes last_response.body, 'Welcome!'

    post '/users/signout'
    get last_response['Location']

    assert_includes last_response.body, 'You have been signed out.'
    assert_includes last_response.body, 'Sign In'
  end
end
