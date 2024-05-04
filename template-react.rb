=begin
Template Name: React
Author: Pablo Zambranp
Author URI: https://pablo-zambrano.netlify.app/
Instructions: $ rails new myapp -d <postgresql, mysql, sqlite3> -m template.rb -j esbuild -d postgresql -T
=end
rails_api_port=3001
def source_paths
    [File.expand_path(File.dirname(__FILE__))]
  end
  
  def add_gems
    gem 'devise'
    gem 'friendly_id'
    gem 'foreman'
    gem 'rack-cors'
    gem 'sidekiq'
    gem 'stripe'
    gem 'bcrypt'
    gem 'jsonapi-serializer'
  end
  

  
  
  def add_storage_and_rich_text
    rails_command "active_storage:install"
    rails_command "action_text:install"
  end
  
  def add_users
    # Install Devise
    generate "devise:install"
  
    # Configure Devise
    environment "config.action_mailer.default_url_options = { host: 'localhost', port: #{rails_api_port} }",
                env: 'development'
  
    route "root to: 'homepage#index'"
  
    # Create Devise User
    generate :devise, "User", "name", "admin:boolean"

    # set admin boolean to false by default
    in_root do
      migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
      gsub_file migration, /:admin/, ":admin, default: false"
    end
    
  end

  
  def add_sidekiq
    environment "config.active_job.queue_adapter = :sidekiq"
  
    insert_into_file "config/routes.rb",
      "require 'sidekiq/web'\n\n",
      before: "Rails.application.routes.draw do"
  
    content = <<-RUBY
      authenticate :user, lambda { |u| u.admin? } do
        mount Sidekiq::Web => '/sidekiq'
      end

      
    RUBY
    insert_into_file "config/routes.rb", "#{content}\n\n", after: "Rails.application.routes.draw do\n"
  end
  
  def add_friendly_id
    generate "friendly_id"
  end
  
  def add_react_plugins
    run "yarn add react react-dom react-router-dom"
  
  end
  
  # Main setup
  source_paths
  
  add_gems
  
  after_bundle do
   
    add_react_plugins
    add_storage_and_rich_text
    add_users
    add_sidekiq
    add_friendly_id

    # Generate controller

    rails_command  "g controller Homepage index"

    home_jsx= <<-JSX
        import React from "react";
        import { Link } from "react-router-dom";

        export default () => (
        <div className="vw-100 vh-100 primary-color d-flex align-items-center justify-content-center">
            <div className="jumbotron jumbotron-fluid bg-transparent">
                <div className="container secondary-color">
                    <h1 className="display-4">Food Recipes</h1>
                    <p className="lead">
                        A curated list of recipes for the best homemade meal and delicacies.
                    </p>
                    <hr className="my-4" />
                    <Link
                        to="/recipes"
                        className="btn btn-lg custom-button"
                        role="button"
                        >
                        View Recipes
                    </Link>
                </div>
            </div>
        </div>
        );

    JSX

    routes_jsx= <<-JSX 
        import React from "react";
        import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
        import Home from "../components/Home";

        export default (
            <Router>
            <Routes>
                <Route path="/" element={<Home />} />
            </Routes>
            </Router>
        );

    JSX

    app_jsx= <<-JSX
        import React from "react";
        import Routes from "../routes";

        export default props => <>{Routes}</>;

    JSX

    index_jsx= <<-JSX
        import React from "react";
        import { createRoot } from "react-dom/client";
        import App from "./App";

        document.addEventListener("turbo:load", () => {
        const root = createRoot(
            document.body.appendChild(document.createElement("div"))
        );
        root.render(<App />);
        });

    JSX

    cors_con= <<-RUBY
    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "http://localhost:#{rails_api_port}"
        resource '*', headers: :any, methods: [:get, :post, :patch, :put], credentials: true
      end
    end
    RUBY

    session_store =<<-RUBY
    Rails.application.config.session_store :cookie_store, key: "_authentication_app", domain:"localhost:#{rails_api_port}"
    RUBY

    devise_routes= <<-RUBY
    , path: '', path_names: {
      sign_in: 'login',
      sign_out: 'logout',
      registration: 'signup'
    },
    controllers: {
      sessions: 'users/sessions',
      registrations: 'users/registrations'
    }
    RUBY

    application_controller=<<-RUBY
    before_action :configure_permitted_parameters, if: :devise_controller?
    protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name avatar])
      devise_parameter_sanitizer.permit(:account_update, keys: %i[name avatar])
    end
    RUBY

    registration_controller=<<-RUBY
    respond_to :json
    private

    def respond_with(current_user, _opts = {})
      if resource.persisted?
        render json: {
          status: {code: 200, message: 'Signed up successfully.'},
          data: UserSerializer.new(current_user).serializable_hash[:data][:attributes]
        }
      else
        render json: {
          status: {message: "User couldn't be created successfully. #{current_user.errors.full_messages.to_sentence}"}
        }, status: :unprocessable_entity
      end
    end
    RUBY

    session_controller=<<-RUBY
    respond_to :json
    private
    def respond_with(current_user, _opts = {})
      render json: {
        status: { 
          code: 200, message: 'Logged in successfully.',
          data: { user: UserSerializer.new(current_user).serializable_hash[:data][:attributes] }
        }
      }, status: :ok
    end
    RUBY



    # After install react this are the initial setting =========
    in_root do
        view = Dir.glob("app/views/homepage/index.html.erb")
        # Replacing all content from file with empty
        gsub_file view[0], /./, ""
        # Create empty directory
        empty_directory "app/javascript/components"
        # Add content to file
        insert_into_file "app/javascript/application.js", "\nimport './components'", after: '@rails/actiontext"'
        # Create file jsx
        create_file "app/javascript/components/Home.jsx"
        # Insert content into the Home.jsx component
        insert_into_file "app/javascript/components/Home.jsx", "#{home_jsx}"
        # Create routes directory
        empty_directory "app/javascript/routes"
        # Create routes.jsx file
        create_file "app/javascript/routes/index.jsx"
        # Insert content into the routes/index.jsx component
        insert_into_file "app/javascript/routes/index.jsx", "#{routes_jsx}"
        # Create file jsx
        create_file "app/javascript/components/App.jsx"
        # Insert content into the App.jsx component
        insert_into_file "app/javascript/components/App.jsx", "#{app_jsx}"
         # Create file jsx
         create_file "app/javascript/components/index.jsx"
         # Insert content into the index.jsx component
         insert_into_file "app/javascript/components/index.jsx", "#{index_jsx}"



      end
    # =====================================================================



    # Rails API initial settings =============================================

    rails_command "g devise:controllers users -c sessions registrations"
    rails_command "generate serializer user id email name"

    in_root do
   
      # Create empty directories
      empty_directory "app/controllers/api"
      empty_directory "app/controllers/api/v1"
      # Create file cors.rb
      create_file "config/initializers/cors.rb"
      # Create file session_store.rb
      create_file "config/initializers/session_store.rb"
      # Insert content into cors.rb
      insert_into_file "config/initializers/cors.rb", "#{cors_con}"
      # Insert content into session_store.rb
      insert_into_file "config/initializers/session_store.rb", "#{session_store}"
      # uncoment line
      uncomment_lines "config/initializers/devise.rb", /config.navigational_formats/
      # Replacing all content
      devise_config = Dir.glob("config/initializers/devise.rb")
      gsub_file devise_config[0], /config.navigational_formats = \['\*\/\*', :html, :turbo_stream\]/, "config.navigational_formats = []"

      port_puma = Dir.glob("config/puma.rb")
      gsub_file port_puma[0], /port ENV.fetch\("PORT"\) \{ 3000 \}/, "port ENV.fetch("PORT") { #{rails_api_port} }"
      # Insert in controllers
      insert_into_file "app/controllers/users/sessions_controller.rb", "\n  #{session_controller}", after: "Devise::SessionsController"
      insert_into_file "app/controllers/users/registrations_controller.rb", "\n  #{registration_controller}", after: "Devise::RegistrationsController"
      # Insert routes devise
      insert_into_file "config/routes.rb", "#{devise_routes}", after: "devise_for :users"
      # Insert content in Application controller
      insert_into_file "app/controllers/application_controller.rb", "\n\n#{application_controller}", after: "ActionController::Base"


    end 

    # Migrate
    rails_command "db:create"
    rails_command "db:migrate"
   
    say
    say "React-rails init app successfully created! 👍", :green
    say
    say "Switch to your app by running:"
    say "$ cd #{app_name}", :yellow
    say
    say "Then run:"
    say "$ ./bin/dev", :green
  end

