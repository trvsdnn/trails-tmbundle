require 'pathname'

bundle_lib = ENV['TM_BUNDLE_SUPPORT'] + '/lib'
$LOAD_PATH.unshift(bundle_lib) if ENV['TM_BUNDLE_SUPPORT'] and !$LOAD_PATH.include?(bundle_lib)
require 'rails/unobtrusive_logger'

def focused_test
  arg = ""
  n = ENV['TM_LINE_NUMBER'].to_i

  should, spec, context, name, test_name = nil, nil, nil

  File.open(ENV['TM_FILEPATH']) do |f|
    # test/unit
    lines     = f.read.split("\n")[0...n].reverse
    name      = lines.find { |line| line =~ /^\s*def test[_a-z0-9]*[\?!]?/i }.to_s.sub(/^\s*def (.*?)\s*$/) { $1 }
    # test helper
    test_name = $2 || $3 if lines.find { |line| line =~ /^\s*test\s+('(.*)'|"(.*)")+\s*(\{|do)/ }
    # test/spec.
    spec      = $3 || $4 if lines.find { |line| line =~ /^\s*(specify|it)\s+('(.*)'|"(.*)")+\s*(\{|do)/ }
    context   = $3 || $4 if lines.find { |line| line =~ /^\s*(context|describe)\s+('(.*)'|"(.*)")+\s*(\{|do)/ }
    # shoulda.
    should    = $3 || $4 if lines.find { |line| line =~ /^\s*(should)\s+('(.*)'|"(.*)")+\s*(\{|do)/ }
    context   = $3 || $4 if lines.find { |line| line =~ /^\s*(context)\s+('(.*)'|"(.*)")+\s*(\{|do)/ }
  end

  if name && !name.empty?
    arg = "--name=#{name}"
  elsif test_name && !test_name.empty?
    arg = "--name=test_#{test_name.gsub(/\s+/,'_')}"
  elsif spec && !spec.empty? && context && !context.empty?
    arg = %Q{--name="/test_spec \\{.*#{context}\\} \\d{3} \\[#{spec}\\]/"}
  elsif should && !should.empty? && context && !context.empty?
    test_name = "#{context} should #{should}".gsub(/[\$\?\+\.\s\'\"\(\)]/,'.?')
    arg = "--name=/#{test_name}/"
  else
    arg = ""
  end

  arg
end

def current_test_file
  ENV["TM_FILEPATH"][(ENV['TM_PROJECT_DIRECTORY'].size + 1)..-1]
end

def applescript
  <<-APPLESCRIPT
  set windowTitle to "TextMate"
  set theWindow to null
  set cmd to "bin/rails test #{current_test_file} #{focused_test}"


  on centerWindow(testWindow)
  tell application "Finder"
    set screenSize to bounds of window of desktop
    set screenWidth to item 3 of screenSize
    set screenHeight to item 4 of screenSize
    set windowWidth to screenWidth / 1.5
    set bounds of testWindow to {(screenWidth - windowWidth) / 2.0, 0, (screenWidth + windowWidth) / 2.0, screenHeight}
  end tell
  end centerWindow

  if application "Terminal" is running then
    tell application "Terminal"
      activate

      repeat with w in every window
        if custom title of w is equal to windowTitle then
          set theWindow to w
        end if
      end repeat

      if theWindow is not null then
        set testTab to first tab of theWindow
        my centerWindow(theWindow)
        do script " cd #{ENV['TM_PROJECT_DIRECTORY']}; clear" in testTab
        do script cmd in testTab
      else
        set testTab to do script
        set theWindow to first window of (every window whose tabs contains testTab)
        set custom title of theWindow to windowTitle
        my centerWindow(theWindow)
        do script " cd #{ENV['TM_PROJECT_DIRECTORY']}; clear" in testTab
        do script cmd in testTab
        end if
    end tell
  else
    tell application "Terminal"
      activate

      delay 0.35

      set theWindow to the front window
      set testTab to first tab of theWindow
      set custom title of theWindow to windowTitle
      my centerWindow(theWindow)
      do script " cd #{ENV['TM_PROJECT_DIRECTORY']}; clear" in testTab
      do script cmd in testTab
    end tell
  end if
  APPLESCRIPT
end


$logger.debug applescript

open('|osascript', 'w') { |io| io << applescript }
