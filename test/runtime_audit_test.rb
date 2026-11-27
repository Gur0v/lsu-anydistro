require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

root = File.expand_path('..', __dir__)
Dir.mktmpdir do |home|
  runtime = File.join(home, '.steam/steam/ubuntu12_32')
  FileUtils.mkdir_p(File.join(runtime, 'steam-runtime_1'))
  File.write(File.join(runtime, 'steam-runtime_1/partial'), 'partial')
  File.write(File.join(runtime, 'steam-runtime.tar.xz.checksum'), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n")
  File.write(File.join(runtime, 'steam-runtime.tar.xz'), 'archive')
  harness = <<~'RUBY'
    require ARGV.shift
    def `(cmd)
      return "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n" if cmd.start_with?('/sbin/md5')
      return "scout_1\n" if cmd.start_with?('/usr/bin/tar')
      super
    end
    def system(*args)
      if args.first == 'tar'
        File.write(File.join(args[2], 'extracted'), 'ok')
        return true
      end
      super
    end
    load ARGV.shift
  RUBY
  # Precreate pins in the extracted tree, avoiding any real setup commands.
  harness.sub!("File.write(File.join(args[2], 'extracted'), 'ok')", "File.write(File.join(args[2], 'extracted'), 'ok'); %w[32 64].each { |n| FileUtils.mkdir_p(File.join(args[2], 'pinned_libs_' + n)) }")
  _, err, status = Open3.capture3({'HOME' => home}, RbConfig.ruby, '-e', harness,
                                  File.join(root, 'bin/.utils.rb'), File.join(root, 'bin/lsu-upgrade-steam-runtime'))
  raise err unless status.success?
  raise 'partial runtime reused' unless File.file?(File.join(runtime, 'steam-runtime/extracted')) && !File.exist?(File.join(runtime, 'steam-runtime/partial'))
  File.write(File.join(runtime, 'steam-runtime.tar.xz.checksum'), "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n")
  failed = harness.sub('return "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\\n"', 'return "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\\n"').sub("return \"scout_1\\n\"", "return \"scout_2\\n\"").sub("return true", "return false")
  _, _, status = Open3.capture3({'HOME' => home}, RbConfig.ruby, '-e', failed,
                               File.join(root, 'bin/.utils.rb'), File.join(root, 'bin/lsu-upgrade-steam-runtime'))
  raise 'failed extraction replaced active runtime' if status.success? || File.readlink(File.join(runtime, 'steam-runtime')) != 'steam-runtime_1' || !File.file?(File.join(runtime, 'steam-runtime/extracted'))
end

Dir.mktmpdir do |home|
  platform = File.join(home, 'SteamLinuxRuntime_sniper/test_platform_1')
  FileUtils.mkdir_p(File.join(platform, 'files'))
  File.write(File.join(platform, 'metadata'), '')
  harness = <<~'RUBY'
    require 'fileutils'
    require ARGV.shift
    class << File
      alias original_realdirpath realdirpath
      def realdirpath(path, *args)
        path.include?('compat-test') ? '/compat/test' : original_realdirpath(path, *args)
      end
    end
    def `(cmd)
      return '/compat-test' if cmd.include?('compat.linux.emul_path')
      return '1' if cmd.include?('vfs.usermount')
      raise "unexpected command #{cmd}"
    end
    def init_tmp_dir; FileUtils.mkdir_p(LSU_TMPDIR_PATH); end
    def try_mount(*args)
      flag = File.join(LSU_TMPDIR_PATH, 'mounted')
      return nil if File.exist?(flag)
      File.write(flag, '')
      args[2]
    end
    def system(*args)
      return true if args.first == 'kldstat -q -m nullfs' || args.first == 'umount'
      if args.first == 'sh'
        File.write(File.join(LSU_TMPDIR_PATH, 'started'), '')
        sleep 1
        return false
      end
      raise "unexpected system #{args.inspect}"
    end
    load ARGV.shift
  RUBY
  command = [RbConfig.ruby, '-e', harness, File.join(root, 'bin/.utils.rb'), File.join(root, 'bin/lsu-mount-runtime'), File.dirname(platform)]
  env = {'HOME' => home, 'LSU_MESA_LIBS' => 'none'}
  first = Process.spawn(env, *command, out: File::NULL, err: File::NULL)
  started = File.join(home, '.steam/tmp/started')
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  until File.exist?(started)
    raise 'first runtime setup did not start' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    sleep 0.01
  end
  _, err, second = Open3.capture3(env, *command)
  _, first_status = Process.wait2(first)
  raise 'failed setup was accepted' if first_status.success? || second.success? || !err.include?('Runtime mount is not ready')
end

Dir.mktmpdir do |home|
  harness = <<~'RUBY'
    require ARGV.shift
    def system(*args)
      raise 'pins created before mount' if args.first.end_with?('lsu-mount-runtime') && File.exist?(File.join(LSU_TMPDIR_PATH, 'SteamLinuxRuntime_sniper/usr/steam-runtime'))
      false
    end
    load ARGV.shift
  RUBY
  _, err, status = Open3.capture3({'HOME' => home}, RbConfig.ruby, '-e', harness,
                                  File.join(root, 'bin/.utils.rb'), File.join(root, 'tools/LSU_Scout_chroot/run.rb'), 'waitforexitandrun')
  raise 'Scout did not stop on mount failure' if status.success? || !err.include?('Unable to prepare chroot dir')
end
puts 'Runtime audit tests passed'
