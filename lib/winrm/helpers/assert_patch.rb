
module PatchAssertions

  def self.assert_major_version(library_name, expected_major, override_var_name)
    supported_major_ver = ENV[override_var_name] || expected_major
    loaded_ver = Gem.loaded_specs[library_name].version
    loaded_major_ver = loaded_ver.to_s.match(/(^\d+\.\d+)\.(.*)$/)[1]
    if loaded_major_ver.to_s != supported_major_ver.to_s
      puts "Unsupported version of #{library_name}. The supported major version of library is #{library_name} version #{expected_major}. This code path monkey patches few methods in #{library_name} to support additional features. If you are aware of the impact of using #{loaded_ver}, this can be enabled by setting #{override_var_name} to the major version #{loaded_major_ver}"
      exit 1
    end
  end

  def self.assert_arity_of_patched_method(klass, method_name, expected_arity)
    if klass.instance_method(method_name).arity != expected_arity
      puts "Cannot patch method #{klass}::#{method_name} since your latest gem seems to have different method definition that cannot be safely patched. Please use the supported version of patched gem."
      exit 1
    end
  end
end