require 'rails/generators'
require 'rails/generators/base'

module Sidekiq
  module Superworker
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        include ::Rails::Generators::Migration
        source_root File.expand_path('../templates', __FILE__)
        desc "Install the migrations"

        def self.next_migration_number(path)
          unless @prev_migration_nr
            @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
          else
            @prev_migration_nr += 1
          end
          @prev_migration_nr.to_s
        end

        def install_migrations
          migration_template "create_sidekiq_superworker_subjobs.rb", "db/migrate/create_sidekiq_superworker_subjobs.rb"
        end
      end 
    end
  end
end