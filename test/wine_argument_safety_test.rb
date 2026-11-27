require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'

class WineArgumentSafetyTest
  def assert(value, message = 'assertion failed')
    raise message unless value
  end

  def refute(value, message = 'assertion failed')
    assert(!value, message)
  end

  def assert_includes(value, substring)
    assert(value.include?(substring), "#{value.inspect} does not include #{substring.inspect}")
  end
  ROOT = File.expand_path('..', __dir__)
  PATCH = File.join(ROOT, 'tools/LSU_FreeBSD_Wine/patch-dt_init.rb')
  FILE_WRAPPER = File.join(ROOT, 'lxbin/file.rb')

  def test_file_wrapper_passes_metacharacters_as_filename
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'file; touch INJECTED')
      File.write(path, 'hello')
      output, status = Open3.capture2e(RbConfig.ruby, FILE_WRAPPER, path, chdir: dir)
      assert status.success?, output
      assert_includes output, path
      refute File.exist?(File.join(dir, 'INJECTED'))
    end
  end

  def test_patch_handles_metacharacters_in_elf_filename
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'elf; touch INJECTED')
      output = File.join(dir, 'patched')
      FileUtils.cp('/bin/ls', input)
      message, status = Open3.capture2e(RbConfig.ruby, PATCH, input, output, chdir: dir)
      assert status.success?, message
      assert File.file?(output)
      refute File.exist?(File.join(dir, 'INJECTED'))
    end
  end

  def test_patch_rejects_missing_or_truncated_dynamic_section_without_writing
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'bad')
      output = File.join(dir, 'output')
      readelf = File.join(dir, 'readelf')
      File.write(input, 'short')
      File.write(readelf, "#!/bin/sh\nprintf '%s\\n' \"$HEADERS\"\n")
      File.chmod(0755, readelf)
      ["Class: ELF64\nData: 2's complement, little endian", "Class: ELF64\nData: 2's complement, little endian\n.dynamic DYNAMIC 0000 0000"].each do |headers|
        message, status = Open3.capture2e({'PATH' => dir, 'HEADERS' => headers}, RbConfig.ruby, PATCH, input, output)
        refute status.success?, message
        refute File.exist?(output)
      end
    end
  end
end

WineArgumentSafetyTest.instance_methods(false).grep(/^test_/).each do |name|
  WineArgumentSafetyTest.new.public_send(name)
  puts "#{name} passed"
end
