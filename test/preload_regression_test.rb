require 'open3'
require 'tmpdir'
require 'rbconfig'

root = File.expand_path('..', __dir__)
cc = ENV.fetch('LINUX_CC', File.exist?('/compat/linux/bin/cc') ? '/compat/linux/bin/cc' : 'cc')
unless system(cc, '--version', out: File::NULL, err: File::NULL)
  warn "Skipping preload regression tests: #{cc} unavailable"
  exit 0
end

Dir.mktmpdir('lsu-preload-test') do |dir|
  %w[steamfix fakeudev].each do |name|
    command = [cc, '-std=c99', '-fPIC', '-shared', '-o', "#{dir}/#{name}.so",
               "#{root}/src/#{name}.c", '-pthread', '-ldl']
    raise "Compilation failed: #{name}" unless system(*command)
  end

  source = <<~'C'
    #define _GNU_SOURCE
    #include <assert.h>
    #include <dlfcn.h>
    #include <errno.h>
    #include <fcntl.h>
    #include <poll.h>
    #include <stdlib.h>
    #include <string.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      assert(system(NULL));
      assert(system("true # steamwebhelper.sh") == 0);
      assert(system("true # /reaper SteamLaunch -- x") == 0);
      char *args[] = {"/reaper SteamLaunch -- x", NULL};
      assert(execvp("/nonexistent-lsu-test", args) == -1 && errno == ENOENT);
      assert(strcmp(args[0], "/reaper SteamLaunch -- x") == 0);
      void *h = dlopen(argv[1], RTLD_NOW);
      assert(h);
      int (*getfd)(void *) = dlsym(h, "udev_monitor_get_fd");
      assert(getfd);
      int fd = getfd(NULL);
      assert(fd >= 0 && (fcntl(fd, F_GETFD) & FD_CLOEXEC));
      /* Linuxulator reports pipe access-mode flags incorrectly. */
      struct pollfd p = {fd, POLLIN, 0};
      assert(poll(&p, 1, 0) == 0);
      return 0;
    }
  C
  File.write("#{dir}/test.c", source)
  raise 'Test compilation failed' unless system(cc, '-o', "#{dir}/test", "#{dir}/test.c", '-ldl')
  env = { 'LSU_KEEP_LD_PRELOAD' => '1', 'LD_PRELOAD' => "#{dir}/steamfix.so" }
  raise 'Preload regression test failed' unless system(env, "#{dir}/test", "#{dir}/fakeudev.so")
end
puts 'Preload regression tests passed'
