#!/usr/local/bin/ruby
# encoding: UTF-8

def linux_to_native_path(file)
  if file.start_with?('/') && File.exist?(File.join('/compat/linux', file))
    File.join('/compat/linux', file)
  else
    file
  end
end

options, files = ARGV.partition{|arg| arg.start_with?('-')}

if options.size == 0 || (options.size == 1 && options.include?('-L'))
  for file in files
    IO.popen(['/usr/bin/file', *options, '--', linux_to_native_path(file)], &:read).then do |output|
      print output.gsub('/compat/linux', '')
    end
    exit($?.exitstatus || 1) unless $?.success?
  end
else
  raise
end
