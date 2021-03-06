require 'quke/configuration'

After('~@nonweb') do |scenario|
  $fail_count ||= 0

  if Quke::Quke.config.browserstack.using_browserstack?
    $session_id = page.driver.browser.session_id
  end

  if scenario.failed?
    $fail_count = $fail_count + 1

    # Tell Cucumber to quit after first failing scenario when stop_on_error is
    # true.
    # Also experience has shown that should a major element of your service go
    # down all your tests will start failing which means you can be swamped
    # with output from `save_and_open_page`. Using a global count of the
    # number of fails, if it hits 5 it will cause cucumber to close.
    if Quke::Quke.config.stop_on_error || $fail_count >= 5
      Cucumber.wants_to_quit = true
    else
      # If we're not using poltergiest and the scenario has failed, we want
      # to save a copy of the page and open it automatically using Launchy.
      # We wrap this in a begin/rescue in case of any issues in which case
      # it defaults to outputting the source to STDOUT.
      begin
        # rubocop:disable Lint/Debugger
        save_and_open_page
        # rubocop:enable Lint/Debugger
      rescue StandardError
        # handle e
        puts "FAILED: #{scenario.name}"
        puts "FAILED: URL of the page with the failure #{page.current_path}"
        puts ''
        puts page.html
      end
    end
  end
end
