require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'

root = File.expand_path('..', __dir__)
harness = <<~'RUBY'
  require 'json'
  $calls = []
  $scenario = JSON.parse(ENV.fetch('SCENARIO'))
  module Process
    def self.kill(*args); $calls << ['kill', *args]; end
    def self.wait(*args); $calls << ['wait', *args]; end
  end
  def `(command)
    case command
    when /ps .* -o pid,ppid/ then JSON.generate('process-information' => {'process' => $scenario.fetch('processes', [])})
    when /ps -o pid,comm/ then JSON.generate('process-information' => {'process' => $scenario.fetch('identity', [])})
    when 'id -un' then "tester\n"
    when 'mount --libxo json' then JSON.generate('mount' => {'mounted' => $scenario.fetch('mounted', [])})
    else raise "unexpected command: #{command}"
    end
  end
  def system(*args); $calls << args; true; end
  load ARGV.fetch(0)
  puts JSON.generate($calls)
RUBY

Dir.mktmpdir('lsu-cleanup-test') do |home|
  FileUtils.mkdir_p(File.join(home, '.steam/tmp'))
  pidfile = File.join(home, '.steam/steam.pid')
  run = lambda do |name, scenario|
    out, err, status = Open3.capture3({'HOME' => home, 'SCENARIO' => JSON.generate(scenario)}, RbConfig.ruby, '-e', harness, File.join(root, "bin/#{name}"))
    raise "#{name} failed: #{err}" unless status.success?
    JSON.parse(out)
  end
  %w[0 -1 garbage 123junk].each do |pid|
    File.write(pidfile, pid)
    raise "invalid PID #{pid} signalled" unless run.call('lsu-kill', {}).empty?
  end
  File.write(pidfile, '123')
  raise 'stale PID signalled' unless run.call('lsu-kill', {'identity' => [{'pid' => '123', 'command' => 'bash'}], 'processes' => [{'pid' => '124', 'ppid' => '123', 'state' => 'S', 'command' => 'child'}]}).empty?
  raise 'missing PID signalled' unless run.call('lsu-kill', {}).empty?
  calls = run.call('lsu-kill', {'identity' => [{'pid' => '123', 'command' => 'steam'}]})
  raise 'Steam PID not selected' unless calls == [['kill', 'KILL', 123], ['wait', 123]]
  tmp = File.realpath(File.join(home, '.steam/tmp'))
  nodes = [tmp, "#{tmp}/child", "#{tmp}2", "#{tmp}-other"]
  calls = run.call('lsu-umount', {'mounted' => nodes.map { |node| {'mounter' => 'tester', 'node' => node} } + [{'mounter' => 'other', 'node' => "#{tmp}/other"}]})
  raise "wrong mount selection: #{calls.inspect}" unless calls == [['umount', "#{tmp}/child"], ['umount', tmp]]
end
puts 'Cleanup safety tests passed'
