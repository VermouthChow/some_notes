## Speed ​​up test time

# rails 6.0.x
# sqlite 3
# minitest
# Parallel Testing with Processes, worker > 1
# test from start, without any cache


# test_helper.rb
# worker_count > 1 (eg: 2, 3,.. , Etc.nprocessors)
parallelize(workers: worker_count)
...


# tesks/my_task.rb
namespace :test_v do

  desc "test prepare and run"
  task :prepare_and_run do |task, args|
    # db:drop db:create db:migrate db:schema:load
    system "RAILS_ENV=test bundle exec rails db:test:prepare"

    test_db = Rails.configuration.database_configuration["test"]["database"]

    worker_count.times { |i|
      db_name = "#{test_db}-#{i}"

      # copy direct, save db prepare time
      system("cp #{test_db} #{db_name}")
    }

    system "bundle exec rails test"
  end

end
